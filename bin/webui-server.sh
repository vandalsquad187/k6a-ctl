#!/system/bin/sh
# k6a-ctl webui-server — localhost control endpoint :8767
MODDIR=/data/adb/modules/k6a-ctl
LOG=$MODDIR/config/service.log
PIDF=$MODDIR/run/webui.pid

_logrot() {
    local sz
    sz=$(stat -c%s "$LOG" 2>/dev/null || wc -c < "$LOG" 2>/dev/null) || return 0
    [ -n "$sz" ] && [ "$sz" -gt 102400 ] 2>/dev/null || return 0
    mv -f "${LOG}.1" "${LOG}.2" 2>/dev/null
    mv -f "$LOG" "${LOG}.1" 2>/dev/null
}
log() { _logrot; printf '[%s] [WEBUI] %s\n' "$(date '+%H:%M:%S')" "$1" >> "$LOG" 2>/dev/null; }
trap 'rm -f "$PIDF"; exit' INT TERM

echo $$ > "$PIDF"
log "webui-server startet auf 127.0.0.1:8767"

while true; do
    nc -L -p 8767 -s 127.0.0.1 -W 2 /system/bin/sh "$MODDIR/bin/webui-handler.sh" >> "$LOG" 2>&1
    # nc nur tot wenn systematisch — kurze pause, neu
    log "nc beendet, restart in 2s"
    sleep 2
done