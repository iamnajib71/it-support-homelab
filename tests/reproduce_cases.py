"""Reproduce three reversible service-desk faults. No third-party host packages."""
from pathlib import Path
import datetime, http.cookiejar, json, re, secrets, subprocess, sys
import time, urllib.request

ROOT = Path(__file__).resolve().parents[1]
ENV = dict(re.findall(r"^(\w+)=(.*)$", (ROOT / ".env").read_text(), re.M))
ENV = {k: v.strip().strip("'\"").replace("$$", "$") for k, v in ENV.items()}
SECRETS = [v for k, v in ENV.items() if re.search("PASSWORD|HASH|TOKEN|KEY", k) and v]
STAMP = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=11))).strftime("%Y%m%d-%H%M%S")
TRANSCRIPT = ROOT / "docs/evidence" / f"support-cases-{STAMP}.txt"
LINES = []
FENCE = chr(96) * 3
def redact(text):
    for secret in SECRETS:
        text = text.replace(secret, "[REDACTED]")
    return re.sub(r"(?im)^((?:PrivateKey|PresharedKey)\s*=\s*).+$", r"\1[REDACTED]", text)
def log(text):
    text = redact(str(text)); LINES.append(text); print(text, flush=True)
    TRANSCRIPT.write_text("\n".join(LINES) + "\n", encoding="utf-8")
def run(args, label, *, input=None, ok=True):
    result = subprocess.run(["docker"] + args, cwd=ROOT, input=input, capture_output=True, text=True, timeout=120)
    output = redact((result.stdout + result.stderr).strip())
    if label:
        log("> " + label)
        if output: log(output)
    if ok and result.returncode:
        raise RuntimeError(f"{label or 'Docker operation'} exited {result.returncode}: {output}")
    return result.returncode, output
def compose(service, args, label, **kwargs):
    return run(["compose", "exec", "-T", service] + args, label, **kwargs)
def api(path, method="GET", data=None):
    body = json.dumps(data).encode() if data is not None else None
    request = urllib.request.Request("http://127.0.0.1:51821/api/" + path, data=body, method=method,
                                     headers={"Content-Type": "application/json"})
    with OPENER.open(request, timeout=20) as response:
        content = response.read().decode()
        return json.loads(content) if response.headers.get("Content-Type", "").startswith("application/json") else content
OPENER = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
def case_doc(filename, title, ticket, questions, diagnosis, start, cause, fix, verify, reply, prevent):
    excerpt = "\n".join(LINES[start:])
    if len(excerpt) > 6500: excerpt = excerpt[:6500] + "\n[trimmed; see linked transcript]"
    text = f"""# {title}

**Lab simulation — {STAMP[:8]}.** No real staff or physical printer affected.

**Ticket (simulated user):** “{ticket}”

**Clarifying questions:** {questions}

**Diagnosis:** {diagnosis}

Captured commands/results (credentials redacted):

{FENCE}text
{excerpt}
{FENCE}

**Root cause:** {cause}

**Fix:** {fix}

**Verification:** {verify}

**Reply to the user:** “{reply}”

**Prevent recurrence:** {prevent}

Full reproduction: [redacted transcript](../evidence/{TRANSCRIPT.name}); rerun python tests/reproduce_cases.py.
"""
    (ROOT / "docs/cases" / filename).write_text(text, encoding="utf-8")
def vpn_case():
    start = len(LINES); suffix = secrets.token_hex(4)
    network = "itops-vpn-case-" + suffix; client = "itops-vpn-client-" + suffix; name = "case-vpn-" + suffix
    peer = None
    server = run(["compose", "ps", "-q", "wireguard"], None)[1]
    file_id = run(["compose", "ps", "-q", "fileserver"], None)[1]
    file_ip = run(["inspect", "--format", "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}", file_id], None)[1]
    api("session", "POST", {"password": ENV["WG_ADMIN_PASSWORD"]})
    try:
        api("wireguard/client", "POST", {"name": name})
        peer = next(p for p in api("wireguard/client") if p["name"] == name)
        config = api("wireguard/client/" + peer["id"] + "/configuration")
        config = re.sub(r"(?m)^Endpoint\s*=.*$", "Endpoint = wg-case-endpoint:51820", config)
        config = re.sub(r"(?m)^DNS\s*=.*\n?", "", config)
        correct = config; stale = re.sub(r"(?m)^AllowedIPs\s*=.*$", "AllowedIPs = 10.8.0.0/24", config)
        run(["network", "create", "--internal", network], None)
        run(["network", "connect", "--alias", "wg-case-endpoint", network, server], None)
        run(["run", "-d", "--name", client, "--network", network, "--cap-add", "NET_ADMIN",
             "--sysctl", "net.ipv4.conf.all.src_valid_mark=1", "-e", "PASSWD=" + ENV["SMB_ALICE_PASSWORD"],
             "it-support-homelab-vpn-client:14", "-c", "sleep 600"], None)
        def install(text):
            run(["exec", "-i", client, "sh", "-c", "umask 077; cat > /etc/wireguard/wg0.conf"], None, input=text)
            run(["exec", client, "wg-quick", "up", "wg0"], None)
        install(stale)
        run(["exec", client, "ping", "-c", "1", "-W", "3", "10.8.0.1"], "VPN client: ping 10.8.0.1", ok=False)
        time.sleep(1)
        run(["exec", client, "sh", "-c",
             "wg show wg0 latest-handshakes | awk '{ print \"Latest handshake epoch: \" $2; if ($2 > 0) ok=1 } END {exit !ok}'"],
            "wg show wg0 latest-handshakes (keys omitted)")
        log("Stale profile AllowedIPs = 10.8.0.0/24 (office subnet omitted)")
        run(["exec", client, "ip", "route", "get", file_ip], "ip route get " + file_ip + " (stale profile)", ok=False)
        code, output = run(["exec", client, "timeout", "8", "smbclient", "//" + file_ip + "/Public", "-U", "alice", "-m", "SMB3", "-c", "ls"],
                           "smbclient Public via stale VPN profile", ok=False)
        if code == 0: raise RuntimeError("Stale VPN profile unexpectedly accessed shares")
        log("PASS reproduced: handshake exists, Public inaccessible")
        run(["exec", client, "wg-quick", "down", "wg0"], None)
        install(correct)
        log("Corrected AllowedIPs = 10.8.0.0/24, 172.20.0.0/16")
        run(["exec", client, "ip", "route", "get", file_ip], "ip route get " + file_ip + " (corrected profile)")
        run(["exec", client, "timeout", "15", "smbclient", "//" + file_ip + "/Public", "-U", "alice", "-m", "SMB3", "-c", "ls"],
            "smbclient Public through WireGuard after corrected import")
        log("PASS VPN routing restored; authenticated share listing succeeds")
    finally:
        run(["rm", "-f", client], None, ok=False)
        run(["network", "disconnect", network, server], None, ok=False)
        run(["network", "rm", network], None, ok=False)
        if peer:
            api("wireguard/client/" + peer["id"], "DELETE")
            assert not any(p["id"] == peer["id"] for p in api("wireguard/client"))
            log("PASS temporary VPN peer revoked and isolated client/network removed")
    case_doc("01-vpn-shares.md", "VPN connects but shares do not open",
             "WireGuard says active and I have a handshake, but Public won't open after my laptop rebuild.",
             "When did it last work? Was the device rebuilt? Does Latest handshake update? Does the intranet IP work? Which share/error?",
             "Used a real WireGuard client in an isolated internal Docker network. Removing the office subnet from AllowedIPs reproduces the routing fault despite a current handshake; this rules out SMB credentials before changing access.",
             start,
             "Stale split-tunnel profile omitted the office Docker subnet, so traffic to fileserver had no route through wg0.",
             "Import a current per-device profile in the WireGuard app. In the exercise, correct AllowedIPs and restart the tunnel. Revoke the old peer and issue a new one if a rebuilt/lost device may retain the old key.",
             "The same authenticated Public listing fails before correction and succeeds afterwards; the route selects wg0. Exercise peer is deleted.",
             "Your VPN connected, but the saved profile was missing the office route. Import the current profile in the WireGuard app, reconnect, and open Public. Keep the profile private.",
             "Record device/peer ownership, revoke peers on rebuild, and test handshake plus share access on onboarding. Publish the intranet server IP; Docker DNS names alone are not client DNS.")
def finance_case():
    start = len(LINES); user = "fin" + secrets.token_hex(4); password = "Aa1!" + secrets.token_hex(16)
    SECRETS.append(password)
    def exec_secret(script, label):
        return run(["compose", "exec", "-T", "-e", "CASE_STARTER_PASSWORD=" + password, "fileserver", "sh", "-c", script], label)
    try:
        exec_secret('adduser -D -H -G staff "' + user + '"; printf "%s\\n%s\\n" "$CASE_STARTER_PASSWORD" "$CASE_STARTER_PASSWORD" | smbpasswd -s -a "' + user + '"',
                    "Create approved lab Finance starter " + user + " (password omitted)")
        exec_secret('PASSWD="$CASE_STARTER_PASSWORD" smbclient //fileserver/Public -U "' + user + '" -m SMB3 -c ls',
                    "Starter can authenticate and list Public")
        code, output = run(["compose", "exec", "-T", "-e", "PASSWD=" + password, "fileserver", "smbclient",
                            "//fileserver/Finance", "-U", user, "-m", "SMB3", "-c", "ls"],
                           "Starter Finance access before group assignment", ok=False)
        assert code != 0 and "NT_STATUS_ACCESS_DENIED" in output
        compose("fileserver", ["sh", "-c", 'id "' + user + '"; testparm -s 2>/dev/null | sed -n "/^\\[Finance\\]/,/^\\[/p"'],
                "id starter; effective Finance share ACL")
        compose("fileserver", ["sh", "-c", 'addgroup "' + user + '" finance; net cache flush; id "' + user + '"'],
                "Manager-approved fix: add starter to finance; refresh identity cache")
        script = ('set -eu; export PASSWD="$CASE_STARTER_PASSWORD"; printf "Finance starter test\\n" > /tmp/' + user + '.txt; '
                  'smbclient //fileserver/Finance -U "' + user + '" -m SMB3 -c "put /tmp/' + user + '.txt ' + user + '.txt; '
                  'get ' + user + '.txt /tmp/' + user + '-download.txt; del ' + user + '.txt"; '
                  'cmp /tmp/' + user + '.txt /tmp/' + user + '-download.txt; rm /tmp/' + user + '*.txt')
        exec_secret(script, "Starter Finance write/read/delete succeeds after group membership")
        log("PASS Finance starter fault reproduced and repaired")
    finally:
        compose("fileserver", ["sh", "-c", 'smbpasswd -x "' + user + '"; deluser "' + user + '"'], "Remove temporary starter account")
    case_doc("02-finance-starter.md", "New Finance starter cannot open Finance",
             "I'm starting in Finance today. Public opens, but Finance says Access is denied.",
             "Which username and exact path? Does Public work? Has the Finance manager approved access? Have you signed out since the group change?",
             "Created a real temporary Samba user in staff. Public authentication succeeded while Finance was denied. Compared the user's groups with the effective share ACL; did not broaden the share.",
             start,
             "The starter belonged to staff but was missing finance. Finance permits @finance. The standalone server is separate from the AD lab: GG-Finance membership alone does not grant this share.",
             "After simulated manager approval, add the Samba user to finance, clear the identity cache, and open a new SMB session. For a domain-joined server, assign the approved AD file-access group instead.",
             "The same user writes, reads back and deletes a Finance test file; contents match. Temporary account is removed.",
             "Your Finance access is now assigned following manager approval. Reconnect the mapped drive using your own username and try again.",
             "Include manager-approved file groups in the starter checklist and test with the new user's credentials. Maintain separate AD and Samba account records until domain integration.")
def print_case():
    start = len(LINES); title = "case-print-" + secrets.token_hex(4); jobid = None
    try:
        compose("printserver", ["cupsdisable", "-r", "LAB SIMULATION: paused by maintenance", "Office-PDF", "Office-Laser"], "Fault injection: stop both office queues")
        compose("printserver", ["lpstat", "-p", "-d"], "lpstat -p -d (office-wide failure)")
        _, out = compose("printserver", ["sh", "-c", 'printf "Office-wide print test\\n" | lp -d Office-PDF -t "' + title + '"'], "Submit test page while Office-PDF is stopped")
        jobid = re.search(r"Office-PDF-(\d+)", out).group(1)
        _, pending = compose("printserver", ["lpstat", "-W", "not-completed", "-o", "Office-PDF"], "lpstat: job remains queued")
        assert "Office-PDF-" + jobid in pending
        log("PASS reproduced: both queues disabled; submitted PDF remains pending")
        compose("printserver", ["cupsenable", "Office-PDF", "Office-Laser"], "Fix: enable both queues")
        compose("printserver", ["cupsaccept", "Office-PDF", "Office-Laser"], "Fix: accept new jobs")
        for attempt in range(30):
            code, output = compose("printserver", ["ipptool", "-t", "-d", "jobid=" + jobid, "ipp://localhost", "/lab-job-completed.test"], None, ok=False)
            if code == 0: log("> ipptool: original stuck job"); log(output); break
            time.sleep(1)
        else: raise RuntimeError("Original job did not reach completed state")
        compose("printserver", ["lpstat", "-p", "-d"], "lpstat -p -d after recovery")
        log("PASS original queued job completed (IPP job-state=9); both queues enabled")
    finally:
        compose("printserver", ["cupsenable", "Office-PDF", "Office-Laser"], None, ok=False)
        compose("printserver", ["cupsaccept", "Office-PDF", "Office-Laser"], None, ok=False)
        if jobid: compose("printserver", ["cancel", "Office-PDF-" + jobid], None, ok=False)
    case_doc("03-office-printing.md", "Print jobs stuck for the whole office",
             "Nobody can print. My job just sits there, and another colleague has the same problem.",
             "Which queues and how many people? When did it start? Any maintenance? Does the printers page load? Is there a device error?",
             "Treat as simulated P2 because multiple users are affected. Paused both queues, then submitted a page to the stopped PDF queue; it remained pending. Web availability alone does not prove printing works.",
             start,
             "Maintenance left both server queues disabled. Office-Laser is a simulated IPP device; scheduler recovery is verified with Office-PDF rather than claiming physical output.",
             "Review the disable reason, enable both queues and accept jobs. In a real incident, cancel only the blocking job after checking its owner; do not purge the office without approval.",
             "The original pending job reaches IPP completed state 9 and both queues are enabled. Finally restores state even on failure.",
             "The office queues were still paused after maintenance. They are enabled again, and the waiting test page completed. Please retry your job once; send the queue and job number if it remains stuck.",
             "Add queue state and end-to-end print tests to the maintenance checklist. Monitor availability plus scheduler/job failures; record who paused a queue and when to re-enable it.")
if __name__ == "__main__":
    log("LAB SIMULATION — three reversible faults, " + STAMP + " Australia/Sydney")
    try:
        vpn_case(); finance_case(); print_case()
        log("RESULT: all three faults reproduced, repaired, verified and cleaned up")
    except Exception as error:
        log("FAIL " + redact(str(error))); sys.exit(1)
