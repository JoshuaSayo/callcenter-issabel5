# Issabel 5 Call Center Architecture Baseline

## Scope

This is a source-backed Phase 1 map of the existing system. It is not a redesign and does not claim that runtime-state hypotheses have been validated.

## End-to-end flow

```text
Issabel campaign/contact UI
        |
        v
call_center database ----> dialerd supervisor
        |                       |
        |                       +--> CampaignProcess
        |                       +--> AMIEventProcess
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

## Process ownership

- `setup/dialer_process/issabeldialer.service:8-23` defines a forking service running as `asterisk`, with `/opt/issabel/dialer/dialerd` as `ExecStart`, a PID file under the dialer directory, and restart-on-failure.
- `setup/dialer_process/dialer/dialerd:298-302,415-434` daemonizes and forks worker processes.
- Worker responsibilities are split across `CampaignProcess`, `AMIEventProcess`, `ECCPWorkerProcess`, and `SQLWorkerProcess`; exact spawn registration will be cited during Task 7.

## Persistent state

- `setup/call_center.sql:26-247` defines agents, audits, calls, campaigns, contacts, and the transient-looking `current_calls`/`current_call_entry` tables.
- `SQLWorkerProcess.class.php:763-878` inserts, updates, and deletes current-call rows for outgoing and incoming calls.
- `CampaignProcess.class.php:146-147` deletes both current-call tables during its initialization path.
- `CampaignProcess.class.php:227`, `ECCPWorkerProcess.class.php:125`, and `SQLWorkerProcess.class.php:165` connect to the `call_center` database.

## Asterisk, AMI, and AGI boundaries

- `CampaignProcess.class.php:377` opens the campaign-side AMI connection used by dialing decisions and origination paths.
- `AMIEventProcess.class.php:260` owns the event-side AMI connection.
- `AMIEventProcess.class.php:305-324` calls `CoreStatus` to observe the Asterisk startup epoch and logs lack of support.
- `ECCPWorkerProcess.class.php:225` opens a separate AMI connection for ECCP-driven work.
- AGI behavior is present under `setup/dialer_process/dialer/phpagi.php`; its exact call-flow ownership remains unverified.

## Authoritative state

- **Hypothesis:** Asterisk events are authoritative for channel/bridge lifecycle, while the database is authoritative for durable campaign, contact, disposition, retry, and callback records.
- **Hypothesis:** `current_calls` and `current_call_entry` are caches reconstructed or cleared after worker restart, not durable call history.
- **Hypothesis:** in-memory worker objects temporarily own transitions between originate requests, AMI events, and SQL-worker acknowledgements.

These hypotheses require later failure-injection tests before dialer or recovery claims.

## Restart reconciliation

- `CampaignProcess.class.php:146-150` shows startup cleanup of current-call tables, which can discard transient DB state.
- `AMIEventProcess.class.php:305-324` observes Asterisk startup data through `CoreStatus`; later code must be traced to prove which in-memory and database structures are reconciled.
- systemd restarts the daemon on failure, but the service unit alone does not prove duplicate-worker prevention.

## Logs

- `issabeldialer.service:27-29` discards standard output, sends standard error to the journal, and uses syslog identifier `issabeldialer`.
- `dialerd:167-172` constructs `AppLogger` and falls back to syslog when application logs cannot open.
- Installer-created module logs are expected under `/var/log/callcenter-module`; exact runtime writers will be mapped in Task 7.

## Installation and removal boundaries

- The shell installer copies web modules, dialer code, systemd/logrotate files, module-installer metadata, dashboard changes, menu data, database setup, and Asterisk configuration.
- The remover targets 31 web-module directories, dialer/service/logrotate/tool metadata, dashboard/menu changes, marked dialplan contexts, and optionally the entire `call_center` database.
- Neither lifecycle script currently behaves as an atomic transaction. Snapshot restoration is the external rollback boundary for Phase 1 staging.
