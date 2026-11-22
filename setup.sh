#!/data/data/com.termux/files/usr/bin/bash
# Set up Termux:Boot without requiring a debuggable Termux build.
set -eu
battery=0
key=
vpn=
while [ "$#" -gt 0 ]; do
    case $1 in
        --battery-saver) battery=1; shift ;;
        --vpn-app) [ "$#" -ge 2 ] || { echo 'Missing VPN package' >&2; exit 2; }; vpn=$2; shift 2 ;;
        --ssh-key) [ "$#" -ge 2 ] || { echo 'Missing SSH key' >&2; exit 2; }; key=$2; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done
yes | pkg install -y -o Dpkg::Options::=--force-confold openssh android-tools nmap
mkdir -p "$HOME/.termux/boot" "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
base=https://raw.githubusercontent.com/elfenomenokim/termux-boot-adb-tcp/main
local_script=$(dirname -- "${BASH_SOURCE[0]:-/dev/null}")/boot-restore-adb.sh
# Write a new file and rename it: a running watch keeps reading the old inode
# instead of a half-overwritten script.
target="$HOME/.termux/boot/boot-restore-adb.sh"
if [ -f "$local_script" ]; then
    cp "$local_script" "$target.new"
else
    curl -fsSL "$base/boot-restore-adb.sh" -o "$target.new"
fi
chmod 700 "$target.new"
mv -f "$target.new" "$target"
envfile="$HOME/.termux/boot-restore-adb.env"
rm -f "$envfile"
if [ "$battery" -eq 1 ]; then
    printf '%s\n' 'ADB_RESTORE_WAKE_LOCK=0' 'ADB_RESTORE_WATCH_INTERVAL=300' >> "$envfile"
fi
# The watch sets this as Android's always-on VPN once its adb port is up, so the
# VPN reconnects by itself after a reboot or a system update.
if [ -n "$vpn" ]; then
    printf 'ADB_RESTORE_VPN_APP=%s\n' "$vpn" >> "$envfile"
fi
[ ! -f "$envfile" ] || chmod 600 "$envfile"
if [ -n "$key" ]; then
    touch "$HOME/.ssh/authorized_keys"
    key_id=$(printf '%s\n' "$key" | awk '{print $1, $2}')
    if ! awk '{print $1, $2}' "$HOME/.ssh/authorized_keys" | grep -qxF "$key_id"; then
        printf '%s\n' "$key" >> "$HOME/.ssh/authorized_keys"
    fi
    chmod 600 "$HOME/.ssh/authorized_keys"
fi
if ! pgrep -x sshd >/dev/null 2>&1; then sshd; fi
# The restore scans for the Wireless debugging port and can take a minute; run it
# in the background like Termux:Boot does.
nohup bash "$HOME/.termux/boot/boot-restore-adb.sh" >/dev/null 2>&1 &
printf '%s\n' \
    "Termux user: $(whoami)" \
    'SSH port: 8022' \
    'Next:' \
    '  1. Open the Termux:Boot app once (Android only delivers boot events after that).' \
    '  2. When Android asks "Allow USB debugging?", tick "Always allow" and tap Allow.' \
    '     That dialog is this Termux adb client; without it the watch cannot re-enable Wireless debugging.' \
    '  3. On the computer: termux-adb --device HOST:5555 install, then termux-adb --device HOST:5555 doctor' \
    "Log: $HOME/.termux/boot.log"
