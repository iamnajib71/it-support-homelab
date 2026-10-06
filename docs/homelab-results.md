# Homelab completion results — 6 October 2026

All eight deliverables in CODEX_TASK_homelab.md completed. Docker Compose homelab startup succeeds; all five homelab containers run (AD, VPN, Samba and Kuma report healthy). Original copilot files and core service definitions are unchanged. README changes are limited to hiring-manager evidence links.

- Windows PowerShell **5.1.26100.9549**: [homelab check](evidence/homelab-check-20261006-153329-772.txt), **0 failed checks**. Four containers running; share listing, Alice Finance write/readback, Bob denied, both Public write/readback; both queues/default; PDF generated in Scans and IPP completed state 9; CUPS public views and authenticated admin; VPN session/peer creation, listing and deletion; Kuma HTTP 200.
- [AD tasks](evidence/ad-tasks-20261006-153335-176.txt), **0 failed checks**: healthy controller, SYSVOL ACLs, OUs/users/groups, create, reset/force-change, five real bad LDAP binds, lockout, unlock/authenticate, Finance membership, disable/deny leaver, list members and cleanup.
- [Support cases](evidence/support-cases-20261006-152953.txt): all three real faults reproduced, repaired and verified; temporary peer/client/network/starter removed; queues restored. Documents: [VPN](cases/01-vpn-shares.md), [Finance](cases/02-finance-starter.md), [printing](cases/03-office-printing.md).
- CUPS setup, AD seed and credential bootstrap rerun idempotently. PowerShell 5.1 parser validation passed. Actual credentials absent from evidence/source and existing Git history; .env stays ignored. Protected-file hashes verified against the initial baseline.

Implemented CUPS LAN/Docker access controls, cups-pdf, generic simulated Office-Laser, group-based Finance permissions, localhost port bindings, corrected VPN subnet, private bcrypt credentials, persistent Samba AD with container-compatible xattr TDB ACLs, repeatable checks, onboarding/offboarding/restore/print/monitor/backup runbook and a clean-clone credential bootstrap.

Resolved during verification: registry TLS timeouts (retried); empty WireGuard hash caused by CRLF parsing (fixed and verified login); AD security.NTACL access denied (replaced with supported persistent xattr TDB backend, SYSVOL check passes); Samba lacks LDAP Who Am I extension (authenticate via successful LDAP search after unlock). Initial failed transcripts are retained as redacted troubleshooting history.

Boundaries: Office-Laser is deliberately a placeholder; no physical device test. AD is Samba, separate from the standalone share server; no Windows domain join/RSAT or MFA claimed. VPN is tested through a real internal Docker client, with no public endpoint. Nightly shadow copies and retention are documented operating targets, not implemented host schedules. Uptime monitor targets are listed for setup; no external notification channel configured. No unresolved required-check failures.

Repository requested by the user: https://github.com/iamnajib71/it-support-homelab
