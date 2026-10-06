# VPN connects but shares do not open

**Lab simulation — 20261006.** No real staff or physical printer affected.

**Ticket (simulated user):** “WireGuard says active and I have a handshake, but Public won't open after my laptop rebuild.”

**Clarifying questions:** When did it last work? Was the device rebuilt? Does Latest handshake update? Does the intranet IP work? Which share/error?

**Diagnosis:** Used a real WireGuard client in an isolated internal Docker network. Removing the office subnet from AllowedIPs reproduces the routing fault despite a current handshake; this rules out SMB credentials before changing access.

Captured commands/results (credentials redacted):

```text
> VPN client: ping 10.8.0.1
PING 10.8.0.1 (10.8.0.1): 56 data bytes
64 bytes from 10.8.0.1: seq=0 ttl=64 time=2.766 ms

--- 10.8.0.1 ping statistics ---
1 packets transmitted, 1 packets received, 0% packet loss
round-trip min/avg/max = 2.766/2.766/2.766 ms
> wg show wg0 latest-handshakes (keys omitted)
Latest handshake epoch: 1791262528
Stale profile AllowedIPs = 10.8.0.0/24 (office subnet omitted)
> ip route get 172.20.0.3 (stale profile)
RTNETLINK answers: Network unreachable
> smbclient Public via stale VPN profile
do_connect: Connection to 172.20.0.3 failed (Error NT_STATUS_NETWORK_UNREACHABLE)
PASS reproduced: handshake exists, Public inaccessible
Corrected AllowedIPs = 10.8.0.0/24, 172.20.0.0/16
> ip route get 172.20.0.3 (corrected profile)
172.20.0.3 dev wg0 src 10.8.0.2 uid 0 
    cache
> smbclient Public through WireGuard after corrected import
.                                   D        0  Tue Oct  6 04:55:09 2026
  ..                                  D        0  Tue Oct  6 04:54:05 2026
  .deleted                           DH        0  Tue Oct  6 04:55:09 2026

		1055762868 blocks of size 1024. 992649916 blocks available
PASS VPN routing restored; authenticated share listing succeeds
PASS temporary VPN peer revoked and isolated client/network removed
```

**Root cause:** Stale split-tunnel profile omitted the office Docker subnet, so traffic to fileserver had no route through wg0.

**Fix:** Import a current per-device profile in the WireGuard app. In the exercise, correct AllowedIPs and restart the tunnel. Revoke the old peer and issue a new one if a rebuilt/lost device may retain the old key.

**Verification:** The same authenticated Public listing fails before correction and succeeds afterwards; the route selects wg0. Exercise peer is deleted.

**Reply to the user:** “Your VPN connected, but the saved profile was missing the office route. Import the current profile in the WireGuard app, reconnect, and open Public. Keep the profile private.”

**Prevent recurrence:** Record device/peer ownership, revoke peers on rebuild, and test handshake plus share access on onboarding. Publish the intranet server IP; Docker DNS names alone are not client DNS.

Full reproduction: [redacted transcript](../evidence/support-cases-20261006-155525.txt); rerun python tests/reproduce_cases.py.
