# New Finance starter cannot open Finance

**Lab simulation — 20261006.** No real staff or physical printer affected.

**Ticket (simulated user):** “I'm starting in Finance today. Public opens, but Finance says Access is denied.”

**Clarifying questions:** Which username and exact path? Does Public work? Has the Finance manager approved access? Have you signed out since the group change?

**Diagnosis:** Created a real temporary Samba user in staff. Public authentication succeeded while Finance was denied. Compared the user's groups with the effective share ACL; did not broaden the share.

Captured commands/results (credentials redacted):

```text
> Create approved lab Finance starter fin4ee32528 (password omitted)
Added user fin4ee32528.
> Starter can authenticate and list Public
.                                   D        0  Tue Oct  6 04:25:04 2026
  ..                                  D        0  Tue Oct  6 04:27:11 2026
  .deleted                           DH        0  Tue Oct  6 04:25:04 2026

		1055762868 blocks of size 1024. 992704696 blocks available
> Starter Finance access before group assignment
tree connect failed: NT_STATUS_ACCESS_DENIED
> id starter; effective Finance share ACL
uid=1000(fin4ee32528) gid=1101(staff) groups=1101(staff),1101(staff)
[Finance]
	comment = Finance team only
	delete veto files = Yes
	path = /shares/finance
	read only = No
	valid users = @finance
	veto files = /.apdisk/.DS_Store/.TemporaryItems/.Trashes/desktop.ini/ehthumbs.db/Network Trash Folder/Temporary Items/Thumbs.db/


[Scans]
> Manager-approved fix: add starter to finance; refresh identity cache
uid=1000(fin4ee32528) gid=1101(staff) groups=1101(staff),1100(finance),1101(staff)
> Starter Finance write/read/delete succeeds after group membership
putting file /tmp/fin4ee32528.txt as \fin4ee32528.txt (20.5 kb/s) (average 20.5 kb/s)
getting file \fin4ee32528.txt of size 21 as /tmp/fin4ee32528-download.txt (20.5 KiloBytes/sec) (average 20.5 KiloBytes/sec)
PASS Finance starter fault reproduced and repaired
> Remove temporary starter account
Deleted user fin4ee32528.
```

**Root cause:** The starter belonged to staff but was missing finance. Finance permits @finance. The standalone server is separate from the AD lab: GG-Finance membership alone does not grant this share.

**Fix:** After simulated manager approval, add the Samba user to finance, clear the identity cache, and open a new SMB session. For a domain-joined server, assign the approved AD file-access group instead.

**Verification:** The same user writes, reads back and deletes a Finance test file; contents match. Temporary account is removed.

**Reply to the user:** “Your Finance access is now assigned following manager approval. Reconnect the mapped drive using your own username and try again.”

**Prevent recurrence:** Include manager-approved file groups in the starter checklist and test with the new user's credentials. Maintain separate AD and Samba account records until domain integration.

Full reproduction: [redacted transcript](../evidence/support-cases-20261006-152953.txt); rerun python tests/reproduce_cases.py.
