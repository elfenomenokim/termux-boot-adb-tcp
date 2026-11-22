# Security

## Supported versions

Security fixes go to the latest release. Check the changelog before
reporting an issue from an older revision.

## Report a vulnerability

Use **Report a vulnerability** in the repository's GitHub **Security** tab.
Share the affected version, operating system and a minimal reproduction
through the private form. Remove real account names and credentials from
the reproduction. Share the potential impact and any workaround you tested.

## Scope

The tool keeps an already-authorized ADB connection alive and writes files as the
Termux app through `run-as`. An open ADB port is the purpose of the tool, not a
vulnerability. In scope: a check or fix hint that reports a healthy device when
the port or the watch is gone, a command that leaks a temporary file or leaves a
second process behind, a device-supplied value (model, version, log line) that
reaches a shell command unsafely, and any command that changes the device without
being invoked as `install` or `keeper`.

Use a normal issue for behavior problems that have no security impact.
