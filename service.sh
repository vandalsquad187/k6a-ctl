#!/system/bin/sh
# k6a-ctl service.sh — boot setup + watchdogs (controller + webui)
MODDIR=${0%/*}
LOG=$MODDIR/config/service.log

log() { printf '[%s] [SVC] %s\n' "$(date '+%H:%M:%S')" "$1" >> "$LOG" 2>/dev/null; }

mkdir -p "$MODDIR/run" "$MODDIR/config" "$MODDIR/webroot" 2>/dev/null
chmod 755 "$MODDIR/bin/k6a-controller" "$MODDIR/bin/webui-server.sh" "$MODDIR/bin/webui-handler.sh" 2>/dev/null

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 3; done
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
    [ "$RC" = "0" ] && RC=143
    _now=$(cut -d. -f1 /proc/uptime)
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