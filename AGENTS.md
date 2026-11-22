# termux-boot-adb-tcp

## Set up for a user

Goal: an Android device the user names stays reachable from their computer over adb
(`HOST:5555`) and SSH (`8022`) after reboots and system updates. Run every step yourself;
only the steps marked **person** need the user.

1. **Computer.** `adb version` prints a version (else install Android platform-tools;
   macOS `brew install android-platform-tools`). `curl` and `gpg` are present (gpg checks
   F-Droid downloads). Put `termux-adb` on PATH with `boot-restore-adb.sh` beside it.
2. **Developer options — person.** Say: "Open Settings > About phone > Software information
   and tap **Build number** seven times, then open Developer options and turn on
   **Wireless debugging**." The device must be on Wi-Fi (a phone hotspot counts).
3. **Pair — person.** Say: "In Wireless debugging, tap **Pair device with pairing code** and
   tell me the six-digit code and the IP address and port shown." Run
   `adb pair IP:PAIR_PORT CODE`, then `adb mdns services` (or the port on the Wireless
   debugging screen) and `adb connect IP:PORT`. `adb devices` shows `device`.
   If the device is only reachable through another device you already control (for example
   both on a phone hotspot), forward its port over SSH:
   `ssh -L 47171:DEVICE_LAN_IP:PORT -p 8022 OTHER_DEVICE` and `adb connect 127.0.0.1:47171`.
4. **Remote path (optional) — person for the login.** For access outside the home network,
   install Tailscale (Play Store) and say: "Open Tailscale and sign in." Then use
   `--vpn-app com.tailscale.ipn` below and the device's Tailscale IP from then on.
5. **Install.** `termux-adb --device IP:PORT install --fetch-apps [--vpn-app com.tailscale.ipn]
   [--battery-saver for a phone] [--ssh-key ~/.ssh/id_ed25519.pub]`. It downloads Termux and
   Termux:Boot (GitHub builds, sha256-checked; debuggable, so every later step runs through
   run-as) and KeepADB (F-Droid, gpg-checked), installs Termux packages, the boot script,
   battery exemptions, the always-on VPN and the SSH key, then runs `doctor`.
   If Termux is already installed from F-Droid, run-as is refused: install prints a
   `setup.sh` one-liner; **person**: say "Open Termux and paste this line."
6. **Always allow — person, only if asked.** If install waits at "tap Always allow", say:
   "Tick **Always allow from this computer** and tap **Allow** on the screen." You can also
   tap it yourself with `adb shell uiautomator dump` and `adb shell input tap X Y`.
7. **KeepADB setup assistant.** Open it (`adb shell monkey -p de.hohnepeople.keepadb -c
   android.intent.category.LAUNCHER 1`) and drive it with uiautomator dump + input tap:
   Start, Keep-Alive **On**, protection Maximum security, Next on permissions (install already
   granted them), **Trust** the current Wi-Fi (the home network or the user's hotspot), skip
   the webhook, Done. Ask the person only if the screen is in use.
8. **Keeper.** On an always-on computer: `termux-adb --device IP:5555 keeper --install
   --ssh-port 8022 [--notify-cmd CMD --notify-after 3]`. Each device gets its own job.
9. **Prove it.** `termux-adb --device IP:5555 doctor --ssh-port 8022` ends with `0 problem`.
   Optional end-to-end: `adb -s IP:5555 reboot`; SSH and 5555 return within about 3 minutes.

When doctor reports a problem, follow its `fix:` line. Common causes, in order:
- *adb cannot reach the device*: Wireless debugging is off or the device left Wi-Fi; after a
  reboot outside Wi-Fi, 5555 returns only once it joins a trusted Wi-Fi (SSH keeps working).
- *Termux adb is not authorized*: run `adb connect 127.0.0.1:5555` in Termux (with
  `TMPDIR=$PREFIX/tmp` over SSH) and do step 6.
- *packages disabled / watch absent*: `keeper` once re-enables and restarts them.
- *Samsung*: `doctor` also reads the auto-disable list; Battery "Unrestricted" removes the app.

## Scope

A Termux:Boot script (`boot-restore-adb.sh`) plus a host CLI (`termux-adb`) that keep a fixed
ADB TCP port available after an Android reboot. The public unit is every file in `public.json`.
Discovery stays on the device's loopback interface and uses the existing Wireless debugging
pairing. The tool does not pair a new client; turning Wireless debugging back on after an
update is KeepADB's job, which `install` sets up.

## Layout

- `termux-adb` — host CLI: `install`, `doctor`, `keeper`. Reads `boot-restore-adb.sh` beside
  its own resolved path, so a symlink is fine.
- `boot-restore-adb.sh` — device script, runs from `~/.termux/boot/`.
- `tests/run.sh` — end-to-end tests through a fake `adb`; `tests/fake-adb` answers from
  `tests/fixtures/`.
- `.github/workflows/tests.yml` — shellcheck, `bash -n`, `tests/run.sh` on Ubuntu and macOS.

## Local checks

Run from the repository directory.

```bash
shellcheck termux-adb boot-restore-adb.sh tests/run.sh tests/fake-adb
bash -n termux-adb && bash -n boot-restore-adb.sh
bash tests/run.sh
```

The suite needs no phone, adb server or network. macOS runs it under `/bin/bash` 3.2, which is
the oldest shell the scripts support: no arrays, no `${var,,}`, no `mapfile`.

## Rules

- Never point a test or CI run at a real device. `tests/run.sh` puts the stub on `PATH` as
  `adb`; keep it that way and never call the real binary from a fixture.
- `install`, `keeper` and the device script change the device (`pm enable`, `deviceidle
  whitelist`, `am start`, `tcpip`). A manual check against hardware is `doctor` only, because
  `doctor` is read-only.
- Never commit a serial, IP address, hostname or key from a real device. Examples use
  `192.168.0.10:5555` and a fake key.
- `VERSION` appears in `termux-adb` and `boot-restore-adb.sh`. Change both together and record
  it in `CHANGELOG.md`.
- Keep `README.md` and `README.ko.md` in step: same commands, same output blocks.
- Every device check prints one line and, when it fails, one `fix:` line. Keep the `✗` count as
  the exit status contract.

## Code Review Rules

A real defect is: a wrong check result, a fix hint that names the wrong command, a command that
runs without the package or file it needs, a leaked process or temporary file, a parse that
breaks on another Android or Samsung output shape, or a README/AGENTS claim the code does not
implement. Style, naming, comment wording and missing tests are not review findings.

Use [SECURITY.md](SECURITY.md) for suspected vulnerabilities and
[CONTRIBUTING.md](CONTRIBUTING.md) for patches.
