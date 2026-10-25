#!/system/bin/sh
# Uninstall: stop watchdog + server, remove runtime files.

MODDIR="${0%/*}"
[ -d "$MODDIR/scripts" ] || MODDIR=/data/adb/modules/cpumodes
export MODDIR
. "$MODDIR/scripts/env.sh"
. "$MODDIR/scripts/lib.sh"

stop_watchdog
sh "$MODDIR/scripts/server.sh" stop
rm -rf "$RUN"
log "uninstalled: server + watchdog stopped"
