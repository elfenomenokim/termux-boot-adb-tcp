# Contributing

## Before you start

Open an issue for a larger change. Name the task the current behavior cannot
handle, the environment where it occurs, and what you want the tool to do.
For a vulnerability, follow [SECURITY.md](SECURITY.md).

Include the relevant command and version when reporting a bug. A small
reproduction with example data makes the problem easier to verify. Redact
device and account details from the report.

## Setup

Follow the install instructions in [README.md](README.md). The checks need no
phone and no adb server; `tests/run.sh` puts a fake `adb` on `PATH` and answers
from `tests/fixtures/`.

```
shellcheck termux-adb boot-restore-adb.sh tests/run.sh tests/fake-adb
bash -n termux-adb && bash -n boot-restore-adb.sh
bash tests/run.sh
```

Never point a check or a test at a real device. `install`, `keeper` and the boot
script change the device; `doctor` is the only read-only command, so it is the
only one to run against hardware.

Check the entry point you are changing and include its actual output in your
pull request when that output explains the change.

## Patch

Keep a patch focused on one behavior. Explain behavior changes and preserve
existing option names unless the issue calls for a breaking change. Add a
fixture and a check in `tests/run.sh` when the existing cases would miss the
failure. A device check prints one line and, on failure, one `fix:` line; keep
that shape.

Update both READMEs and add a changelog entry when output or usage changes.
Bump `VERSION` in `termux-adb` and `boot-restore-adb.sh` together. State which
operating systems and devices you exercised, and list the ones you did not.

Discussions and contributions follow the [code of conduct](CODE_OF_CONDUCT.md).
