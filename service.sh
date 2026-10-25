#!/system/bin/sh
# BOOT-TIME: runtime state cleanup ONLY.
# This module NEVER changes any governor / frequency / core at boot.
# (After a reboot the kernel is back at defaults, so the state files
#  are cleared here to keep the WebUI honest - no fake "active mode".)

MODDIR="${0%/*}"
[ -d "$MODDIR/scripts" ] || MODDIR=/data/adb/modules/cpumodes
export MODDIR
. "$MODDIR/scripts/env.sh"
. "$MODDIR/scripts/lib.sh"

rm -rf "$RUN"
mkdir -p "$RUN"
chmod 700 "$RUN" 2>/dev/null

# zip installs may lose exec bits - restore them now
chmod 755 "$MODDIR/action.sh" "$MODDIR/uninstall.sh" 2>/dev/null
chmod 755 "$MODDIR/webroot/cgi-bin/api.sh" 2>/dev/null
find "$MODDIR/scripts" -name '*.sh' -exec chmod 755 {} \; 2>/dev/null

log "boot: runtime state cleared (no settings touched)"
