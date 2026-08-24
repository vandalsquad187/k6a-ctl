#!/system/bin/sh
# k6a-ctl webui handler — whitelisted endpoints only, one shot per connection
CONF="$(cd "$(dirname "$0")/.." && pwd)/config/settings.conf"

read -r REQ
# REQ: GET /endpoint?k=v HTTP/1.x
REST=${REQ#* }
PATHQ=${REST%% *}
P=${PATHQ%%\?*}
Q=${PATHQ#*\?}
[ "$Q" = "$PATHQ" ] && Q=""

ok()  { printf 'HTTP/1.0 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK'; }
bad() { printf 'HTTP/1.0 400 Bad Request\r\nContent-Length: 0\r\nConnection: close\r\n\r\n'; }

setcfg() {
    # key/value hart validiert von den case-zweigen oben
    sed -i "s|^$1=.*|$1=$2|" "$CONF" 2>/dev/null
}

echo "[$(date '+%H:%M:%S')] [WEBUI] REQ: $REQ" >> "${CONF%/*}/../config/service.log" 2>/dev/null

case "$P" in
    /mode)
        case "$Q" in
            m=gaming|m=daily) setcfg mode "${Q#m=}"; ok ;;
            *) bad ;;
        esac ;;
    /thermal)
        case "$Q" in
            t=on|t=off) setcfg thermal_protect "${Q#t=}"; ok ;;
            *) bad ;;
        esac ;;
    /ping)
        ok ;;
    *)
        bad ;;
esac