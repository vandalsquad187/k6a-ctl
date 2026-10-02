#!/system/bin/sh
# k6a-ctl service.sh — boot setup + watchdogs (controller + webui)
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
# USB dwc3 autosuspend - FIXED Badazz Build 68 (08.09.): autosuspend now safe, keep auto

# ── k6a_gov.ko laden (CONFIG_K6A_GOV=m ab Badazz Build 341) ──────────────────
GOV=/sys/kernel/k6a_gov
GOV_KO_VER=1.5.0

_load_gov() {
    if [ -f "$GOV/status" ]; then
        log "k6a_gov bereits geladen"
        return 0
    fi
    local ko="" kv="" gv="" out rc
    for ko in "$MODDIR/k6a_gov.ko" /data/adb/k6a_gov.ko \
              /system/lib/modules/k6a_gov.ko /vendor/lib/modules/k6a_gov.ko; do
        [ -f "$ko" ] && break
        ko=""
    done
    if [ -z "$ko" ]; then
        log "WARN k6a_gov.ko nicht gefunden — Legacy-Fallback (Userspace-Cooldown)"
        return 1
    fi
    if command -v strings >/dev/null 2>&1; then
        kv=$(strings "$ko" 2>/dev/null | grep -E '^version=[0-9]+\.[0-9]+\.[0-9]+$' | head -1 | cut -d= -f2)
        if [ -n "$kv" ] && [ "$kv" != "$GOV_KO_VER" ]; then
            log "WARN k6a_gov.ko version=$kv, erwartet $GOV_KO_VER — nicht geladen"
            return 1
        fi
    fi
    out=$(/system/bin/insmod "$ko" 2>&1)
    rc=$?
    if [ "$rc" != "0" ]; then
        log "WARN insmod $ko fehlgeschlagen rc=$rc: $out"
        return 1
    fi
    sleep 1
    gv=$(grep -oE 'version=[^ ]*' "$GOV/status" 2>/dev/null | head -1 | cut -d= -f2)
    if [ "$gv" != "$GOV_KO_VER" ]; then
        log "WARN k6a_gov runtime version=${gv:-?}, erwartet $GOV_KO_VER — rmmod"
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

# ── webui-server (einmalig, stale-guard) ────────────────────────────────────
(
    PIDF=$MODDIR/run/webui.pid
    if [ -f "$PIDF" ]; then
        OLD=$(cat "$PIDF" 2>/dev/null)
        if [ -n "$OLD" ] && [ -d "/proc/$OLD" ]; then OLD_C=$(tr '\0' ' ' < "/proc/$OLD/cmdline" 2>/dev/null); case "$OLD_C" in *webui-server*) OLD="" ;; esac; fi
        [ -n "$OLD" ] && rm -f "$PIDF"
    fi
    setsid sh "$MODDIR/bin/webui-server.sh" >/dev/null 2>&1 </dev/null &
) &

# ── controller watchdog (crash-backoff) ─────────────────────────────────────
CTRL="$MODDIR/bin/k6a-controller"
_backoff=3; _crashes=0; _window=$(cut -d. -f1 /proc/uptime 2>/dev/null || echo 0)

while true; do
    nice -n -5 sh "$CTRL" "$MODDIR"
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