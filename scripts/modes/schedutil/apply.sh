#!/system/bin/sh
# Schedutil mode: apply + verify + retry. Stops any running watchdog first.

MODDIR="${MODDIR:-/data/adb/modules/cpumodes}"
. "$MODDIR/scripts/env.sh"
. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/modes/schedutil/config.sh"

apply_mode schedutil
