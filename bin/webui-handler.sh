#!/system/bin/sh
# k6a-ctl webui handler — whitelisted endpoints only, one shot per connection
# v1.4.9: token-gate (config/webui.token, root-only) für alle state-changing routes
CONF="$(cd "$(dirname "$0")/.." && pwd)/config/settings.conf"
TOKENF="$(dirname "$CONF")/webui.token"

read -r REQ
# REQ: GET /endpoint?k=v HTTP/1.x
REST=${REQ#* }
PATHQ=${REST%% *}
P=${PATHQ%%\?*}
Q=${PATHQ#*\?}
[ "$Q" = "$PATHQ" ] && Q=""
_QFULL=$Q
Q=${Q%%&*}

ok()  { printf 'HTTP/1.0 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK'; }
bad() { printf 'HTTP/1.0 400 Bad Request\r\nContent-Length: 0\r\nConnection: close\r\n\r\n'; }
forbidden() { printf 'HTTP/1.0 403 Forbidden\r\nContent-Length: 0\r\nConnection: close\r\n\r\n'; }

_auth_or_bad() { # k=<token> verpflichtend an jeder state-changing route
    _got=""
    case "$_QFULL" in
        *k=*) _got=${_QFULL#*k=}; _got=${_got%%&*} ;;
    esac
    _ref=$(tr -d '\r\n \t' < "$TOKENF" 2>/dev/null) || _ref=""
    [ -n "$_ref" ] && [ "$_got" = "$_ref" ] && return 0
    forbidden
    exit 1
}

_setcfg_locked() {
    local k="$1" v="$2" tmp
    tmp=$(mktemp "${CONF}.tmp.XXXXXX" 2>/dev/null) || return 1
    if grep -q "^${k}=" "$CONF" 2>/dev/null; then
        grep -v "^${k}=" "$CONF" > "$tmp" 2>/dev/null
        printf '%s=%s\n' "$k" "$v" >> "$tmp"
    else
        cat "$CONF" > "$tmp" 2>/dev/null
        printf '%s=%s\n' "$k" "$v" >> "$tmp"
    fi
    mv -f "$tmp" "$CONF" 2>/dev/null || { cat "$tmp" > "$CONF" 2>/dev/null; rm -f "$tmp"; }
}
# Lock um den Read-Modify-Write: gleichzeitige Requests dürfen sich keine Keys wegnehmen
setcfg() {
    local lk="${CONF}.lock" i=0
    while ! mkdir "$lk" 2>/dev/null; do
        i=$((i+1))
        if [ "$i" -gt 40 ]; then          # veralteter Lock (>2 s): brechen
            rmdir "$lk" 2>/dev/null
            mkdir "$lk" 2>/dev/null || return 1
            break
        fi
        sleep 0.05
    done
    _setcfg_locked "$@"
    rmdir "$lk" 2>/dev/null
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
        [ "$a" -ge 0 ] 2>/dev/null && [ "$a" -le 30000 ] 2>/dev/null || return 1
    done
    printf '%s' "$vals" > /sys/kernel/k6a_gov/bw_floors 2>/dev/null
}

# REQ log: CRLF + injection strip (only state-changing, no /ping spam)
_logq=$(printf '%s' "$REQ" | tr -d '\r\n' | sed 's/\([?&]\)k=[0-9a-fA-F]*/\1k=***/' | cut -c1-120)   # Token nie im Log
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
_auth_or_bad
        case "$Q" in
            m=gaming|m=daily|m=auto) setcfg mode "${Q#m=}"; ok ;;
            *) bad ;;
        esac ;;
    /thermal)
_auth_or_bad
        case "$Q" in
            t=on|t=off) setcfg thermal_protect "${Q#t=}"; ok ;;
            *) bad ;;
        esac ;;
    /goldcap)
_auth_or_bad
        case "$Q" in
            g=on) setcfg gold_cap_gaming 1708800; ok ;;
            g=off) setcfg gold_cap_gaming 0; ok ;;
            *) bad ;;
        esac ;;
    /profile)
_auth_or_bad
        case "$Q" in
            p=gaming|p=battery|p=badazz|p=badazz_safe|p=custom|p=off) setcfg profile "${Q#p=}"; ok ;;
            *) bad ;;
        esac ;;
    /delegated)
_auth_or_bad
        case "$Q" in
            d=0|d=1) setcfg delegated "${Q#d=}"; ok ;;
            *) bad ;;
        esac ;;
    /bw_floors)
_auth_or_bad
        case "$Q" in
            bw=* )
                vals="${Q#bw=}"
                if bw_set "$vals"; then ok; else bad; fi ;;
            *) bad ;;
        esac ;;
    /battguard)
_auth_or_bad
        case "$Q" in
            t=* )
                v="${Q#t=}"
                case "$v" in ''|*[!0-9]*) bad ;; *)
                    if [ "$v" -ge 35 ] 2>/dev/null && [ "$v" -le 60 ] 2>/dev/null; then
                        setcfg battery_guard_temp "$v"; ok
                    else bad; fi ;; esac ;;
            e=1) setcfg battery_guard on; ok ;;
            e=0) setcfg battery_guard off; ok ;;
            *) bad ;;
        esac ;;
    /ping)
        ok ;;
    *)
        bad ;;
esac