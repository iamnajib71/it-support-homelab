# Test results: 6 October 2026

Run on Windows 11 with Docker Desktop and Windows PowerShell 5.1, from a clean start of this repository's own Compose project
(`it-support-homelab`, office LAN 172.20.0.0/16).

| Check | Result | Transcript |
|---|---|---|
| Homelab: all six containers running; share listing; Alice writes and reads back on Finance; Bob denied on Finance; both use Public; both print queues and default; PDF printed into Scans and IPP job completed (state 9); CUPS public views and admin login required; VPN peer create, list and delete; Uptime Kuma responds and all 6 status-page monitors are UP; office dashboard responds | **0 failed checks** | [homelab-check](evidence/homelab-check-20261006-211239-566.txt) |
| Directory (ITOPS.LAB): controller healthy, SYSVOL ACLs, OUs/users/groups; create user; reset password with change at next logon; lockout after bad passwords and unlock; add to Finance group; disable a leaver and confirm sign-in is denied; list members; clean up | **0 failed checks** | [ad-tasks](evidence/ad-tasks-20261006-155516-705.txt) |
| Support cases: VPN route, Finance access, paused print queues, each reproduced, fixed, verified and cleaned up | **3 of 3** | [support-cases](evidence/support-cases-20261006-155525.txt) |

Secrets live only in the ignored `.env` and are redacted from every transcript; the published files were scanned for them before each commit.

## Problems solved while building it

- WireGuard admin login failed because the password hash was read with Windows line endings (CRLF). Fixed the parsing and verified the login.
- Samba AD could not store Windows ACLs inside a container (`security.NTACL` access denied). Switched to the supported xattr TDB backend; the SYSVOL ACL check now passes.
- Samba's LDAP server lacks the "Who am I" extension, so sign-in after unlock is verified with an authenticated LDAP search instead.
- The VPN routing case depends on the office subnet, so the subnet is pinned in Compose and profiles stay valid when containers are recreated.

## Boundaries

Office-Laser is a placeholder device and no physical printer is tested. The directory is Samba AD, separate from the standalone
file server, so no Windows domain join, RSAT, Group Policy or MFA is claimed. The VPN has no public endpoint. Shadow copies and
retention are documented targets, not scheduled jobs. Uptime Kuma has no external notification channel configured.
