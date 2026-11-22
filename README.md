<div align="center">

# termux-boot-adb-tcp

A Termux:Boot script and a host CLI that bring a fixed ADB TCP port back after an Android reboot.

[한국어](README.ko.md) · Termux on Android · macOS or Linux on the host

[![license](https://img.shields.io/github/license/elfenomenokim/termux-boot-adb-tcp)](LICENSE)
[![tests](https://github.com/elfenomenokim/termux-boot-adb-tcp/actions/workflows/tests.yml/badge.svg)](https://github.com/elfenomenokim/termux-boot-adb-tcp/actions/workflows/tests.yml)

[Install](#install) · [Quick start](#quick-start) · [Why](#why) · [Reference](#reference) · [Limits](#limits)

</div>

```console
$ termux-adb doctor --device 192.168.0.10:5555
termux-adb 0.2.0 doctor  ·  192.168.0.10:5555

✓ adb: SM-X900 · Android 16 · 192.168.0.10:5555
✓ com.termux 0.118.3
✓ com.termux.boot 0.8.1 launched once
✓ packages enabled
✓ battery allow-list: com.termux
✓ battery allow-list: com.termux.boot
✓ samsung: com.termux is not in the auto-disable target list
! boot script installed, bytes differ from this 0.2.0 copy
    fix: termux-adb install
✓ watch running (pid 12441)
✓ sshd running (pid 12421)
✓ wireless debugging on (adb_wifi_enabled=1)
✓ port 5555 open on 192.168.0.10 (service.adb.tcp.port=5555)
✓ boot.log, last 3 lines
    [2026-11-22 04:04:59] PID: 12441 | UID: 10315 | USER: u0_a315
    [2026-11-22 04:04:59] System boot completed detected (waited 1s).
    [2026-11-22 04:04:59] Watch started: checking port 5555 every 60s.

12 ok, 1 warning, 0 problem
```

<sub>A real run against a Samsung Galaxy Tab S8 that still had the earlier script installed, so
one check warns about those bytes. The address is a placeholder.</sub>

## Install

On the computer, install Android platform-tools, `curl` and `gpg`. On the device, enable Wireless debugging and pair the computer using `adb pair HOST:PAIRING_PORT`, then connect with `adb connect HOST:PORT`. `termux-adb install --fetch-apps` then downloads and installs [Termux](https://github.com/termux/termux-app/releases) and [Termux:Boot](https://github.com/termux/termux-boot/releases) (GitHub builds, sha256-checked) and [KeepADB](https://f-droid.org/packages/de.hohnepeople.keepadb/) (F-Droid, gpg-checked). You can also install Termux and Termux:Boot yourself, from the same source.

An AI agent setting this up for someone follows [AGENTS.md › Set up for a user](AGENTS.md#set-up-for-a-user): the person only enables Developer options, reads out the pairing code and, for remote access, signs in to Tailscale.

Clone this repository on the computer and put `termux-adb` on PATH; keep `boot-restore-adb.sh` beside it.

## Quick start

In Termux, run:

```bash
curl -fsSL https://raw.githubusercontent.com/elfenomenokim/termux-boot-adb-tcp/main/setup.sh | bash -s --
```

Add `--battery-saver`, `--vpn-app com.tailscale.ipn` or `--ssh-key "ssh-ed25519 AAAA..."` after `--` if needed. Run `adb connect 127.0.0.1:5555` in Termux and tap **Always allow** on the device. On the computer:

```bash
termux-adb --device 192.168.0.10:5555 install
termux-adb --device 192.168.0.10:5555 doctor --ssh-port 8022 --ssh-user USER
termux-adb --device 192.168.0.10:5555 keeper --install
```

Use the Termux username printed by setup. SSH diagnostics need SSH authentication. `install --keep-auth-timeout` leaves the Android authorization timeout unchanged. `keeper --notify-cmd /path/to/executable --notify-after 3` sends one message argument after three failed passes and another on recovery; add these flags to `keeper --install` to schedule them.

## What survives a system update

Apps, data, keys and the battery allow-list persist. Port 5555 closes on each reboot; the watch reopens it. A major update may turn Developer options or Wireless debugging off. SSH still works, but ADB needs Wireless debugging to be enabled manually; `doctor` reports its state when reachable. A VPN app such as Tailscale stays off after the update's reboot unless it is Android's always-on VPN: pass `--vpn-app PACKAGE` to `install` or `setup.sh` (verified on the Fold4: Tailscale was off after a One UI update).

The same Fold4 update also turned Wireless debugging off. A Termux script cannot turn it back on: Android refuses `settings` and `content` writes from an app's shell even with `WRITE_SECURE_SETTINGS`. Install [KeepADB](https://f-droid.org/packages/de.hohnepeople.keepadb/) from F-Droid and turn on its Keep-Alive; `termux-adb install` grants it the permission, notifications and Wi-Fi detection, and `doctor` checks it; in KeepADB's setup assistant choose Keep-Alive on and trust your home Wi-Fi. On the Tab S8, switching Wireless debugging off brought it back within 1 s. KeepADB opens the door, and this tool's watch then reopens port 5555, SSH and Termux.

## Why

Wireless debugging turns itself off when Wi-Fi drops, and adbd listens on a **new random
port** every time it restarts. A script that runs at boot can call `adb tcpip 5555` once and
keep checking the port from then on, so the host always connects to the same address.

The second half is the part that fails on its own. Samsung MARs disables apps it considers
idle, and it sets them to `DISABLED_UNTIL_USED` with `lastDisabledCaller: auto_disabler`. A
disabled Termux:Boot never receives `BOOT_COMPLETED`, so after a reboot nothing comes back:
no sshd, no port, no watch. One UI offers no way to exempt Termux: it is absent from the
never-sleeping picker, and the FAS provider needs a system permission. Setting battery usage
to **Unrestricted** adds both packages to the deviceidle allow-list, which removes them from
MARs's target list. `install` does that, and `doctor` later says whether either package came
back into the list.

| | this tool | [Termux:Boot](https://github.com/termux/termux-boot) alone | [wireless-adb-keeper](https://github.com/MBanucu/wireless-adb-keeper) |
|---|---|---|---|
| fixed port on the host | `adb tcpip 5555`, kept open | no | no, follows adbd's random port over mDNS |
| works from the host only | no, Termux setup required | no host part | no, needs an on-device app build |
| detects a disabled Termux:Boot | `doctor`, `keeper` | no | no |
| re-enables after Samsung disables it | yes | no | no, its own app has the same problem |
| needs an APK build on the device | no | no | yes (`openjdk-17`, `aapt`, `d8`, `android.jar`) |

## Reference

### Commands

| Command | Effect |
|---|---|
| `termux-adb install [--ssh-key FILE] [--no-start] [--battery-saver] [--keep-auth-timeout] [--vpn-app PKG] [--fetch-apps]` | Set up the device, copy the boot script, start it, then run `doctor`. `--no-start` skips the immediate start. `--battery-saver` (phones) drops the wake lock and checks every 300 s. `--vpn-app` makes that VPN app the always-on VPN. `--fetch-apps` downloads and installs missing Termux, Termux:Boot and KeepADB. |
| `termux-adb doctor [--ssh-port PORT --ssh-user USER]` | Read-only checks with a fix hint per failed line. Exit 1 when a `✗` appears. |
| `termux-adb keeper [--ssh-port 8022] [--log FILE]` | One recovery pass. Starts the boot script when the watch is gone, or when `--ssh-port` is closed. |
| `termux-adb keeper --install [--interval 300] [--ssh-port 8022]` | Write the scheduler entry that runs one pass every N seconds. One entry per `--device`, so one host can keep a tablet and a phone. Healthy passes write nothing to the log. |
| `termux-adb keeper --uninstall` | Remove that entry. |

The device comes from `--device HOST:PORT` (or `-s SERIAL`), then `TERMUX_ADB_DEVICE`, then
the one device `adb devices` reports. Options are accepted before or after the command.

### What `install` changes on the device

| Step | Device effect |
|---|---|
| `pm enable com.termux`, `pm enable com.termux.boot` | Only runs when `pm list packages -d` lists the package. |
| `cmd deviceidle whitelist +com.termux`, `+com.termux.boot` | Battery usage becomes Unrestricted; Samsung removes both from `mMARsTargetPackages`. |
| `am start -n com.termux.boot/.BootActivity`, then HOME | Termux:Boot records its first launch (`notLaunched=false`). |
| push to `/data/local/tmp`, copy with `run-as` | `~/.termux/boot/boot-restore-adb.sh`, mode 700. Without `run-as`, install prints the Termux setup one-liner. |
| `--ssh-key` | Public key appended to `~/.ssh/authorized_keys` (mode 600), skipped when already present. |
| start | `run-as com.termux … setsid nohup bash .termux/boot/boot-restore-adb.sh`, the same call the keeper makes. |

### Device script

`boot-restore-adb.sh` runs from `~/.termux/boot/` at boot: it takes a wake lock, starts
`sshd` when installed, restores the port once, then watches it every 60 seconds and switches
Wireless debugging back on when Android turned it off. It keeps one watch per device:
`~/.termux/boot-restore-adb.watch.pid` holds the pid, and a second `--watch` start exits 0.

| Setting | Default | Effect |
|---|---|---|
| `ADB_RESTORE_PORT` | 5555 | Port to restore and watch. |
| `ADB_RESTORE_WAKE_LOCK` | 1 | `0` skips the Termux wake lock (set by `--battery-saver`). |
| `ADB_RESTORE_WATCH_INTERVAL` | 60 | Seconds between watch checks after boot (`300` with `--battery-saver`). |
| `ADB_RESTORE_LOG` | `~/.termux/boot.log` | Log path. |
| `ADB_RESTORE_VPN_APP` | unset | Android package for the always-on VPN. |
| `ADB_RESTORE_VPN_LOCKDOWN` | unset | `0` or `1`, requires the VPN package. |

`bash boot-restore-adb.sh --once` restores once and exits; `--watch [SECONDS]` watches only;
`--version` prints `boot-restore-adb.sh 0.3.0`.

### Host environment

| Variable | Default | Effect |
|---|---|---|
| `TERMUX_ADB_DEVICE` | unset | Same as `--device`. |
| `ADB` | `adb` from `PATH` | adb binary to call. |
| `TERMUX_ADB_LOG` | `~/.local/state/termux-adb-keeper.log` | Keeper log; `--log` overrides it. |

Exit codes: `0` ok, `1` a check failed or the device is unreachable, `2` bad usage.

## Limits

Verified on two devices: Samsung Galaxy Tab S8 (SM-X900) and Galaxy Z Fold4 (SM-F936N with
`--battery-saver`), both Android 16, Termux 0.118.3, Termux:Boot 0.8.1. `install`, `doctor` and
`keeper` ran from macOS 26 on Apple Silicon. A Tab S8 reboot with 0.3.0 brought sshd back in
80 s and port 5555 in 111 s with one watch process, untouched. The phone reboot path and Linux scheduler path were not run. Windows hosts are unsupported.

The restore needs an authorized ADB pairing on the device and Wireless debugging available
after boot. `run-as` requires a debuggable Termux build. F-Droid builds can use setup and SSH diagnostics instead.
Samsung's `dumpsys activity mars` is vendor-specific, so that check runs only when
`ro.product.manufacturer` is `samsung`. A vendor update can change its output, and `doctor`
then reports the list as unchecked rather than guessing.

[Contributing](CONTRIBUTING.md) · [MIT license](LICENSE)

This project is independent of Termux, Samsung and Google.
