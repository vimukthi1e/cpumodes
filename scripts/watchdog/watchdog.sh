#!/system/bin/sh
# CPU Mode Control - adaptive watchdog (performance mode ONLY)
#
# Cycle rules (as specified):
#   - starts WATCHDOG_FIRST_CHECK (20s) after being armed
#   - clean check  -> next check in 60s
#   - any deviation -> fix it, drop to 10s cycle
#   - 10s cycle: 10 consecutive clean checks (=100s) -> back to 60s
#   - 60s cycle: any deviation -> fix + back to 10s
#   - runs until another mode is applied or reboot
#   - never exits on errors; keeps guarding

MODDIR="${MODDIR:-/data/adb/modules/cpumodes}"
. "$MODDIR/scripts/env.sh"
. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/modes/performance/config.sh"

mkdir -p "$RUN"
MYPID=$$
printf '%s\n' "$MYPID" > "$RUN/watchdog.pid.tmp"
mv -f "$RUN/watchdog.pid.tmp" "$RUN/watchdog.pid"
log "watchdog started (pid $MYPID), first check in ${WATCHDOG_FIRST_CHECK}s"

# heartbeat immediately, so the UI shows a sane cycle during the arm delay
printf 'interval=60 clean=0 last=%s\n' "$(date +%s)" > "$RUN/watchdog.state.tmp"
mv -f "$RUN/watchdog.state.tmp" "$RUN/watchdog.state"

sleep "$WATCHDOG_FIRST_CHECK"

INTERVAL=60
CLEAN=0

while :; do
    # stop conditions: replaced, or mode is no longer performance
    if [ "$(rdi "$RUN/watchdog.pid")" != "$MYPID" ]; then
        exit 0
    fi
    if [ "$(rd "$RUN/mode" | tr -d ' \n')" != "performance" ]; then
        rm -f "$RUN/watchdog.pid" "$RUN/watchdog.state" 2>/dev/null
        log "watchdog: mode changed, exiting"
        exit 0
    fi

    BAD=$(verify_state)

    if [ -z "$BAD" ]; then
        if [ "$INTERVAL" = "10" ]; then
            CLEAN=$((CLEAN+1))
            if [ "$CLEAN" -ge 10 ]; then
                INTERVAL=60
                CLEAN=0
                log "watchdog: 100s clean, back to 60s cycle"
            fi
        fi
    else
        log "watchdog: deviation ->${BAD}"
        do_apply
        INTERVAL=10
        CLEAN=0
        log "watchdog: fixed, 10s cycle"
    fi

    printf 'interval=%s clean=%s last=%s\n' "$INTERVAL" "$CLEAN" "$(date +%s)" > "$RUN/watchdog.state.tmp"
    mv -f "$RUN/watchdog.state.tmp" "$RUN/watchdog.state"

    sleep "$INTERVAL"
done
