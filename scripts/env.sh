#!/system/bin/sh
# CPU Mode Control - constants and paths (sourced, never executed directly)

MODID=cpumodes
MODDIR="${MODDIR:-/data/adb/modules/cpumodes}"
BB=/data/adb/ksu/bin/busybox
[ -x "$BB" ] || BB=/data/adb/magisk/busybox

WEBROOT="$MODDIR/webroot"
RUN="$MODDIR/run"
LOG="$MODDIR/module.log"

PORTS="8899 8900 8901"

SYS_CPU=/sys/devices/system/cpu
GPU_DF=/sys/class/kgsl/kgsl-3d0/devfreq

IDLE_TIMEOUT=180       # seconds without API traffic -> server exits
STOP_GRACE=2           # seconds between shutdown request and actual stop
APPLY_DEADLINE=8       # seconds for apply + verify retries (frontend cap is 10)
WATCHDOG_FIRST_CHECK=20
