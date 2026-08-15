# Ubuntu-desktops-custom — V1 Execution Candidate

Version: `1.0.0-rc1`

## Status

This branch is a reviewed execution candidate. The real-apply code path is feature-enabled, but the runtime approval remains closed by default:

- `REAL_APPLY_FEATURE_ENABLED=true`
- static `REAL_MACHINE_APPROVED=false`
- `DRY_RUN=true` by default

No real mutation occurs merely by cloning the repository or running the diagnostic/menu.

## Mandatory sequence before real execution

1. Checkout the exact candidate commit to execute.
2. Run `./diagnostic.sh` and require `GO PRE-TEST` with no KO.
3. Run `./install.sh --dry-run` and require `FULL DRY-RUN PASS`.
4. Prepare an external Restic repository and runtime password file.
5. Run `RESTIC_REPOSITORY=... RESTIC_PASSWORD_FILE=... ./verify-preapply-backup.sh`.
6. Require a fresh `BACKUP_VERIFIED` proof tied to the same Git commit (maximum age: 24h).
7. Start `./install.sh --apply` from an interactive TTY only.
8. Pass the read-only HOST hardware/OS preflight.
9. Type the exact global confirmation phrase requested by the installer.
10. Confirm each domain independently: `HOST`, `KVM`, `VM_DEVOPS`, `BACKUP`.
11. Stop immediately on any PRECHECK/APPLY/POSTCHECK/ROLLBACK error; do not bypass a failed gate.

## Runtime gates

Real mutation is possible only inside the `install.sh --apply` process after `lib/apply_gate.sh` verifies all required proofs and confirmations. `REAL_MACHINE_APPROVED=true` is never stored as static configuration.

## Safety properties reviewed for RC1

- all declared module mutations pass through the secure runner;
- existing `devops-nat` is validated before KVM network mutation;
- KVM firewall ownership is limited to the project nftables table;
- no global nftables/iptables flush is permitted;
- VM provisioning rolls back a newly-created disk, DHCP reservation and partial domain on failure;
- DevOps tooling is installed through the VM transport, not directly on the HOST;
- full dry-run proof and backup proof are bound to the current Git commit;
- backup proof expires after 24 hours;
- local backup target may not be on the same filesystem as `/`;
- Restic repository integrity and data verification are mandatory before proof generation;
- each major execution domain requires a separate interactive confirmation.

## Not implied by RC status

RC status is not proof that every physical workstation-specific condition will pass. The actual machine must still satisfy the real preflight (Ubuntu release, filesystems, hardware, KVM prerequisites, network overlap checks, storage layout and runtime inputs). Any mismatch must fail closed.
