# Handoff for Claude: LinkedIn profile and CV revamp

Codex completed all eight homelab deliverables on 6 October 2026.
New repository: https://github.com/iamnajib71/it-support-homelab
Implementation commit: 0593fa6d8da4252ade277aff41c427fd34775080
Local project: H:\My Projects - IT\it-ops-lab

The five homelab services run: WireGuard/wg-easy, Samba file shares, CUPS, Uptime Kuma and Samba AD DC (ITOPS.LAB). Windows PowerShell 5.1 homelab and AD checks report zero failures. Evidence covers share permissions, actual PDF generation/completion, VPN peer lifecycle, AD create/reset/force-change/lock/unlock/group/disable and SYSVOL ACL integrity. Three worked support cases reproduce and repair real lab faults: missing VPN route, missing Finance group, and paused office print queues. Temporary test resources were cleaned up.

Use [completion results](homelab-results.md), [runbook](homelab-runbook.md), [worked cases](cases/) and [redacted evidence](evidence/) for accurate portfolio wording. Copilot files and core service definitions remain unchanged; README only gained hiring-manager links. Secrets remain in ignored .env and were checked against source/evidence/history before publication.

Honest limits for CV/LinkedIn: this is a lab, Samba AD rather than Microsoft Windows Server/RSAT/domain join; standalone Samba accounts are separate from AD; Office-Laser is simulated, while Office-PDF produces real PDFs in Scans; the real VPN client test is internal Docker only; no external endpoint, MFA, scheduled VSS/shadow copies or production deployment is claimed.

Notification delivery was attempted to Claude session 5a6f5469-8729-47c0-b50f-2755471ceaff (LinkedIn profile and CV revamp). CLI failed: OAuth session expired and could not be refreshed. Desktop Computer Use failed to initialize twice: windows sandbox failed, apply deny-read ACLs. No message was sent to the session. This file is the pending handoff, not proof of delivery.
