#!/system/bin/sh
# CPU Mode Control - shared helpers (sourced, never executed directly)
# Requires env.sh to be sourced first.

# ---------- logging (size-capped) ----------
log() {
    mkdir -p "$RUN" 2>/dev/null
    printf '[%s] %s\n' "$(date '+%F %T')" "$*" >> "$LOG" 2>/dev/null
    if [ -f "$LOG" ]; then
        _lsz=$(stat -c%s "$LOG" 2>/dev/null)
        case "$_lsz" in ''|*[!0-9]*) _lsz=0 ;; esac
        if [ "$_lsz" -gt 200000 ]; then
            "$BB" tail -c 100000 "$LOG" > "$LOG.tmp" 2>/dev/null && mv -f "$LOG.tmp" "$LOG"
        fi
    fi
}

# ---------- sysfs io ----------
rd()  { cat "$1" 2>/dev/null; }
rdi() { rd "$1" | tr -d ' \t\n'; }
wr()  { printf '%s\n' "$1" > "$2" 2>/dev/null; }

# ---------- process helpers ----------
proc_alive() { [ -n "$1" ] && [ -d "/proc/$1" ]; }
proc_is()    { [ -n "$1" ] && tr '\0' ' ' < "/proc/$1/cmdline" 2>/dev/null | grep -q "$2"; }

detach_run() {
    # fd 9 is closed in the child: a long-lived child (watchdog) must
    # never inherit the apply lock, or the lock would be held forever.
    # Nested subshell = immediate return + reparent to init; setsid (no
    # flags - busybox builds differ on -f support) is used when present.
    if "$BB" --list 2>/dev/null | grep -q '^setsid$'; then
        ( "$BB" setsid "$@" >/dev/null 2>&1 < /dev/null 9>&- & )
    else
        ( "$@" >/dev/null 2>&1 < /dev/null 9>&- & )
    fi
}

# ---------- cluster topology (resolved at runtime, never guessed) ----------
# Verified on this device: policy0 = CPUs 0,1,2,3 (silver, max 1804800)
#                         policy4 = CPUs 4,5,6   (gold,   max 2419200)
#                         policy7 = CPU 7        (prime,  max 3091200)
resolve_clusters() {
    POL_SILVER=""; POL_GOLD=""; POL_PRIME=""
    for _p in /sys/devices/system/cpu/cpufreq/policy*; do
        [ -d "$_p" ] || continue
        _rc=$(rdi "$_p/related_cpus")
        case "$_rc" in
            "0 1 2 3") POL_SILVER="$_p" ;;
            "4 5 6")   POL_GOLD="$_p" ;;
            "7")       POL_PRIME="$_p" ;;
        esac
    done
    # fallback: identify by max frequency if policy numbering ever changes
    if [ -z "$POL_SILVER" ] || [ -z "$POL_GOLD" ] || [ -z "$POL_PRIME" ]; then
        for _p in /sys/devices/system/cpu/cpufreq/policy*; do
            [ -d "$_p" ] || continue
            _mx=$(rdi "$_p/cpuinfo_max_freq")
            [ "$_mx" = "1804800" ] && [ -z "$POL_SILVER" ] && POL_SILVER="$_p"
            [ "$_mx" = "2419200" ] && [ -z "$POL_GOLD" ]   && POL_GOLD="$_p"
            [ "$_mx" = "3091200" ] && [ -z "$POL_PRIME" ]  && POL_PRIME="$_p"
        done
    fi
}

# ---------- core online/offline ----------
core_online() {
    _v=$(rdi "$SYS_CPU/cpu$1/online")
    [ -z "$_v" ] && _v=1          # no online file = always-on core
    [ "$_v" = "1" ]
}

set_core() { wr "$2" "$SYS_CPU/cpu$1/online"; }

online_all_cores() {
    for _c in 0 1 2 3 4 5 6 7; do
        core_online "$_c" || set_core "$_c" 1
    done
}

# expects ONLINE_ALL / KEEP_CORES from the sourced mode config
core_wanted() {
    if [ "$ONLINE_ALL" = "1" ]; then return 0; fi
    for _k in $KEEP_CORES; do
        [ "$_k" = "$1" ] && return 0
    done
    return 1
}

# ---------- cluster / gpu writes (Linux-correct safe order) ----------
cluster_write() { # cluster_write <policy> <gov> <min> <max>
    _pol="$1"; _gov="$2"; _tmin="$3"; _tmax="$4"
    [ -d "$_pol" ] || return 1
    _hwmin=$(rdi "$_pol/cpuinfo_min_freq")
    [ -z "$_hwmin" ] && _hwmin="$_tmin"
    wr "$_gov"   "$_pol/scaling_governor"   # governor first (a switch can reset limits)
    wr "$_hwmin" "$_pol/scaling_min_freq"   # floor min so max can move freely
    wr "$_tmax"  "$_pol/scaling_max_freq"
    wr "$_tmin"  "$_pol/scaling_min_freq"
}

gpu_write() { # gpu_write <gov>  (GPU frequencies are NEVER touched)
    wr "$1" "$GPU_DF/governor"
}

# ---------- verify (readback against sourced mode config) ----------
# prints a ';'-separated mismatch list; empty output = everything matches
verify_state() {
    _bad=""
    resolve_clusters

    _g=$(rdi "$POL_SILVER/scaling_governor")
    [ "$_g" = "$GOV_SILVER" ] || _bad="$_bad;C1 gov=$_g want=$GOV_SILVER"
    _v=$(rdi "$POL_SILVER/scaling_min_freq")
    [ "$_v" = "$MIN_SILVER" ] || _bad="$_bad;C1 min=$_v want=$MIN_SILVER"
    _v=$(rdi "$POL_SILVER/scaling_max_freq")
    [ "$_v" = "$MAX_SILVER" ] || _bad="$_bad;C1 max=$_v want=$MAX_SILVER"

    _g=$(rdi "$POL_GOLD/scaling_governor")
    [ "$_g" = "$GOV_GOLD" ] || _bad="$_bad;C2 gov=$_g want=$GOV_GOLD"
    _v=$(rdi "$POL_GOLD/scaling_min_freq")
    [ "$_v" = "$MIN_GOLD" ] || _bad="$_bad;C2 min=$_v want=$MIN_GOLD"
    _v=$(rdi "$POL_GOLD/scaling_max_freq")
    [ "$_v" = "$MAX_GOLD" ] || _bad="$_bad;C2 max=$_v want=$MAX_GOLD"

    _g=$(rdi "$POL_PRIME/scaling_governor")
    [ "$_g" = "$GOV_PRIME" ] || _bad="$_bad;C3 gov=$_g want=$GOV_PRIME"
    _v=$(rdi "$POL_PRIME/scaling_min_freq")
    [ "$_v" = "$MIN_PRIME" ] || _bad="$_bad;C3 min=$_v want=$MIN_PRIME"
    _v=$(rdi "$POL_PRIME/scaling_max_freq")
    [ "$_v" = "$MAX_PRIME" ] || _bad="$_bad;C3 max=$_v want=$MAX_PRIME"

    for _c in 0 1 2 3 4 5 6 7; do
        if core_online "$_c"; then _o=1; else _o=0; fi
        if core_wanted "$_c"; then _w=1; else _w=0; fi
        [ "$_o" = "$_w" ] || _bad="$_bad;cpu$_c on=$_o want=$_w"
    done

    _g=$(rdi "$GPU_DF/governor")
    [ "$_g" = "$GPU_GOV" ] || _bad="$_bad;gpu gov=$_g want=$GPU_GOV"

    printf '%s' "$_bad"
}

# ---------- apply a mode (config must be sourced already) ----------
do_apply() {
    resolve_clusters
    # 1) all cores online first: an offline cluster's policy may not accept writes
    online_all_cores
    # 2) clusters, safe order
    cluster_write "$POL_SILVER" "$GOV_SILVER" "$MIN_SILVER" "$MAX_SILVER"
    cluster_write "$POL_GOLD"   "$GOV_GOLD"   "$MIN_GOLD"   "$MAX_GOLD"
    cluster_write "$POL_PRIME"  "$GOV_PRIME"  "$MIN_PRIME"  "$MAX_PRIME"
    # 3) gpu governor only
    gpu_write "$GPU_GOV"
    # 4) power save: drop the extra cores LAST, after settings are in place
    if [ "$ONLINE_ALL" != "1" ]; then
        for _c in 0 1 2 3 4 5 6 7; do
            core_wanted "$_c" || set_core "$_c" 0
        done
    fi
}

# ---------- watchdog control ----------
stop_watchdog() {
    _wp=$(rdi "$RUN/watchdog.pid")
    if [ -n "$_wp" ] && proc_is "$_wp" watchdog.sh; then
        kill "$_wp" 2>/dev/null
        _i=0
        while proc_is "$_wp" watchdog.sh && [ "$_i" -lt 20 ]; do
            sleep 0.1
            _i=$((_i+1))
        done
        proc_is "$_wp" watchdog.sh && kill -9 "$_wp" 2>/dev/null
        log "watchdog stopped (pid $_wp)"
    fi
    rm -f "$RUN/watchdog.pid" "$RUN/watchdog.state" 2>/dev/null
}

start_watchdog() {
    rm -f "$RUN/watchdog.pid" "$RUN/watchdog.state" 2>/dev/null
    detach_run /system/bin/sh "$MODDIR/scripts/watchdog/watchdog.sh"
}

# ---------- apply serialization (pure shell: atomic mkdir, no flock) ----------
apply_lock_acquire() {
    _tries=0
    while [ "$_tries" -lt 10 ]; do
        if mkdir "$RUN/apply.lockdir" 2>/dev/null; then
            printf '%s\n' "$$" > "$RUN/apply.lockdir/pid" 2>/dev/null
            return 0
        fi
        # holder dead (killed mid-apply)? clean the stale lock
        _lp=$(rdi "$RUN/apply.lockdir/pid")
        if [ -z "$_lp" ] || ! proc_is "$_lp" apply.sh; then
            rm -rf "$RUN/apply.lockdir" 2>/dev/null
        fi
        _tries=$((_tries+1))
        sleep 0.1
    done
    log "apply lock busy (holder pid ${_lp:-unknown})"
    return 1
}

apply_lock_release() {
    rm -rf "$RUN/apply.lockdir" 2>/dev/null
}

# ---------- apply engine: apply -> verify -> retry until deadline ----------
# prints a single JSON object on stdout (consumed by the WebUI)
apply_mode() { # apply_mode <mode-name>
    _mode="$1"
    mkdir -p "$RUN"
    if ! apply_lock_acquire; then
        printf '{"ok":false,"error":"busy"}'
        return
    fi
    # always release, even if killed mid-apply
    trap 'apply_lock_release' EXIT INT TERM
    _t0=$(date +%s)
    _dl=$((_t0 + APPLY_DEADLINE))

    stop_watchdog

    _att=0
    _bad="not-checked"
    while :; do
        _att=$((_att+1))
        do_apply
        _bad=$(verify_state)
        [ -z "$_bad" ] && break
        [ "$(date +%s)" -ge "$_dl" ] && break
        sleep 0.5
    done
    _el=$(( $(date +%s) - _t0 ))

    if [ -z "$_bad" ]; then
        printf '%s\n' "$_mode" > "$RUN/mode"
        log "apply [$_mode] OK in ${_el}s (attempts: $_att)"
        if [ "$WATCHDOG" = "1" ]; then
            start_watchdog
            log "watchdog armed: first check in ${WATCHDOG_FIRST_CHECK}s"
        fi
        printf '{"ok":true,"mode":"%s","elapsed":%s,"attempts":%s}' "$_mode" "$_el" "$_att"
    else
        printf 'none\n' > "$RUN/mode"
        log "apply [$_mode] FAILED after ${_el}s:$_bad"
        printf '{"ok":false,"mode":"%s","elapsed":%s,"attempts":%s,"detail":"%s"}' \
            "$_mode" "$_el" "$_att" "${_bad#;}"
    fi
    apply_lock_release
    trap - EXIT INT TERM
}
