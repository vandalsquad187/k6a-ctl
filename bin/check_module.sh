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

# ── 1/6 Shell-Syntax ────────────────────────────────────────────────────────
echo "[1] Shell-Syntax"
for f in "$MOD"/service.sh "$MOD"/customize.sh "$MOD"/bin/*.sh "$MOD"/bin/k6a-controller; do
    [ -f "$f" ] || continue
    if sh -n "$f" 2>/dev/null; then _pass "$(basename "$f")"; else _fail "$(basename "$f") Syntaxfehler"; fi
done

# ── 2/6 r-Alias-Schatten (mksh: alias r='fc -e -' schlägt Funktion!) ───────
echo "[2] Alias-Falle"
for lib in "$MOD"/bin/k6a-lib.sh "$MOD"/bin/*.sh; do
    [ -f "$lib" ] || continue
    if grep -qE '^[[:space:]]*r\(\)' "$lib" && ! grep -qE '^[[:space:]]*unalias r' "$lib"; then
        _fail "$(basename "$lib"): r() ohne 'unalias r' → mksh-fc-Schatten!"
    fi
done
_pass "alias-check fertig"

# ── 3/6 JS: dup const/let, Brackets ────────────────────────────────────────
echo "[3] JS-Integrität"
for js in "$MOD"/webroot/app.js "$MOD"/webroot/index.html; do
    [ -f "$js" ] || { _warn "$(basename "$js") fehlt"; continue; }
    dups=$(grep -oE "(^|[;})])[[:space:]]*(const|let)[[:space:]]+[A-Za-z_$][A-Za-z0-9_$]*" "$js" 2>/dev/null \
           | awk '{print $NF}' | sort | uniq -d)
    [ -n "$dups" ] && _fail "$(basename "$js"): dup let/const: $dups" || true
    ob=$(grep -o '{' "$js" | wc -l); cb=$(grep -o '}' "$js" | wc -l)
    [ "$ob" != "$cb" ] && _fail "$(basename "$js"): brackets $ob/$cb" || _pass "$(basename "$js") sauber"
done

# ── 4/6 Zone-Dryrun (nur auf Gerät möglich) ────────────────────────────────
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

# ── 5/6 Config-Sanity ──────────────────────────────────────────────────────
echo "[5] Config"
CONF="$MOD/config/settings.conf"
[ -f "$CONF" ] || _fail "settings.conf fehlt"
if [ -f "$CONF" ]; then
    DEL=$(grep "^delegated=" "$CONF" | cut -d= -f2 | tr -d ' ')
    [ "$DEL" = "1" ] && _pass "delegated=1 (kernel governor)" || _pass "delegated=0 (legacy)"

    if [ "$DEL" = "1" ]; then
        # Delegated: thresholds in kernel, prüfe profile + auto_badazz
        PROF=$(grep "^profile=" "$CONF" | cut -d= -f2 | tr -d ' ')
        case "$PROF" in gaming|battery|badazz|badazz_safe|custom) _pass "profile=$PROF" ;; *) _fail "profile ungültig: [$PROF]" ;; esac
        ABT=$(grep "^auto_badazz_temp=" "$CONF" | cut -d= -f2 | tr -d ' ')
        [ -n "$ABT" ] && [ "$ABT" -ge 70 ] 2>/dev/null && [ "$ABT" -le 95 ] 2>/dev/null \
            && _pass "auto_badazz_temp=${ABT}°C" || _fail "auto_badazz_temp ungültig: [$ABT]"
        BGT=$(grep "^battery_guard_temp=" "$CONF" | cut -d= -f2 | tr -d ' ')
        [ -n "$BGT" ] && [ "$BGT" -ge 35 ] 2>/dev/null && [ "$BGT" -le 60 ] 2>/dev/null \
            && _pass "battery_guard_temp=${BGT}°C" || _fail "battery_guard_temp ungültig: [$BGT]"
        BG=$(grep "^battery_guard=" "$CONF" | cut -d= -f2 | tr -d ' ')
        case "$BG" in on|off) _pass "battery_guard=$BG" ;; *) _fail "battery_guard ungültig: [$BG]" ;; esac

        # Gold-Cluster-Deckelung: 0 = frei, sonst Hz (wird auf OPP gesnappt)
        for _k in gold_cap_gaming gold_cap_daily; do
            _v=$(grep "^${_k}=" "$CONF" | cut -d= -f2 | tr -d ' \r')
            case "$_v" in
                '') _fail "${_k} fehlt" ;;
                *[!0-9]*) _fail "${_k} ungültig: [$_v]" ;;
                *) _pass "${_k}=$_v Hz" ;;
            esac
        done
        # cd_thresholds: genau 7 Zahlen in fester Reihenfolge l2t l3t l4t rec l2g l3g l4g
        CDT=$(grep "^cd_thresholds=" "$CONF" | cut -d= -f2- | tr -d '\r')
        _n=$(printf '%s' "$CDT" | wc -w 2>/dev/null)
        if [ -z "$CDT" ]; then
            _fail "cd_thresholds fehlt"
        elif [ "${_n:-0}" -ne 7 ] 2>/dev/null; then
            _fail "cd_thresholds: erwartet 7 Werte, hat $_n"
        else
            set -- $CDT
            if [ "$4" -ge "$1" ] 2>/dev/null; then _fail "cd_thresholds: rec($4) >= l2t($1)"
            elif [ "$1" -ge "$2" ] 2>/dev/null; then _fail "cd_thresholds: l2t($1) >= l3t($2)"
            elif [ "$2" -ge "$3" ] 2>/dev/null; then _fail "cd_thresholds: l3t($2) >= l4t($3)"
            elif [ "$5" -lt "$6" ] 2>/dev/null || [ "$6" -lt "$7" ] 2>/dev/null; then _fail "cd_thresholds: Gold-Grenzen nicht absteigend"
            else _pass "cd_thresholds $CDT" ; fi
        fi
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

# ── 5b/6 Version-Lock: service.sh (insmod) ↔ controller (wartet auf) ─────────
echo "[5b] Version-Lock k6a_gov"
GKV=$(grep "^GOV_KO_VER=" "$MOD/service.sh" 2>/dev/null | cut -d= -f2 | tr -d ' ')
if echo "$GKV" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    _pass "service.sh GOV_KO_VER=$GKV"
else
    _fail "service.sh GOV_KO_VER fehlt/ungültig: [$GKV]"
fi
GMM=${GKV%.*}
if [ -n "$GMM" ] && grep -q "${GMM}\.\*" "$MOD/bin/k6a-controller" 2>/dev/null; then
    _pass "controller wartet auf k6a_gov ${GMM}.*"
else
    _fail "Version-Lock inkonsistent: controller wartet nicht auf ${GMM:-?}.*"
fi
if grep -q '^GOV_KO_VER=' "$MOD/service.sh" 2>/dev/null && grep -q 'insmod' "$MOD/service.sh"; then
    _pass "service.sh lädt k6a_gov.ko per insmod"
else
    _fail "service.sh lädt kein k6a_gov.ko (insmod fehlt)"
fi

# ── 5c/6 SELinux: sepolicy.rule muss für ksud parsbar sein ─────────────────
echo "[5c] sepolicy.rule (SELinux)"
SP="$MOD/sepolicy.rule"
if [ ! -f "$SP" ]; then
    _fail "sepolicy.rule fehlt — hash_state bleibt 3 (kernel darf sysfs nicht lesen)"
elif ! grep -q 'allow kernel sysfs file {read open getattr}' "$SP"; then
    _fail "sepolicy.rule: 'allow kernel sysfs file {read open getattr}' fehlt"
elif grep -q ':' "$SP"; then
    _fail "sepolicy.rule: Doppelpunkt-Syntax — ksud parst nur 'src tgt class {perms}'"
else
    _pass "sepolicy.rule: kernel → sysfs file/dir"
fi

# ── 6/6 Governor: k6a-ctl MUSS auf schedutil umstellen (F1) ──────────────────
echo "[6] Governor (schedutil)"
if grep -q '_ensure_gov()' "$MOD/bin/k6a-lib.sh" 2>/dev/null; then
    _pass "k6a-lib.sh: _ensure_gov() definiert"
else
    _fail "k6a-lib.sh: _ensure_gov() fehlt → Governor bleibt performance"
fi
if grep -q 'scaling_governor' "$MOD/bin/k6a-lib.sh" 2>/dev/null; then
    _pass "k6a-lib.sh: scaling_governor-Write vorhanden"
else
    _fail "k6a-lib.sh: scaling_governor-Write fehlt"
fi
if grep -q '_ensure_gov' "$MOD/bin/k6a-controller" 2>/dev/null; then
    _pass "controller ruft _ensure_gov() auf"
else
    _fail "controller ruft _ensure_gov() nicht auf"
fi
if grep -q 'w_checked()' "$MOD/bin/k6a-lib.sh" 2>/dev/null; then
    _pass "k6a-lib.sh: w_checked() definiert"
else
    _fail "k6a-lib.sh: w_checked() fehlt (F8)"
fi
if grep -q 'echo 40' "$MOD/bin/k6a-lib.sh" 2>/dev/null; then
    _fail "k6a-lib.sh: read_temp hartkodiert 40 (F10)"
else
    _pass "k6a-lib.sh: read_temp ohne 40-Fallback"
fi

echo "════════════════════════════════════"
if [ "$FAIL" = "0" ]; then echo " GATE OK — $WARN warn(s)"; exit 0
else echo " GATE FAILED — $FAIL err(s), $WARN warn(s)"; exit 1; fi