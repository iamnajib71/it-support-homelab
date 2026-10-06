"""Create demo per-device VPN profiles so the dashboard shows a realistic office (idempotent).
Usage: python homelab/vpn/demo-peers.py"""
import http.cookiejar, json, re, urllib.request
from pathlib import Path

ENV = dict(re.findall(r"^(\w+)=(.*)$", (Path(__file__).resolve().parents[2] / ".env").read_text(), re.M))
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))

def api(path, method="GET", data=None):
    req = urllib.request.Request("http://127.0.0.1:51821/api/" + path, method=method,
                                 data=json.dumps(data).encode() if data is not None else None,
                                 headers={"Content-Type": "application/json"})
    with opener.open(req, timeout=20) as r:
        body = r.read().decode()
        return json.loads(body) if body.startswith(("{", "[")) else body

api("session", "POST", {"password": ENV["WG_ADMIN_PASSWORD"].strip()})
existing = {p["name"] for p in api("wireguard/client")}
for name in ["alice-laptop", "bob-laptop", "carol-phone"]:
    if name not in existing:
        api("wireguard/client", "POST", {"name": name})
        print("created", name)
print("peers:", sorted(p["name"] for p in api("wireguard/client")))
