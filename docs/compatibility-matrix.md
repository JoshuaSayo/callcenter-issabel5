# Issabel 5 Compatibility Matrix

## Evidence levels

- **Documented:** authoritative public release information or repository metadata.
- **Observed externally:** screenshot or unauthenticated network response from the supplied environment.
- **Verified on clone:** authenticated command executed on VM 127 with decisive output retained in `docs/test-evidence.md`.

| Component | Documented | Observed externally | Verified on clone | Current claim |
| --- | --- | --- | --- | --- |
| Issabel media | `issabel5-USB-DVD-x86_64-20240430.iso` in official Issabel 5 SourceForge listing | User identifies this as the deployed media | Unverified | Exact media target known; installed build unknown |
| Issabel module | Repository `RELEASE='5.0.0-1'`; README describes Call Center 5.0.0-1 | User reports Call Center already installed on source test server | Unverified | Upgrade/repeat target only |
| Operating system | Issabel 5 release documentation names Rocky Linux 8.8 | Console screenshot shows Rocky Linux 8.8 | Unverified | Observed, not authenticated |
| Kernel | No exact media claim retained | Console screenshot shows `4.18.0-477.27.1.el8_8.x86_64` | Unverified | Observed, not authenticated |
| PHP | README claims 5.4 through 8.0 compatibility | HTTPS header reports PHP 7.4.33 | Unverified | Web runtime observed as 7.4.33 |
| Apache | Rocky/Issabel web stack expected | HTTPS header reports Apache 2.4.37 | Unverified | Observed, not authenticated |
| OpenSSL | Rocky/Issabel web stack expected | HTTPS header reports OpenSSL 1.1.1k | Unverified | Observed, not authenticated |
| Asterisk | README states Asterisk 18 testing | Issabel CLI screenshot reports Asterisk 18.19.0 | Unverified | Target is 18.19.0; clone check pending |
| MariaDB/MySQL | `issabeldialer.service` requires `mariadb.service`; installer uses MySQL APIs | No version evidence | Unverified | Version and schema state unknown |
| systemd | Service unit is shipped in `setup/dialer_process/issabeldialer.service` | No version evidence | Unverified | Service-manager version unknown |
| FreePBX-derived components | Runtime reads Issabel/Asterisk configuration and `asterisk` database | No component-version evidence | Unverified | Exact component versions unknown |
| Baseline collector | Repository contract defined in `tools/collect-issabel-baseline.sh` | Command-stub RED/GREEN tests pass under Git Bash 5.3 | Unverified | Ready for authenticated clone execution; no compatibility claim yet |

No row may be promoted to **Verified on clone** without an authenticated command recorded in `docs/test-evidence.md`.
