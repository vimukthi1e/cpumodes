#!/system/bin/sh
# Power Save mode: apply + verify + retry. Stops any running watchdog first.
# Extra cores (1,2,3,5,6) are taken offline LAST, after settings are set.

MODDIR="${MODDIR:-/data/adb/modules/cpumodes}"
. "$MODDIR/scripts/env.sh"
. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/modes/powersave/config.sh"

apply_mode powersave
