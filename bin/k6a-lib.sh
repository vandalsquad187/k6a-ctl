#!/system/bin/sh
# k6a-ctl lib v1.0.0 — slim hardware layer for sweet (SM7150-class)
# Rules: no hardcoded freqs, no alias traps, dynamic tables only.

unalias r 2>/dev/null || true

MODDIR=${MODDIR:-/data/adb/modules/k6a-ctl}
GPU=/sys/class/kgsl/kgsl-3d0
P0=/sys/devices/system/cpu/cpufreq/policy0
P6=/sys/devices/system/cpu/cpufreq/policy6
LOG_FILE=${LOG_FILE:-$MODDIR/config/service.log}

log()  { printf '[%s] [INFO] %s\n' "$(date '+%H:%M:%S')" "$1" >> "$LOG_FILE" 2>/dev/null; }
warn() { printf '[%s] [WARN] %s\n' "$(date '+%H:%M:%S')" "$1" >> "$LOG_FILE" 2>/dev/null; }
err()  { printf '[%s] [ERROR] %s\n' "$(date '+%H:%M:%S')" "$1" >> "$LOG_FILE" 2>/dev/null; }
dbg()  { [ "${CFG_DEBUG:-0}" = "1" ] && printf '[%s] [DBG] %s\n' "$(date '+%H:%M:%S')" "$1" >> "$LOG_FILE" 2>/dev/null; }

r() { cat "$1" 2>/dev/null || echo "0"; }
w() { printf '%s' "$2" > "$1" 2>/dev/null; }

# ── dynamic clock tables ────────────────────────────────────────────────────
# liest verfügbare frequenzen, wählt nächst-verfügbaren wert <= ziel-prozent
_init_freq_tables() {
    SILVER_FREQS=$(r "$P0/scaling_available_frequencies")
    GOLD_FREQS=$(r "$P6/scaling_available_frequencies")
    GPU_FREQS=$(r "$GPU/gpu_available_frequencies")

    GOLD_MAX=0; for f in $GOLD_FREQS; do [ "$f" -gt "$GOLD_MAX" ] 2>/dev/null && GOLD_MAX=$f; done
    SILVER_MAX=0; for f in $SILVER_FREQS; do [ "$f" -gt "$SILVER_MAX" ] 2>/dev/null && SILVER_MAX=$f; done
    GPU_MAX=0; for f in $GPU_FREQS; do [ "$f" -gt "$GPU_MAX" ] 2>/dev/null && GPU_MAX=$f; done
    GPU_MIN=999999999; for f in $GPU_FREQS; do [ "$f" -lt "$GPU_MIN" ] 2>/dev/null && GPU_MIN=$f; done
    [ "$GPU_MIN" = 999999999 ] && GPU_MIN=0

    dbg "tables: silver_max=$SILVER_MAX gold_max=$GOLD_MAX gpu=$GPU_MIN-$GPU_MAX"
}

# nächst-niedrigere verfügbare freq <= ziel
_pick_freq() { # $1=table $2=target
    local best=0 f
    for f in $1; do
        [ "$f" -le "$2" ] 2>/dev/null && [ "$f" -gt "$best" ] 2>/dev/null && best=$f
    done
    echo "$best"
}

gold_at_pct() { _pick_freq "$GOLD_FREQS" $(( GOLD_MAX * $1 / 100 )); }
gpu_at_pct()  { _pick_freq "$GPU_FREQS"  $(( GPU_MAX  * $1 / 100 )); }

# ── thermal zones ───────────────────────────────────────────────────────────
_cache_thermal_zones() {
    TZ_GOLD=""; TZ_SILVER=""; TZ_FALLBACK=""
    local zone type
    for zone in /sys/devices/virtual/thermal/thermal_zone*/; do
        [ -d "$zone" ] || continue
        type=$(cat "${zone}type" 2>/dev/null) || continue
        case "$type" in
            *cpu-1-*usr*|*cpu-1-0*|*gold*|*cluster1*) [ -z "$TZ_GOLD" ]   && TZ_GOLD="${zone}temp" ;;
            *cpu-0-*usr*|*cpuss-0*|*silver*|*cluster0*) [ -z "$TZ_SILVER" ] && TZ_SILVER="${zone}temp" ;;
        esac
    done
    [ -z "$TZ_GOLD" ] && TZ_GOLD="/sys/devices/virtual/thermal/thermal_zone0/temp"
    [ -z "$TZ_SILVER" ] && TZ_SILVER="$TZ_FALLBACK"
    log "zones: Gold=$TZ_GOLD Silver=$TZ_SILVER"
}

read_temp() {
    local t
    t=$(cat "$TZ_GOLD" 2>/dev/null); [ -n "$t" ] && echo $(( t / 1000 )) && return
    t=$(cat "$TZ_SILVER" 2>/dev/null); [ -n "$t" ] && echo $(( t / 1000 )) && return
    echo 40
}

# ── cpu/gpu apply ───────────────────────────────────────────────────────────
cpu_apply() { # $1=sil_max $2=gold_max
    w "$P0/scaling_max_freq" "$1"
    w "$P6/scaling_max_freq" "$2"
}

gpu_limits() { # $1=max_hz ($GPU_MAX = frei)
    w "$GPU/devfreq/max_freq" "${1:-$GPU_MAX}"
}

gov_sysfs_exists() { [ -d /sys/kernel/k6a_gov ]; }
