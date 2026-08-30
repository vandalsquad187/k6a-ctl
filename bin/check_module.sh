#!/system/bin/sh
# check_module.sh — k6a-ctl Build Gate. Bei JEDEM Fehler Abbruch.
# Usage: check_module.sh [module-dir]
MOD="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
FAIL=0; WARN=0

_pass() { echo "  OK  $1"; }
_fail() { echo "  FAIL $1"; FAIL=1; }
_warn() { echo "  WARN $1"; WARN=$((WARN+1)); }

echo "════════════════════════════════════"
echo " k6a-ctl Gate | Modul: $MOD"
echo "════════════════════════════════════"

# ── 1/5 Shell-Syntax ────────────────────────────────────────────────────────
echo "[1] Shell-Syntax"
for f in "$MOD"/service.sh "$MOD"/bin/*.sh "$MOD"/bin/k6a-controller; do
    [ -f "$f" ] || continue
    if sh -n "$f" 2>/dev/null; then _pass "$(basename "$f")"; else _fail "$(basename "$f") Syntaxfehler"; fi
done

# ── 2/5 r-Alias-Schatten (mksh: alias r='fc -e -' schlägt Funktion!) ───────
echo "[2] Alias-Falle"
for lib in "$MOD"/bin/k6a-lib.sh "$MOD"/bin/*.sh; do
    [ -f "$lib" ] || continue
    if grep -qE '^[[:space:]]*r\(\)' "$lib" && ! grep -qE '^[[:space:]]*unalias r' "$lib"; then
        _fail "$(basename "$lib"): r() ohne 'unalias r' → mksh-fc-Schatten!"
    fi
done
_pass "alias-check fertig"

# ── 3/5 JS: dup const/let, Brackets ────────────────────────────────────────
echo "[3] JS-Integrität"
for js in "$MOD"/webroot/app.js "$MOD"/webroot/index.html; do
    [ -f "$js" ] || { _warn "$(basename "$js") fehlt"; continue; }
    dups=$(grep -oE "(^|[;})])[[:space:]]*(const|let)[[:space:]]+[A-Za-z_$][A-Za-z0-9_$]*" "$js" 2>/dev/null \
           | awk '{print $NF}' | sort | uniq -d)
    [ -n "$dups" ] && _fail "$(basename "$js"): dup let/const: $dups" || true
    ob=$(grep -o '{' "$js" | wc -l); cb=$(grep -o '}' "$js" | wc -l)
    [ "$ob" != "$cb" ] && _fail "$(basename "$js"): brackets $ob/$cb" || _pass "$(basename "$js") sauber"
done

# ── 4/5 Zone-Dryrun (nur auf Gerät möglich) ────────────────────────────────
echo "[4] Thermal-Zonen"
if [ -d /sys/devices/virtual/thermal ]; then
    ZL=$(mktemp 2>/dev/null || echo /data/local/tmp/gate_zones.log)
    MODDIR="$MOD" LOG_FILE="$ZL" sh -c ". '$MOD/bin/k6a-lib.sh'; _cache_thermal_zones" >/dev/null 2>&1
    if grep -q "zones:" "$ZL" 2>/dev/null; then
        grep "zones:" "$ZL" | tail -1 | sed 's/^/  OK  /'
    else _fail "Zone-Dryrun lieferte kein Ergebnis"; fi
    rm -f "$ZL"
else
    _pass "übersprungen (kein /sys — Dev-Machine)"
fi

# ── 5/5 Config-Sanity ──────────────────────────────────────────────────────
echo "[5] Config"
CONF="$MOD/config/settings.conf"
[ -f "$CONF" ] || _fail "settings.conf fehlt"
if [ -f "$CONF" ]; then
    DEL=$(grep "^delegated=" "$CONF" | cut -d= -f2 | tr -d ' ')
    [ "$DEL" = "1" ] && _pass "delegated=1 (kernel governor)" || _pass "delegated=0 (legacy)"

    if [ "$DEL" = "1" ]; then
        # Delegated: thresholds in kernel, prüfe profile + auto_badazz
        PROF=$(grep "^profile=" "$CONF" | cut -d= -f2 | tr -d ' ')
        case "$PROF" in gaming|battery|badazz|badazz_safe) _pass "profile=$PROF" ;; *) _fail "profile ungültig: [$PROF]" ;; esac
        ABT=$(grep "^auto_badazz_temp=" "$CONF" | cut -d= -f2 | tr -d ' ')
        [ -n "$ABT" ] && [ "$ABT" -ge 70 ] 2>/dev/null && [ "$ABT" -le 95 ] 2>/dev/null \
            && _pass "auto_badazz_temp=${ABT}°C" || _fail "auto_badazz_temp ungültig: [$ABT]"
    else
        # Legacy: thresholds in settings.conf
        L2=$(grep "^cd_l2_temp=" "$CONF" | cut -d= -f2); L3=$(grep "^cd_l3_temp=" "$CONF" | cut -d= -f2)
        L4=$(grep "^cd_l4_temp=" "$CONF" | cut -d= -f2); RC=$(grep "^cd_recover=" "$CONF" | cut -d= -f2)
        if [ "${RC:-76}" -ge "${L2:-80}" ] 2>/dev/null; then _fail "recover >= l2";
        elif [ "${L2:-80}" -ge "${L3:-82}" ] 2>/dev/null; then _fail "l2 >= l3";
        elif [ "${L3:-82}" -ge "${L4:-88}" ] 2>/dev/null; then _fail "l3 >= l4";
        else _pass "thresholds ${RC}°<${L2}°<${L3}°<${L4}°"; fi
    fi

    m=$(grep "^mode=" "$CONF" | cut -d= -f2 | tr -d ' ')
    case "$m" in gaming|daily) _pass "mode=$m" ;; *) _fail "mode ungültig: [$m]" ;; esac
fi

echo "════════════════════════════════════"
if [ "$FAIL" = "0" ]; then echo " GATE OK — $WARN warn(s)"; exit 0
else echo " GATE FAILED — $FAIL err(s), $WARN warn(s)"; exit 1; fi