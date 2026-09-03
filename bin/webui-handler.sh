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
    local k="$1" v="$2" tmp
    tmp=$(mktemp "${CONF}.tmp.XXXXXX" 2>/dev/null) || return 1
    if grep -q "^${k}=" "$CONF" 2>/dev/null; then
        grep -v "^${k}=" "$CONF" > "$tmp" 2>/dev/null
        printf '%s=%s\n' "$k" "$v" >> "$tmp"
    else
        cat "$CONF" > "$tmp" 2>/dev/null
        printf '%s=%s\n' "$k" "$v" >> "$tmp"
    fi
    cat "$tmp" > "$CONF" 2>/dev/null
    rm -f "$tmp"
}
bw_set() {
    local vals="$1" a b c d e f
    case "$vals" in
        ""|*[!0-9_]* ) return 1 ;;
    esac
    vals=$(printf '%s' "$vals" | tr '_' ' ')
    set -- $vals
    [ $# -eq 6 ] || return 1
    for a in "$@"; do
        case "$a" in ''|*[!0-9]* ) return 1 ;; esac
        [ "$a" -ge 0 ] 2>/dev/null && [ "$a" -le 20000 ] 2>/dev/null || return 1
    done
    printf '%s' "$vals" > /sys/kernel/k6a_gov/bw_floors 2>/dev/null
}

# REQ log: CRLF + injection strip (only state-changing, no /ping spam)
_logq=$(printf '%s' "$REQ" | tr -d '\r\n' | cut -c1-120)
_logf="${CONF%/*}/../config/service.log"
case "$P" in
    /ping) ;;
    *)
        _sz=$(stat -c%s "$_logf" 2>/dev/null || wc -c < "$_logf" 2>/dev/null) || _sz=0
        if [ -n "$_sz" ] && [ "$_sz" -gt 102400 ] 2>/dev/null; then
            mv -f "${_logf}.1" "${_logf}.2" 2>/dev/null
            mv -f "$_logf" "${_logf}.1" 2>/dev/null
        fi
        echo "[$(date '+%H:%M:%S')] [WEBUI] REQ: $_logq" >> "$_logf" 2>/dev/null ;;
esac

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
    /profile)
        case "$Q" in
            p=gaming|p=battery|p=badazz|p=badazz_safe|p=custom|p=off) setcfg profile "${Q#p=}"; ok ;;
            *) bad ;;
        esac ;;
    /delegated)
        case "$Q" in
            d=0|d=1) setcfg delegated "${Q#d=}"; ok ;;
            *) bad ;;
        esac ;;
    /bw_floors)
        case "$Q" in
            bw=* )
                vals="${Q#bw=}"
                if bw_set "$vals"; then ok; else bad; fi ;;
            *) bad ;;
        esac ;;
    /battguard)
        case "$Q" in
            t=* )
                v="${Q#t=}"
                case "$v" in ''|*[!0-9]*) bad ;; *)
                    if [ "$v" -ge 35 ] 2>/dev/null && [ "$v" -le 60 ] 2>/dev/null; then
                        setcfg battery_guard_temp "$v"; ok
                    else bad; fi ;; esac ;;
            *) bad ;;
        esac ;;
    /ping)
        ok ;;
    *)
        bad ;;
esac