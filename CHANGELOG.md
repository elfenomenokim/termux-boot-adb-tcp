# Changelog

## [0.3.1] - 2026-11-22

### Added

- `--vpn-app PKG` for `install` and `setup.sh`: the VPN app becomes Android's always-on VPN and
  the watch re-applies it and adds the app to the battery allow-list, so Tailscale reconnects after a reboot or system update. `doctor` warns
  when Tailscale is installed but not the always-on VPN.
- KeepADB support: `install` grants it `WRITE_SECURE_SETTINGS` and the battery allow-list, and
  `doctor` checks it, so Wireless debugging comes back after a system update turns it off.

- `install --fetch-apps` downloads and installs missing Termux and Termux:Boot (GitHub builds,
  sha256-checked, waits for Termux's first start) and KeepADB (F-Droid, gpg-checked). `doctor`
  checks that KeepADB's Keep-Alive service runs.
- AGENTS.md starts with "Set up for a user": the steps an agent runs from nothing installed to a
  working device, with the four steps that need the person.

### Fixed

- Package checks pass `--user current`: on a Samsung phone with Secure Folder or Dual Messenger,
  plain `pm list packages` failed, so `doctor` and `install` saw no packages.
- The boot script sets a default `TMPDIR`: started over SSH or run-as, its adb server could not
  start. `doctor` checks Termux adb over SSH directly instead of guessing from boot.log.
- `install` installs missing Termux packages (openssh, android-tools, nmap) through run-as instead
  of asking the user to type `pkg install`; Termux's adb gets TMPDIR and HOME under run-as; the
  local endpoint may show as `emulator-5554`. Found by a first-time install on an iPlay60 mini Pro.

## [0.3.0] - 2026-11-22

### Added

- Termux-side setup for non-debuggable builds, authorization and timeout diagnostics,
  manufacturer battery hints, SSH diagnostics and keeper failure/recovery notifications.

## [0.2.0] - 2026-11-22

### Added

- `termux-adb`, the host CLI: `install`, `doctor` and `keeper`. The CLI finds the device from
  `--device`, `TERMUX_ADB_DEVICE` or the single attached adb device, and reads the device
  script beside its own resolved path so a symlink install works.
- `install` enables both packages when Android disabled them, adds them to the deviceidle
  allow-list, launches Termux:Boot once, copies the boot script to `~/.termux/boot/` with mode
  700, optionally appends an SSH public key, starts the restore, then runs `doctor`.
- `doctor` reports adb reachability, Termux and Termux:Boot versions, `notLaunched`, the
  enabled state with `lastDisabledCaller`, the battery allow-list, Samsung's `mMARsTargetPackages`
  list, the installed script's sha256, the watch and sshd processes, `adb_wifi_enabled`, the TCP
  port and the last three log lines. Exit 1 when a check fails.
- `keeper` recovers one pass: it re-enables disabled Termux packages and starts the boot script
  when the watch is gone or the SSH port is closed. `keeper --install` writes a launchd agent
  or a systemd user service and timer; `--uninstall` removes it.
- `boot-restore-adb.sh --version`, sharing the CLI's version constant.
- `install --battery-saver` for phones: writes `~/.termux/boot-restore-adb.env` with
  `ADB_RESTORE_WAKE_LOCK=0` and `ADB_RESTORE_WATCH_INTERVAL=300`; `install` stops watches from older
  copies before starting the new one.
- `keeper --install` writes one scheduler entry per `--device` (with `ADB` and `--ssh-port`
  baked in); healthy passes log nothing.
- A single-instance guard: `~/.termux/boot-restore-adb.watch.pid` stops a second `--watch`
  process, and a boot run no longer starts a watch that already exists.
- `tests/run.sh` with a fake `adb` and `.github/workflows/tests.yml`, running shellcheck,
  `bash -n` and the suite on Ubuntu and macOS.

### Changed

- The tool moved to `docs/products/skills/atlas-cowork/termux-boot-adb-tcp/`; this release is
  the source directory for the public repository of the same name.
- README rewritten around the Samsung finding, the tested device and the comparison with
  Termux:Boot alone and wireless-adb-keeper. It ships without a logo: there is no mark for
  this tool yet.

## [0.1.0] - 2026-11-20

### Added

- Initial public source, bilingual documentation and MIT license.
- Read the port, log path and optional VPN settings from the environment. Keep the boot-time
  loopback discovery confined to the existing port range.
