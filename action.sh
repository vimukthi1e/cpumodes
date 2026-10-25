#!/system/bin/sh
# KernelSU action button: start (or reuse) the localhost server,
# then open the control panel in the browser.

MODDIR="${0%/*}"
[ -d "$MODDIR/scripts" ] || MODDIR=/data/adb/modules/cpumodes
export MODDIR
. "$MODDIR/scripts/env.sh"
. "$MODDIR/scripts/lib.sh"

mkdir -p "$RUN"
sh "$MODDIR/scripts/server.sh" start

PORT=$(rdi "$RUN/server.port")
TOKEN=$(rdi "$RUN/token")

if [ -n "$PORT" ] && [ -n "$TOKEN" ]; then
    /system/bin/am start -a android.intent.action.VIEW \
        -d "http://127.0.0.1:$PORT/?token=$TOKEN" >/dev/null 2>&1
    log "action: panel served on port $PORT"
    echo "CPU Mode Control"
    echo "http://127.0.0.1:$PORT"
else
    log "action: server start FAILED"
    echo "CPU Mode Control: server failed to start"
    echo "Check log: $LOG"
    exit 1
fi
