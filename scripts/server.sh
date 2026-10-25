#!/system/bin/sh
# CPU Mode Control - localhost server (busybox httpd + supervisor)
# usage: server.sh start | stop | supervise <port> <token>

MODDIR="${MODDIR:-/data/adb/modules/cpumodes}"
. "$MODDIR/scripts/env.sh"
. "$MODDIR/scripts/lib.sh"

export PATH="/data/adb/ksu/bin:/system/bin:/system/xbin:$PATH"

server_alive() {
    _sp=$(rdi "$RUN/server.pid")
    proc_is "$_sp" httpd
}

# cleanup used by the supervisor itself (never kills the supervisor)
server_stop_silent() {
    _sp=$(rdi "$RUN/server.pid")
    [ -n "$_sp" ] && kill "$_sp" 2>/dev/null
    rm -f "$RUN/server.pid" "$RUN/server.port" "$RUN/token" "$RUN/stop_at" "$RUN/supervisor.pid" 2>/dev/null
}

server_stop() {
    _sp=$(rdi "$RUN/server.pid")
    _vp=$(rdi "$RUN/supervisor.pid")
    [ -n "$_sp" ] && kill "$_sp" 2>/dev/null
    rm -f "$RUN/server.pid" "$RUN/server.port" "$RUN/token" "$RUN/stop_at" 2>/dev/null
    if [ -n "$_vp" ] && proc_is "$_vp" server.sh; then
        kill "$_vp" 2>/dev/null
    fi
    rm -f "$RUN/supervisor.pid" 2>/dev/null
    log "server stopped"
}

supervise() { # supervise <port> <token>
    PORT="$1"; TOKEN="$2"
    mkdir -p "$RUN"
    printf '%s\n' "$$" > "$RUN/supervisor.pid"
    rm -f "$RUN/stop_at"

    # CGI must be executable: httpd execs it directly
    chmod 755 "$WEBROOT/cgi-bin/api.sh" 2>/dev/null

    "$BB" httpd -f -p 127.0.0.1:"$PORT" -h "$WEBROOT" >> "$LOG" 2>&1 &
    HTTPD_PID=$!
    printf '%s\n' "$HTTPD_PID" > "$RUN/server.pid"
    log "server listening on 127.0.0.1:$PORT (httpd pid $HTTPD_PID)"

    while :; do
        # replaced by a newer supervisor? take our httpd down too -
        # never leave an orphan listener holding a port
        [ "$(rdi "$RUN/supervisor.pid")" = "$$" ] || {
            kill "$HTTPD_PID" 2>/dev/null
            exit 0
        }
        # httpd died?
        kill -0 "$HTTPD_PID" 2>/dev/null || { log "httpd died, cleanup"; server_stop_silent; exit 0; }

        _now=$(date +%s)

        # explicit shutdown request (beacon), after grace period
        _st=$(rdi "$RUN/stop_at")
        if [ -n "$_st" ]; then
            _la=$(rdi "$RUN/last_access")
            [ -z "$_la" ] && _la=0
            if [ "$((_now - _st))" -ge "$STOP_GRACE" ] && [ "$_st" -ge "$_la" ]; then
                log "server shutdown (requested by page close)"
                server_stop_silent
                exit 0
            fi
        fi

        # idle fallback (browser crash etc.)
        _la=$(rdi "$RUN/last_access")
        [ -z "$_la" ] && _la=$_now
        if [ "$((_now - _la))" -ge "$IDLE_TIMEOUT" ]; then
            log "server idle exit (${IDLE_TIMEOUT}s without traffic)"
            server_stop_silent
            exit 0
        fi

        sleep 5
    done
}

server_start() {
    mkdir -p "$RUN"
    chmod 700 "$RUN" 2>/dev/null

    if server_alive; then
        return 0
    fi
    rm -f "$RUN/server.pid" "$RUN/server.port" "$RUN/token" "$RUN/stop_at" 2>/dev/null

    _t1=$(rd /proc/sys/kernel/random/uuid | tr -cd '0-9a-f')
    _t2=$(rd /proc/sys/kernel/random/uuid | tr -cd '0-9a-f')
    TOKEN="$_t1$_t2"
    printf '%s\n' "$TOKEN" > "$RUN/token"
    chmod 600 "$RUN/token" 2>/dev/null
    date +%s > "$RUN/last_access"

    for P in $PORTS; do
        printf '%s\n' "$P" > "$RUN/server.port"
        detach_run /system/bin/sh "$MODDIR/scripts/server.sh" supervise "$P" "$TOKEN"
        _i=0
        while [ "$_i" -lt 20 ]; do
            server_alive && break
            sleep 0.2
            _i=$((_i+1))
        done
        if server_alive; then
            if "$BB" wget -q -O /dev/null "http://127.0.0.1:$P/cgi-bin/api.sh?op=ping&token=$TOKEN" 2>/dev/null; then
                log "server ready on port $P"
                return 0
            fi
        fi
        log "port $P failed, trying next"
        rm -f "$RUN/server.pid" 2>/dev/null
    done

    rm -f "$RUN/token" "$RUN/server.port" 2>/dev/null
    log "server start FAILED (all ports refused)"
    return 1
}

case "$1" in
    start)    server_start ;;
    stop)     server_stop ;;
    supervise) supervise "$2" "$3" ;;
esac
