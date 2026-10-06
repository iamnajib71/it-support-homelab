# Print jobs stuck for the whole office

**Lab simulation — 20261006.** No real staff or physical printer affected.

**Ticket (simulated user):** “Nobody can print. My job just sits there, and another colleague has the same problem.”

**Clarifying questions:** Which queues and how many people? When did it start? Any maintenance? Does the printers page load? Is there a device error?

**Diagnosis:** Treat as simulated P2 because multiple users are affected. Paused both queues, then submitted a page to the stopped PDF queue; it remained pending. Web availability alone does not prove printing works.

Captured commands/results (credentials redacted):

```text
> Fault injection: stop both office queues
> lpstat -p -d (office-wide failure)
printer Office-Laser disabled since Tue Oct  6 04:55:35 2026 -
	LAB SIMULATION: paused by maintenance
printer Office-PDF disabled since Tue Oct  6 04:55:35 2026 -
	LAB SIMULATION: paused by maintenance
system default destination: Office-PDF
> Submit test page while Office-PDF is stopped
request id is Office-PDF-2 (0 file(s))
> lpstat: job remains queued
Office-PDF-2            root              1024   Tue Oct  6 04:55:36 2026
PASS reproduced: both queues disabled; submitted PDF remains pending
> Fix: enable both queues
> Fix: accept new jobs
> ipptool: original stuck job
"/lab-job-completed.test":
    Job completed, not cancelled or aborted                              [PASS]
> lpstat -p -d after recovery
printer Office-Laser is idle.  enabled since Tue Oct  6 04:55:36 2026
printer Office-PDF is idle.  enabled since Tue Oct  6 04:55:37 2026
system default destination: Office-PDF
PASS original queued job completed (IPP job-state=9); both queues enabled
```

**Root cause:** Maintenance left both server queues disabled. Office-Laser is a simulated IPP device; scheduler recovery is verified with Office-PDF rather than claiming physical output.

**Fix:** Review the disable reason, enable both queues and accept jobs. In a real incident, cancel only the blocking job after checking its owner; do not purge the office without approval.

**Verification:** The original pending job reaches IPP completed state 9 and both queues are enabled. Finally restores state even on failure.

**Reply to the user:** “The office queues were still paused after maintenance. They are enabled again, and the waiting test page completed. Please retry your job once; send the queue and job number if it remains stuck.”

**Prevent recurrence:** Add queue state and end-to-end print tests to the maintenance checklist. Monitor availability plus scheduler/job failures; record who paused a queue and when to re-enable it.

Full reproduction: [redacted transcript](../evidence/support-cases-20261006-155525.txt); rerun python tests/reproduce_cases.py.
