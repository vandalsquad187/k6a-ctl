#!/system/bin/sh
# k6a-ctl service.sh — boot setup + watchdogs (controller + webui)
# v1.4.9: dynamischer k6a_gov-versionsgate, webui-token, P4-stale-watchdog
MODDIR=${0%/*}
LOG=$MODDIR/config/service.log

_logrot() {
    local sz
    sz=$(stat -c%s "$LOG" 2>/dev/null || wc -c < "$LOG" 2>/dev/null) || return 0
    [ -n "$sz" ] && [ "$sz" -gt 102400 ] 2>/dev/null || return 0
    mv -f "${LOG}.1" "${LOG}.2" 2>/dev/null
    mv -f "$LOG" "${LOG}.1" 2>/dev/null
}
log() { _logrot; printf '[%s] [SVC] %s\n' "$(date '+%H:%M:%S')" "$1" >> "$LOG" 2>/dev/null; }

mkdir -p "$MODDIR/run" "$MODDIR/config" "$MODDIR/webroot" 2>/dev/null
chmod 755 "$MODDIR/bin/k6a-controller" "$MODDIR/bin/webui-server.sh" "$MODDIR/bin/webui-handler.sh" 2>/dev/null

# ── webui token (root-only, für state-changing routes) ──────────────────────
TOKENF=$MODDIR/config/webui.token
if [ ! -s "$TOKENF" ]; then
    tr -dc 'a-f0-9' </dev/urandom 2>/dev/null | head -c 32 > "$TOKENF" 2>/dev/null
    [ -s "$TOKENF" ] && log "webui-token erzeugt"
fi
chmod 600 "$TOKENF" 2>/dev/null
# token in webroot/app.js einbacken (falls abweichend)
_TOK=$(tr -d '\r\n \t' < "$TOKENF" 2>/dev/null)
if [ -n "$_TOK" ] && [ -f "$MODDIR/webroot/app.js" ] && ! grep -q "^const KTOKEN='$_TOK'" "$MODDIR/webroot/app.js" 2>/dev/null; then
    sed -i "s/^const KTOKEN='.*'/const KTOKEN='$_TOK'/" "$MODDIR/webroot/app.js" 2>/dev/null \
        && log "webroot/app.js token aktualisiert"
fi

# ── k6a_gov.ko laden (CONFIG_K6A_GOV=m ab Badazz Build 341) ──────────────────
GOV=/sys/kernel/k6a_gov
GOV_KO_VER=1.7.0

kver_ok() { case "${1:-}" in 1.[5-9].*|1.[1-9][0-9].*) return 0 ;; *) return 1 ;; esac }

_load_gov() {
    if [ -f "$GOV/status" ]; then
        log "k6a_gov bereits geladen"
        return 0
    fi
    local ko="" kv="" gv="" out rc cand seen=0
    for cand in "$MODDIR/k6a_gov.ko" /data/adb/k6a_gov.ko \
                /system/lib/modules/k6a_gov.ko /vendor/lib/modules/k6a_gov.ko; do
        [ -f "$cand" ] || continue
        seen=1
            # v1.6.1: binaerer Fallback (strings fehlt z. B. auf manchen toybox-Builds);
            # Muster unabgeankert — in .binaries trennen NUL-Bytes keine Zeilen
            if command -v strings >/dev/null 2>&1; then
                kv=$(strings "$cand" 2>/dev/null | grep -E '^version=[0-9]+\.[0-9]+\.[0-9]+$' | head -1 | cut -d= -f2)
            else
                kv=$(grep -aoE 'version=[0-9]+\.[0-9]+\.[0-9]+' "$cand" 2>/dev/null | head -1 | cut -d= -f2)
            fi
            # Version-Gate gilt jetzt fuer beide Pfade (vorher: ohne strings
            # wurde jeder Kandidat geladen und erst am Runtime-Gate rmmodded)
            if [ -n "$kv" ] && ! kver_ok "$kv"; then
                log "WARN $cand version=$kv, erwartet 1.5.x–1.9.x / 1.10+ — überspringe"
                continue
            fi
        ko=$cand
        break
    done
    if [ -z "$ko" ]; then
        if [ "$seen" = "1" ]; then
            log "WARN k6a_gov.ko: alle Kandidaten nicht version-konform — Legacy-Fallback (Userspace-Cooldown)"
        else
            log "WARN k6a_gov.ko nicht gefunden — Legacy-Fallback (Userspace-Cooldown)"
        fi
        return 1
    fi
    out=$(/system/bin/insmod "$ko" 2>&1)
    rc=$?
    if [ "$rc" != "0" ]; then
        log "WARN insmod $ko fehlgeschlagen rc=$rc: $out"
        return 1
    fi
    sleep 1
    gv=$(grep -oE 'version=[^ ]*' "$GOV/status" 2>/dev/null | head -1 | cut -d= -f2)
    if ! kver_ok "$gv"; then
        log "WARN k6a_gov runtime version=${gv:-?}, erwartet 1.5.x–1.9.x / 1.10+ — rmmod"
        /system/bin/rmmod k6a_gov 2>/dev/null
        return 1
    fi
    log "k6a_gov $gv aus $ko geladen"
    return 0
}
_load_gov

_tries=0
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 3
    _tries=$((_tries + 1))
    [ "$_tries" -ge 40 ] && { log "boot_completed timeout 120s — starte trotzdem"; break; }
done
sleep 5
log "service start"

# ── webui-server (einmalig, stale-guard + belegt-check) ─────────────────────
(
    PIDF=$MODDIR/run/webui.pid
    _ui_alive() {
        local p
        p=$(cat "$PIDF" 2>/dev/null)
        [ -n "$p" ] && [ -d "/proc/$p" ] && tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | grep -q webui-server
    }
    if _ui_alive; then
        : # laeuft bereits — nichts tun
    else
        rm -f "$PIDF"
        if grep -qi ':223F[[:space:]]' /proc/net/tcp 2>/dev/null; then
            log "webui :8767 belegt (fremd) — kein spawn"
        else
            setsid sh "$MODDIR/bin/webui-server.sh" >/dev/null 2>&1 </dev/null &
        fi
    fi
) &

# ── controller watchdog (crash-backoff) ─────────────────────────────────────
CTRL="$MODDIR/bin/k6a-controller"
_backoff=3; _crashes=0; _window=$(cut -d. -f1 /proc/uptime 2>/dev/null || echo 0)

while true; do
    nice -n 0 sh "$CTRL" "$MODDIR"
    RC=$?
    [ -f "$MODDIR/run/stop" ] && { rm -f "$MODDIR/run/stop"; log "stop-file — ende"; break; }
    if [ "$RC" = "0" ]; then
        log "controller clean exit 0 — kein Crash"
        _crashes=0; _backoff=3; _window=$(cut -d. -f1 /proc/uptime 2>/dev/null || echo 0)
        sleep 1
        continue
    fi
    _now=$(cut -d. -f1 /proc/uptime 2>/dev/null || echo 0)
    if [ $(( _now - _window )) -lt 60 ]; then
        _crashes=$(( _crashes + 1 ))
        [ "$_crashes" -gt 10 ] && { log "crash storm — gebe auf"; break; }
        [ "$_backoff" -lt 30 ] && _backoff=$(( _backoff * 2 ))
    else
        _crashes=1; _backoff=3; _window=$_now
    fi
    log "controller exit $RC — restart in ${_backoff}s"
    sleep "$_backoff"
done