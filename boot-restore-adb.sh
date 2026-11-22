#!/data/data/com.termux/files/usr/bin/bash

# Restore a fixed ADB TCP port from this phone's already-paired wireless ADB.
# VERSION is the release of this file and of the host CLI (termux-adb).
VERSION=0.3.1
if [[ ${1:-} == --version ]]; then
    printf '%s\n' "boot-restore-adb.sh $VERSION"
    exit 0
fi
if [[ ${1:-} == --help ]]; then
    printf '%s\n' "boot-restore-adb.sh $VERSION" \
        'Usage: boot-restore-adb.sh [--once | --watch [SECONDS]]' \
        '  (no argument, as run by Termux:Boot) hold a wake lock, start sshd if installed,' \
        '  restore once, then keep a background watch that re-opens the port whenever it closes.' \
        '  --once   restore once and exit (1 when the port could not be restored)' \
        '  --watch  check every SECONDS (default 60): re-open the port when closed, switch Wireless debugging back on when off' \
        '  --version  print the script version' \
        'ADB_RESTORE_PORT          TCP port to restore (default: 5555)' \
        'ADB_RESTORE_WAKE_LOCK     1 holds a Termux wake lock (default), 0 saves battery on phones' \
        'ADB_RESTORE_WATCH_INTERVAL  Seconds between watch checks after boot (default: 60)' \
        'ADB_RESTORE_LOG           Log path (default: ~/.termux/boot.log)' \
        'ADB_RESTORE_VPN_APP       Optional Android package for always-on VPN' \
        'ADB_RESTORE_VPN_LOCKDOWN  Optional 0 or 1, with ADB_RESTORE_VPN_APP'
    exit 0
fi

# Optional per-device settings written by `termux-adb install --battery-saver`.
# shellcheck source=/dev/null
[[ -f "$HOME/.termux/boot-restore-adb.env" ]] && . "$HOME/.termux/boot-restore-adb.env"
PORT=${ADB_RESTORE_PORT:-5555}
WAKE_LOCK=${ADB_RESTORE_WAKE_LOCK:-1}
WATCH_INTERVAL=${ADB_RESTORE_WATCH_INTERVAL:-60}
LOGFILE=${ADB_RESTORE_LOG:-"$HOME/.termux/boot.log"}
VPN_APP=${ADB_RESTORE_VPN_APP:-}
VPN_LOCKDOWN=${ADB_RESTORE_VPN_LOCKDOWN:-}
if [[ ! $PORT =~ ^[1-9][0-9]{0,4}$ ]] || (( PORT > 65535 )); then
    printf '%s\n' 'ADB_RESTORE_PORT must be between 1 and 65535.' >&2
    exit 2
fi
if [[ -n $VPN_APP && ! $VPN_APP =~ ^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$ ]]; then
    printf '%s\n' 'ADB_RESTORE_VPN_APP must be an Android package name.' >&2
    exit 2
fi
if [[ -n $VPN_LOCKDOWN && ( -z $VPN_APP || ! $VPN_LOCKDOWN =~ ^[01]$ ) ]]; then
    printf '%s\n' 'ADB_RESTORE_VPN_LOCKDOWN requires a VPN package and a value of 0 or 1.' >&2
    exit 2
fi
ENDPOINT="127.0.0.1:$PORT"
# adb's server needs a writable TMPDIR. Termux:Boot sets it, but a start over
# SSH or run-as may not, and then every adb call fails with "cannot connect to daemon".
export TMPDIR=${TMPDIR:-${PREFIX:-/data/data/com.termux/files/usr}/tmp}
WATCH_PIDFILE="$HOME/.termux/boot-restore-adb.watch.pid"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOGFILE"
}

# One watch per device. The boot run, a keeper trigger and a manual start all
# end up here, and a second watch would double every scan and log line.
watch_pid() {
    local pid
    [[ -f $WATCH_PIDFILE ]] || return 1
    read -r pid < "$WATCH_PIDFILE" || return 1
    [[ $pid =~ ^[0-9]+$ ]] || return 1
    kill -0 "$pid" 2>/dev/null || return 1
    tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | grep -q 'boot-restore-adb.sh' || return 1
    printf '%s\n' "$pid"
}

restore_settings() {
    adb connect "$ENDPOINT" >/dev/null 2>&1 || true
    adb -s "$ENDPOINT" shell settings put global adb_wifi_enabled 1 2>/dev/null || true
    if [[ -n $VPN_APP ]]; then
        adb -s "$ENDPOINT" shell settings put secure always_on_vpn_app "$VPN_APP" 2>/dev/null || true
        adb -s "$ENDPOINT" shell cmd deviceidle whitelist "+$VPN_APP" >/dev/null 2>&1 || true
    fi
    if [[ -n $VPN_LOCKDOWN ]]; then
        adb -s "$ENDPOINT" shell settings put secure always_on_vpn_lockdown "$VPN_LOCKDOWN" 2>/dev/null || true
    fi
}

mkdir -p "$(dirname "$LOGFILE")" || exit 1
log "=========================================="
log "Termux:Boot ADB Restore Service Started"
log "PID: $$ | UID: $(id -u) | USER: $(whoami)"

# Wait for system boot completion
MAX_BOOT_WAIT=40
for ((i=1; i<=MAX_BOOT_WAIT; i++)); do
    BOOT_STATE=$(getprop sys.boot_completed 2>/dev/null)
    if [ "$BOOT_STATE" = "1" ]; then
        log "System boot completed detected (waited ${i}s)."
        break
    fi
    sleep 1
done

# Function to test TCP port connectivity
check_port() {
    local target_port="$1"
    (echo > /dev/tcp/127.0.0.1/"$target_port") 2>/dev/null
}


restore_once() {
    # Clean up any stale adb daemon state before connecting
    adb kill-server >/dev/null 2>&1 || true
    sleep 1

    # Attempt discovery of Wireless Debugging TLS port
    local MAX_ATTEMPTS=${1:-12}
    SUCCESS=0

    for ((attempt=1; attempt<=MAX_ATTEMPTS; attempt++)); do
        log "Discovery attempt $attempt/$MAX_ATTEMPTS: Scanning localhost 30000-50000..."
        CANDIDATES=$(nmap -sT -p 30000-50000 -T5 --open 127.0.0.1 -oG - 2>/dev/null | grep "Ports:" | grep -oE "[0-9]+/open" | cut -d/ -f1)
    
        if [ -n "$CANDIDATES" ]; then
            log "Found open candidate port(s): $CANDIDATES"
            for p in $CANDIDATES; do
                log "Connecting to 127.0.0.1:$p..."
                CONN_RES=$(adb connect 127.0.0.1:"$p" 2>&1)
                log "adb connect result: $CONN_RES"
            
                # Wait up to 6 seconds for connection to transition to 'device' state (TLS handshake)
                DEV_STATE=""
                for ((w=1; w<=6; w++)); do
                    DEV_STATE=$(adb -s 127.0.0.1:"$p" get-state 2>/dev/null)
                    if [ "$DEV_STATE" = "device" ]; then
                        break
                    fi
                    sleep 1
                done
                log "State on 127.0.0.1:$p after wait: $DEV_STATE"

                if [ "$DEV_STATE" = "device" ]; then
                    log "Device authorized. Requesting tcpip $PORT."
                    TCPIP_RES=$(adb -s 127.0.0.1:"$p" tcpip "$PORT" 2>&1)
                    log "adb tcpip result: $TCPIP_RES"
                    sleep 2
                    if check_port "$PORT"; then
                        log "SUCCESS: TCP port $PORT is now listening."
                        restore_settings
                        SUCCESS=1
                        break 2
                    else
                        log "WARNING: Port $PORT not responding yet after tcpip command. Waiting 2s."
                        sleep 2
                        if check_port "$PORT"; then
                            log "SUCCESS: TCP port $PORT is listening on recheck."
                            restore_settings
                            SUCCESS=1
                            break 2
                        fi
                    fi
                else
                    log "Port $p did not reach device state (state='$DEV_STATE'). Disconnecting..."
                    adb disconnect 127.0.0.1:"$p" >/dev/null 2>&1 || true
                fi
            done
        else
            log "No open ports found in 30000-50000 on attempt $attempt."
        fi
    
        if [ "$attempt" -lt "$MAX_ATTEMPTS" ]; then
            log "Sleeping 5 seconds before next scan attempt..."
            adb kill-server >/dev/null 2>&1 || true
            sleep 5
        fi
    done

    [ $SUCCESS -eq 1 ]
}

# Network facts at the moment the port was found closed, so the real cause can be found later.
# Android hides network state from app processes, so read it through the shell on the open port.
log_network() {
    local wifi
    wifi=$(adb -s "$ENDPOINT" shell 'cmd wifi status 2>/dev/null | head -2' 2>/dev/null | tr '\r\n' '  ')
    log "Network: ${wifi:-unreadable (port $PORT closed)}"
}

# Android turns Wireless debugging off on reboot and when Wi-Fi drops or changes. With it off, a
# later adbd restart cannot be recovered, so the watch switches it back on through the open port.
ensure_wifi_debugging() {
    adb connect "$ENDPOINT" >/dev/null 2>&1 || true
    local state
    state=$(adb -s "$ENDPOINT" shell settings get global adb_wifi_enabled 2>/dev/null | tr -d '\r')
    if [ "$state" != "1" ]; then
        log "Wireless debugging is off (adb_wifi_enabled=${state:-unreadable}); switching it on."
        log_network
        adb -s "$ENDPOINT" shell settings put global adb_wifi_enabled 1 2>/dev/null || true
        state=$(adb -s "$ENDPOINT" shell settings get global adb_wifi_enabled 2>/dev/null | tr -d '\r')
        log "Wireless debugging now adb_wifi_enabled=${state:-unreadable} (Android keeps it off without Wi-Fi)."
    fi
}

watch_loop() {
    local interval=${1:-60} down=0
    log "Watch started: checking port $PORT every ${interval}s."
    while true; do
        if check_port "$PORT"; then
            if [ $down -eq 1 ]; then log "Port $PORT is back."; fi
            down=0
            ensure_wifi_debugging
        else
            log "Port $PORT is closed."
            log_network
            down=1
            if restore_once 3; then
                log "Watch: port $PORT restored."
                down=0
            else
                log "Watch: restore failed (wireless debugging off or no Wi-Fi?); retrying in ${interval}s."
            fi
        fi
        sleep "$interval"
    done
}

case ${1:-} in
    --once)
        if check_port "$PORT"; then log "Port $PORT is already open."; restore_settings; exit 0; fi
        restore_once 12 || { log "ERROR: restore failed."; exit 1; }
        log "ADB restore completed."; exit 0 ;;
    --watch)
        RUNNING=$(watch_pid) || RUNNING=""
        if [[ -n $RUNNING && $RUNNING != "$$" ]]; then
            log "Watch already running (pid $RUNNING); this start exits."
            exit 0
        fi
        mkdir -p "$(dirname "$WATCH_PIDFILE")"
        echo "$$" > "$WATCH_PIDFILE"
        watch_loop "${2:-60}" ;;
    "")
        if [[ $WAKE_LOCK == 1 ]]; then command -v termux-wake-lock >/dev/null && termux-wake-lock; fi
        if command -v sshd >/dev/null && ! pgrep -x sshd >/dev/null; then
            sshd && log "sshd started (port 8022)."
        fi
        if check_port "$PORT"; then
            log "Port $PORT is already open."; restore_settings
        elif restore_once 12; then
            log "ADB Boot Restore completed successfully."
        else
            log "ERROR: ADB Boot Restore failed; the watch keeps retrying."
        fi
        RUNNING=$(watch_pid) || RUNNING=""
        if [[ -n $RUNNING ]]; then
            log "Background watch already running (pid $RUNNING)."
        else
            nohup "$0" --watch "$WATCH_INTERVAL" >/dev/null 2>&1 &
            mkdir -p "$(dirname "$WATCH_PIDFILE")"
            echo "$!" > "$WATCH_PIDFILE"
            log "Background watch started (pid $!)."
        fi
        log "==========================================" ;;
    *) printf '%s\n' "Unknown option: $1 (see --help)" >&2; exit 2 ;;
esac
