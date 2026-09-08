#!/usr/bin/env sh
# k6a-ctl build.sh — Gate MUSS grün sein, sonst kein Zip
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
VER=$(grep '^version=' "$SRC/module.prop" 2>/dev/null | cut -d= -f2 | tr -d ' \r\n')
[ -z "$VER" ] && VER="0.0.0"
OUT="$SRC/../k6a-ctl-v${VER}.zip"
OUT_GENERIC="$SRC/../k6a-ctl.zip"

echo "── Gate-Check ──"
sh "$SRC/bin/check_module.sh" "$SRC" || { echo "BUILD ABORTED (gate)"; exit 1; }

rm -f "$OUT" "$OUT_GENERIC"
find "$SRC" -type f \
    ! -path '*/.git/*' ! -path '*/run/*' \
    ! -path '*/config/service.log' ! -path '*/webroot/data.txt' ! -path '*/config/*.log' \
    ! -name '*.swp' ! -name '*~' ! -name 'check_module.sh' ! -name 'build.sh' \
    | sed "s|^$SRC/||" | sort | (cd "$SRC" && zip -q -FS "$OUT" -@)
cp -f "$OUT" "$OUT_GENERIC" 2>/dev/null || true

echo "Built: $OUT ($(wc -c < "$OUT") bytes) + $OUT_GENERIC"