#!/system/bin/sh
# Performance mode: apply + verify + retry, arm watchdog on success.

MODDIR="${MODDIR:-/data/adb/modules/cpumodes}"
. "$MODDIR/scripts/env.sh"
. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/modes/performance/config.sh"

apply_mode performance
