#!/system/bin/sh
# CPU Mode Control - CGI entry point (executed by busybox httpd)
# ops: ping | status | apply&mode=<name> | shutdown   (every op requires token)

MODDIR=/data/adb/modules/cpumodes
. "$MODDIR/scripts/env.sh"
. "$MODDIR/scripts/lib.sh"

export PATH="/data/adb/ksu/bin:/system/bin:/system/xbin:$PATH"

OP=""; TOK=""; MODE=""
_oldifs=$IFS
IFS='&'
for _kv in $QUERY_STRING; do
    _k=${_kv%%=*}
    _v=${_kv#*=}
    [ "$_k" = "$_kv" ] && _v=""
    case "$_k" in
        op)    OP="$_v" ;;
        token) TOK="$_v" ;;
        mode)  MODE="$_v" ;;
    esac
done
IFS=$_oldifs

hdr() {
    printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'
}

# --- token gate: no valid token, no API access ---
_ST=$(rd "$RUN/token")
if [ -z "$_ST" ] || [ "$TOK" != "$_ST" ]; then
    hdr
    printf '{"ok":false,"error":"forbidden"}'
    exit 0
fi

mkdir -p "$RUN"
date +%s > "$RUN/last_access"
# live traffic cancels a pending shutdown (handles page reload)
[ -f "$RUN/stop_at" ] && rm -f "$RUN/stop_at"

case "$OP" in
    ping)
        hdr
        printf '{"ok":true,"op":"ping"}'
        ;;
    status)
        hdr
        sh "$MODDIR/scripts/status.sh"
        ;;
    apply)
        case "$MODE" in
            performance|schedutil|powersave)
                hdr
                sh "$MODDIR/scripts/modes/$MODE/apply.sh"
                ;;
            *)
                hdr
                printf '{"ok":false,"error":"bad mode"}'
                ;;
        esac
        ;;
    shutdown)
        hdr
        printf '{"ok":true,"op":"shutdown"}'
        date +%s > "$RUN/stop_at"
        ;;
    *)
        hdr
        printf '{"ok":false,"error":"bad op"}'
        ;;
esac
