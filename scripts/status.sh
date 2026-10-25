#!/system/bin/sh
# CPU Mode Control - live status JSON (real sysfs reads only, no caching)

MODDIR="${MODDIR:-/data/adb/modules/cpumodes}"
. "$MODDIR/scripts/env.sh"
. "$MODDIR/scripts/lib.sh"

resolve_clusters

MODE=$(rd "$RUN/mode" | tr -d ' \n')
[ -z "$MODE" ] && MODE=none

# watchdog state (honest: process must actually exist)
WD_RUN=false
WD_INT=0
_wp=$(rdi "$RUN/watchdog.pid")
if [ -n "$_wp" ] && proc_is "$_wp" watchdog.sh; then
    WD_RUN=true
    _ws=$(rd "$RUN/watchdog.state")
    _int=$(printf '%s' "$_ws" | sed -n 's/.*interval=\([0-9]*\).*/\1/p')
    [ -n "$_int" ] && WD_INT="$_int"
fi

jstr() { # string or null
    if [ -z "$1" ]; then printf 'null'; else printf '"%s"' "$1"; fi
}
jnum() { # integer or null
    case "$1" in
        ''|*[!0-9]*) printf 'null' ;;
        *)           printf '%s' "$1" ;;
    esac
}

cjson() { # cjson <policy> <label> <cpus>
    _pol="$1"; _lab="$2"; _cps="$3"
    _g=""; _c=""; _mn=""; _mx=""
    if [ -n "$_pol" ] && [ -d "$_pol" ]; then
        _g=$(rdi "$_pol/scaling_governor")
        _c=$(rdi "$_pol/scaling_cur_freq")
        _mn=$(rdi "$_pol/scaling_min_freq")
        _mx=$(rdi "$_pol/scaling_max_freq")
    fi
    printf '{"label":"%s","cpus":"%s","gov":%s,"cur":%s,"min":%s,"max":%s}' \
        "$_lab" "$_cps" "$(jstr "$_g")" "$(jnum "$_c")" "$(jnum "$_mn")" "$(jnum "$_mx")"
}

CORES=""
_sep=""
for _c in 0 1 2 3 4 5 6 7; do
    if core_online "$_c"; then _o=1; else _o=0; fi
    CORES="$CORES$_sep{\"c\":$_c,\"on\":$_o}"
    _sep=","
done

_ggov=$(rdi "$GPU_DF/governor")
_gcur=$(rdi "$GPU_DF/cur_freq")

printf '{"ok":true,"ts":%s,"mode":"%s","watchdog":{"running":%s,"interval":%s},"clusters":[%s,%s,%s],"cores":[%s],"gpu":{"gov":%s,"cur":%s}}\n' \
    "$(date +%s)" \
    "$MODE" \
    "$WD_RUN" \
    "$WD_INT" \
    "$(cjson "$POL_SILVER" 'Cluster 1 · Silver' 'CPU 0–3')" \
    "$(cjson "$POL_GOLD"   'Cluster 2 · Gold'   'CPU 4–6')" \
    "$(cjson "$POL_PRIME"  'Cluster 3 · Prime'  'CPU 7')" \
    "$CORES" \
    "$(jstr "$_ggov")" \
    "$(jnum "$_gcur")"
