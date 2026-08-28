# Issabel 5 Call Center Phase 1 Design

**Status:** Approved in chat on 2026-08-28; written specification awaiting user review.

## Purpose

Establish a trustworthy engineering and installation baseline for the Issabel 5 Call Center module before changing dialer-critical behavior. This phase produces durable project evidence, reconstructs the existing control and data flow, hardens the current Issabel 5 installer without replacing the module architecture, and validates the result on the user's disposable staging clone.

The wider stabilization program is architectural and spans several independent subsystems. This specification deliberately covers only the first independently testable slice: repository baseline, runtime compatibility evidence, architecture documentation, and safe installation or repeat installation. Dialer, agent, campaign, reporting, security, and recovery changes require later focused specifications after this foundation passes.

## Target and Evidence Boundary

The compatibility target is the user's Issabel 5 installation derived from `issabel5-USB-DVD-x86_64-20240430.iso`.

| Item | Current evidence | Phase 1 requirement |
| --- | --- | --- |
| Issabel media | Exact ISO filename supplied by the user and confirmed in the official SourceForge Issabel 5 listing | Record the installed Issabel package/build from staging |
| Operating system | Rocky Linux 8.8 shown in the supplied console evidence | Capture `/etc/os-release`, Rocky release package, and kernel from staging |
| Web runtime | Unauthenticated staging response reports Apache 2.4.37, OpenSSL 1.1.1k, and PHP 7.4.33 | Confirm CLI PHP version and required extensions on staging |
| Asterisk | User-supplied Issabel CLI evidence reports Asterisk 18.19.0 | Re-run `core show version` on clone `10.39.188.63` before compatibility is marked verified there |
| Database | Not yet measured on the clone | Record MariaDB server/client versions, schema presence, and migration state without retaining credentials |
| Existing module | The user reports that Call Center is already installed on the source test server that was cloned | Treat VM 127 as an upgrade/repeat-install target; inspect the installed package and schema before mutation |
| Staging safety | Proxmox VM 127, `ISSABEL5CALLCENTERTEST`, with snapshot `baseline-before-callcenter-work`; user reports trunks plus inbound and outbound routes removed, with no GSM connection or VPN | Use synthetic records only and do not originate external calls |

Public documentation, repository metadata, screenshots, unauthenticated probes, and authenticated staging commands must remain separately labeled. A version is “staging verified” only when its command and output are retained in `docs/test-evidence.md`; screenshots containing private infrastructure details remain outside the public repository.

## Chosen Approach

Preserve and characterize the existing installer, then make the smallest complete hardening changes.

This is preferred over a replacement installer because the current script already encodes Issabel-specific paths, dashboard integration, module layout, systemd setup, menu merging, database installation, and Asterisk reload behavior. A rewrite would create a larger regression surface before the existing behavior is understood. Static review alone is also insufficient because installation and migration claims require execution on a disposable Issabel system.

The alternatives rejected for this phase are:

1. **Rewrite installation as a new package manager or orchestration layer.** This could improve structure but would introduce new dependencies and obscure compatibility with the current RPM and module installer paths.
2. **Patch only the visibly malformed commands.** This is smaller but leaves false-success behavior, unsafe fixed-directory cleanup, unchecked database installation, and partial-install ambiguity.

## Existing Runtime Architecture to Document

Phase 1 does not redesign the runtime. It records the current boundaries and authoritative state so later fixes can be scoped correctly.

```text
Issabel campaign/contact UI
        |
        v
call_center database ----> dialerd supervisor
        |                       |
        |                       +--> CampaignProcess
        |                       +--> ECCPWorkerProcess / ECCPConn
        |                       +--> SQLWorkerProcess
        |                                  |
        v                                  v
campaign/contact state <---- AMI events / originate commands ----> Asterisk
        |                                                        queues/channels
        v                                                               |
agent console / ECCP <---------- agent and call state ------------------+
        |
        v
disposition, retry, callback, and reporting records
```

The architecture document must identify:

- process ownership and startup under `issabeldialer.service`;
- configuration read from Issabel/Asterisk files and the `call_center` and `asterisk` databases;
- where campaign, contact, agent, call, retry, callback, and disposition state is persisted;
- AMI and AGI message boundaries and how runtime state is reconciled after reconnect or restart;
- which observed state is authoritative when memory, database rows, and Asterisk events disagree;
- how browser modules and ECCP requests reach the dialer and database;
- log locations and failure visibility.

Assertions will cite source paths and runtime evidence. Unresolved interpretations remain hypotheses in the issue register rather than being presented as facts.

## Phase 1 Components

### 1. Durable project records

Create and maintain:

- `docs/project-status.md` for phase, completed work, active work, blockers, next action, and commit hashes;
- `docs/issue-register.md` for stable issue identifiers, severity, evidence, cause, intended behavior, proposed fix, implementation, and validation;
- `docs/test-evidence.md` for environment, commands, expected and actual results, limitations, and retained-log paths;
- `docs/compatibility-matrix.md` for documented, statically inferred, and staging-verified versions;
- `docs/architecture.md` for the process, data, control, and recovery model.

These files contain no passwords, session identifiers, SIP credentials, private keys, contact data, or public-repository screenshots exposing private infrastructure.

### 2. Staging baseline collection

Before mutation, collect read-only versions and state for Issabel, Rocky, PHP and required modules, MariaDB, Asterisk, Apache, systemd, the call-center package/module, `issabeldialer`, database schema identifiers, and relevant configuration-file checksums. Commands and decisive output are recorded; secrets and full configuration contents are not.

The collector must fail closed when a required command cannot be read and must distinguish “not installed” from “command failed.” It may be a documented command set or a repository script, depending on which is easier to audit without adding runtime dependencies.

### 3. Installer contract and characterization tests

Preserve these public entry points:

- `bash build/5.0/install-issabel-callcenter.sh --local` installs from the checked-out repository;
- `bash build/5.0/install-issabel-callcenter.sh` installs from a temporary GitHub checkout;
- Asterisk 18 is the verified target for this program; other branches already present in the script are not promoted to verified support without matching evidence.

Characterization tests must demonstrate the current failure before each behavioral change. Tests use disposable filesystem roots or command stubs and are explicitly labeled as local simulated tests. Real path, database, service, and Asterisk behavior is proved separately on the snapshotted staging VM.

Required failure scenarios include missing Asterisk, unsupported or unparsable version output, clone failure, missing source layout, module-copy failure, menu-merge failure, PHP installer failure, systemd failure, Asterisk reload failure, and cleanup after an interrupted install. A failed required stage must return nonzero and must not print the completion banner.

### 4. Installer hardening

Refactor `build/5.0/install-issabel-callcenter.sh` into small shell functions while preserving its two invocation modes and installed paths. The production path gains:

- strict error propagation suitable for Bash, including safe handling of an absent first argument;
- an explicit root and prerequisite preflight;
- validated repository layout before filesystem mutation;
- unique temporary checkout and module-staging directories created with `mktemp`;
- cleanup traps limited to the exact temporary directories created by the current run;
- quoted paths and removal of broad fixed-directory cleanup for temporary work;
- checked copy, ownership, permission, menu merge, PHP installer, systemd, and service operations;
- `asterisk -rx "core reload"` with correct argument separation and a required success result;
- completion output only after database installation, service activation, Asterisk reload, and post-install health checks succeed;
- error output that names the failed stage and leaves the VM snapshot as the documented recovery boundary.

Optional integration remains optional only where absence is already non-fatal by design, such as a missing dashboard applet. A present dashboard file that cannot be patched or copied is a failure. Commands must not suppress required failures with `|| true`.

`setup/installer.php` is changed only when characterization proves that it reports a failed required database or configuration operation as success. Such changes must return a nonzero process status without redesigning the schema in this phase.

### 5. Safe staging validation

Staging changes require key-based SSH access through a temporary authorized account or an equivalent user-operated console. Credentials are never placed in the repository or evidence files.

Validation proceeds in this order:

1. Confirm the snapshot and capture the read-only baseline.
2. Capture schema and relevant-file backups without call or contact data.
3. Run local/simulated installer tests outside the PBX.
4. Run the local installer as an upgrade/repeat installation over the existing staging module and retain the exact exit status and logs.
5. Verify installed files, ownership, permissions, menu integration, database objects, `issabeldialer`, Apache/PHP loading, and Asterisk connectivity.
6. Run the same installer a second time to prove repeat-install safety.
7. Exercise only synthetic UI and service-health checks; do not create an external trunk or originate an external call.
8. Restore the Proxmox snapshot if validation produces an unrecoverable partial state, then record the failure rather than converting it into success.

## Error and Recovery Model

The installer is a staged transaction with explicit checkpoints, not a claim of filesystem-wide atomicity. Temporary resources are always removed by exact-path traps. Required-stage failure stops later stages and returns nonzero. Existing installed files and schema are not automatically deleted on failure because destructive rollback could remove a working prior installation; recovery uses retained backups, repeatable installation where safe, or the named Proxmox snapshot.

Logs identify the stage and failing command without echoing database passwords or session values. A retry is allowed only after the recorded cause is corrected. Three failed materially different attempts at the same staging blocker trigger a pause and documented escalation.

## Testing Strategy

Testing is layered and evidence labels remain explicit:

1. **Static:** Bash syntax, PHP syntax for modified files, XML parsing where applicable, and ShellCheck when available.
2. **Characterization/unit simulation:** deterministic success and failure-path tests for installer control flow, temporary-directory safety, exit codes, and completion messaging.
3. **Repository regression:** existing project checks plus targeted searches proving malformed invocation and unsafe temporary cleanup patterns are absent from the changed installer.
4. **Disposable Issabel integration:** upgrade/repeat installation on VM 127, database and file verification, service health, Apache/PHP module loading, and Asterisk CLI connectivity.
5. **Rollback rehearsal:** verify the snapshot is still available and record restore steps; restore it only when required by a failed integration run or when the user requests rehearsal.

No simulated test is evidence of real Issabel, MariaDB, systemd, or Asterisk integration. No health check is evidence that outbound or inbound calling works.

## Phase 1 Acceptance Criteria

Phase 1 is complete when all of the following have retained evidence:

- the five durable project documents exist and agree on status and environment;
- the runtime architecture and authoritative-state questions are documented with citations or explicitly marked hypotheses;
- the staging compatibility matrix contains exact Issabel, Rocky, kernel, PHP, MariaDB, Asterisk, Apache, and systemd versions;
- each installer change has a pre-change failing characterization or a recorded safety rationale;
- required installer failures return nonzero and never print completion;
- temporary cleanup is unique to the current run and does not use the fixed `/usr/src/callcenter` or broad `/tmp/new_module` removal pattern;
- the corrected Asterisk reload is checked rather than suppressed;
- the PHP database installer cannot fail a required operation while the shell installer reports success;
- syntax, static, simulated, and relevant regression checks pass;
- an upgrade/repeat installation and an immediate second repeat installation pass on the snapshotted clone;
- database objects, installed files, menu integration, web module loading, `issabeldialer`, and Asterisk CLI connectivity pass post-install checks;
- limitations and every unverified runtime claim are recorded;
- the verified changes are committed as small logical commits on `develop` and are ready for review on the user's fork.

## Explicit Non-Goals

This phase does not claim a clean ISO installation because VM 127 already contains the module. A clean-install claim requires a separate fresh-ISO VM in a later validation cycle. This phase also does not redesign predictive algorithms, originate real calls, add trunks, contact leads, change campaign or agent behavior, repair reports or UI workflows, resolve the ECCP authentication protocol, publish a release, merge upstream, or claim production readiness. Those areas remain in the issue register and receive separate design and implementation cycles after the installation foundation is verified.
