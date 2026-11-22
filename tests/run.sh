#!/usr/bin/env bash
# End-to-end tests for termux-adb. A fake adb answers from tests/fixtures, so no
# phone, adb server or network is involved. Run: bash tests/run.sh
set -u

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
CLI=$ROOT/termux-adb
FAKE=$ROOT/tests/fake-adb
WORK=$(mktemp -d "${TMPDIR:-/tmp}/termux-adb-tests.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
# The fake adb sits on PATH under the name the CLI looks for.
mkdir -p "$WORK/bin"
ln -s "$FAKE" "$WORK/bin/adb"
PATH=$WORK/bin:$PATH
export PATH
PASS=0
FAIL=0

ok() {
    PASS=$((PASS + 1))
    printf 'ok - %s\n' "$1"
}

no() {
    FAIL=$((FAIL + 1))
    printf 'not ok - %s\n' "$1"
    printf '%s\n' "$2" | sed 's/^/    # /'
}

sha256_file() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | cut -d' ' -f1
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d' ' -f1
    else
        openssl dgst -sha256 "$1" | awk '{ print $NF }'
    fi
}

# Copy the base fixtures plus one scenario's overrides into its own directory.
scenario() {
    local dir=$WORK/$1
    mkdir -p "$dir"
    cp -R "$ROOT/tests/fixtures/base/." "$dir/"
    if [[ -d $ROOT/tests/fixtures/$1 ]]; then
        cp -R "$ROOT/tests/fixtures/$1/." "$dir/"
    fi
    sha256_file "$ROOT/boot-restore-adb.sh" > "$dir/sha"
    printf '%s' "$dir"
}

# run_cli DIR OUTPUT_FILE ARGS...: run the CLI against the fake adb, keep its output
run_cli() {
    local dir=$1 out=$2
    shift 2
    : > "$dir/calls"
    FAKE_FIXTURES=$dir FAKE_ADB_LOG=$dir/calls \
        "$CLI" "$@" > "$out" 2>&1
}

expect_status() {
    if [[ $3 == "$2" ]]; then
        ok "$1"
    else
        no "$1" "expected exit $2, got $3"
    fi
}

expect_line() {
    if grep -qF -- "$3" "$2"; then
        ok "$1"
    else
        no "$1" "missing line: $3"
        sed 's/^/    # /' "$2"
    fi
}

# --- version and usage ----------------------------------------------------------------

out=$WORK/version.out
"$CLI" --version > "$out" 2>&1
expect_status "termux-adb --version exits 0" 0 $?
expect_line "termux-adb prints its version" "$out" "termux-adb 0.3.1"

bash "$ROOT/boot-restore-adb.sh" --version > "$out" 2>&1
expect_status "boot-restore-adb.sh --version exits 0" 0 $?
expect_line "boot-restore-adb.sh prints the same version" "$out" "boot-restore-adb.sh 0.3.1"

"$CLI" bogus > "$out" 2>&1
expect_status "an unknown command exits 2" 2 $?

"$CLI" --device FAKE123 doctor extra > "$out" 2>&1
expect_status "doctor rejects extra arguments" 2 $?

# --- doctor ---------------------------------------------------------------------------

dir=$(scenario base)
run_cli "$dir" "$dir/out" --device FAKE123 doctor
expect_status "doctor on a healthy device exits 0" 0 $?
expect_line "doctor reads model and Android version" "$dir/out" "✓ adb: SM-X900 · Android 16 · FAKE123"
expect_line "doctor reports the watch" "$dir/out" "✓ watch running (pid 12441)"
expect_line "doctor confirms the installed script" "$dir/out" "✓ boot script installed, sha256 matches 0.3.1"
expect_line "doctor reads the Samsung list" "$dir/out" "✓ samsung: com.termux is not in the auto-disable target list"
expect_line "doctor reports the TCP port" "$dir/out" "✓ adb listens on TCP port 5555"
expect_line "doctor ends with the counts" "$dir/out" "0 problem"

dir=$(scenario disabled)
run_cli "$dir" "$dir/out" --device FAKE123 doctor
expect_status "doctor with a disabled Termux:Boot exits 1" 1 $?
expect_line "doctor names the disabled package" "$dir/out" "✗ com.termux.boot is disabled"
expect_line "doctor prints lastDisabledCaller" "$dir/out" "lastDisabledCaller: auto_disabler"
expect_line "doctor gives the fix" "$dir/out" "fix: termux-adb install"

dir=$(scenario allowlist-missing)
run_cli "$dir" "$dir/out" --device FAKE123 doctor
expect_status "doctor without the battery allow-list exits 1" 1 $?
expect_line "doctor names the package off the allow-list" "$dir/out" "✗ com.termux.boot is not on the battery allow-list"

dir=$(scenario mars-target)
run_cli "$dir" "$dir/out" --device FAKE123 doctor
expect_status "doctor with a MARs target warns without failing" 0 $?
expect_line "doctor names the MARs target" "$dir/out" "! Samsung may auto-disable: com.termux.boot"

# --- keeper ---------------------------------------------------------------------------

dir=$(scenario disabled)
run_cli "$dir" "$dir/out" --device FAKE123 keeper --log "$dir/keeper.log"
expect_status "keeper exits 0" 0 $?
expect_line "keeper re-enables a disabled package" "$dir/out" "re-enabled com.termux.boot"
if grep -qF "pm enable com.termux.boot" "$dir/calls"; then
    ok "keeper sends pm enable to the device"
else
    no "keeper sends pm enable to the device" "no pm enable call recorded"
    sed 's/^/    # /' "$dir/calls"
fi
if grep -q "boot script started\|watch was absent" "$dir/out"; then
    no "keeper leaves a running watch alone" "keeper restarted a running watch"
else
    ok "keeper leaves a running watch alone"
fi

dir=$(scenario watch-missing)
run_cli "$dir" "$dir/out" --device FAKE123 keeper --log "$dir/keeper.log"
expect_status "keeper without a watch exits 0" 0 $?
expect_line "keeper starts the boot script when the watch is gone" "$dir/out" "watch was absent; boot script started"
if grep -qF "boot-restore-adb.sh" "$dir/calls"; then
    ok "keeper asks run-as for the boot script"
else
    no "keeper asks run-as for the boot script" "no start call recorded"
    sed 's/^/    # /' "$dir/calls"
fi

# --- setup and generalized scenarios --------------------------------------------------
dir=$(scenario denied)
touch "$dir/run_as_denied"
run_cli "$dir" "$dir/out" --device FAKE123 install --battery-saver
expect_status "install without run-as returns setup instructions" 0 $?
expect_line "install prints setup one-liner" "$dir/out" "setup.sh | bash -s -- --battery-saver"
dir=$(scenario auth)
printf '604800000\n' > "$dir/auth_timeout"
run_cli "$dir" "$dir/out" --device FAKE123 doctor
expect_status "nonzero auth timeout fails doctor" 1 $?
expect_line "doctor reports auth timeout" "$dir/out" "✗ adb authorization timeout is 604800000"
dir=$(scenario xiaomi)
printf 'Xiaomi\n' > "$dir/manufacturer"
run_cli "$dir" "$dir/out" --device FAKE123 doctor
expect_line "doctor names Xiaomi battery help" "$dir/out" "https://dontkillmyapp.com/xiaomi"
dir=$(scenario notify)
cat > "$WORK/bin/notify" <<'NOTIFY'
#!/usr/bin/env bash
printf '%s\n' "$1" >> "$NOTIFY_LOG"
NOTIFY
chmod +x "$WORK/bin/notify"
export NOTIFY_LOG="$dir/notifications"
touch "$dir/unreachable"
run_cli "$dir" "$dir/out" --device FAKE123 keeper --log "$dir/keeper.log" --notify-cmd "$WORK/bin/notify" --notify-after 2
if [[ ! -e $NOTIFY_LOG ]]; then ok "no early notification"; else no "no early notification" "notification arrived early"; fi
run_cli "$dir" "$dir/out" --device FAKE123 keeper --log "$dir/keeper.log" --notify-cmd "$WORK/bin/notify" --notify-after 2
expect_line "notifies after two failures" "$NOTIFY_LOG" "2 consecutive passes"
rm "$dir/unreachable"
run_cli "$dir" "$dir/out" --device FAKE123 keeper --log "$dir/keeper.log" --notify-cmd "$WORK/bin/notify" --notify-after 2
expect_line "notifies on recovery" "$NOTIFY_LOG" "recovered"
mkdir -p "$WORK/setup-home" "$WORK/setup-bin"
for tool in pkg sshd; do
    printf '#!/bin/sh\nexit 0\n' > "$WORK/setup-bin/$tool"; chmod +x "$WORK/setup-bin/$tool"
done
cat > "$WORK/setup-bin/curl" <<'CURL'
#!/bin/sh
while [ "$#" -gt 0 ]; do
    if [ "$1" = -o ]; then shift; printf '#!/bin/sh\nexit 0\n' > "$1"; exit; fi
    shift
done
CURL
chmod +x "$WORK/setup-bin/curl"
# Run from stdin to exercise the remote-download path.
HOME="$WORK/setup-home" PATH="$WORK/setup-bin:$PATH" bash -s -- --battery-saver --ssh-key 'ssh-ed25519 AAAATEST test' < "$ROOT/setup.sh" > "$WORK/setup.out" 2>&1
expect_status "setup runs in a clean Termux home" 0 $?
if [[ -x $WORK/setup-home/.termux/boot/boot-restore-adb.sh ]]; then ok "setup installs boot script"; else no "setup installs boot script" "script missing"; fi
expect_line "setup adds SSH key" "$WORK/setup-home/.ssh/authorized_keys" 'ssh-ed25519 AAAATEST test'

# --- result ---------------------------------------------------------------------------

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
