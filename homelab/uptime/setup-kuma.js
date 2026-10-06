// Idempotent Uptime Kuma 1.23 setup: first-run admin, office monitors and a public status page.
// Runs inside the uptime container (uses Kuma's bundled socket.io-client):
//   docker compose exec -T -e KUMA_PASSWORD=... uptime node /lab/setup-kuma.js
const { io } = require("/app/node_modules/socket.io-client");

const USER = "admin";
const PASSWORD = process.env.KUMA_PASSWORD;
const SLUG = "office";

// Field defaults mirror what the Kuma 1.23 editor sends for a new monitor.
const base = {
  interval: 60, retryInterval: 60, resendInterval: 0, maxretries: 2, timeout: 48,
  notificationIDList: {}, ignoreTls: false, upsideDown: false, expiryNotification: false,
  maxredirects: 10, accepted_statuscodes: ["200-299"], method: "GET", packetSize: 56,
  dns_resolve_type: "A", dns_resolve_server: "1.1.1.1", httpBodyEncoding: "json",
  kafkaProducerBrokers: [], kafkaProducerSaslOptions: { mechanism: "None" },
  kafkaProducerSsl: false, kafkaProducerAllowAutoTopicCreation: false,
  gamedigGivenPortOnly: true, description: "", parent: null,
};
const MONITORS = [
  { ...base, type: "http", name: "VPN admin (wg-easy)", url: "http://wireguard:51821" },
  { ...base, type: "port", name: "File server (SMB 445)", hostname: "fileserver", port: 445 },
  { ...base, type: "http", name: "Print server (CUPS)", url: "http://printserver:631/printers/" },
  { ...base, type: "port", name: "Active Directory (LDAP 389)", hostname: "directory", port: 389 },
  { ...base, type: "port", name: "Active Directory (Kerberos 88)", hostname: "directory", port: 88 },
  { ...base, type: "http", name: "Office dashboard", url: "http://homepage:3000" },
];

const socket = io("http://127.0.0.1:3001", { transports: ["websocket"], reconnection: false });
const call = (event, ...args) => new Promise((resolve) => socket.emit(event, ...args, resolve));
let monitorList = null;
socket.on("monitorList", (list) => { monitorList = list; });
const fail = (msg) => { console.error("FAIL " + msg); process.exit(1); };

socket.on("connect", async () => {
  try {
    if (!PASSWORD) fail("KUMA_PASSWORD is not set");
    if (await call("needSetup")) {
      const r = await call("setup", USER, PASSWORD);
      if (!r.ok) fail("setup: " + r.msg);
      console.log("Created Kuma admin account (password in .env)");
    }
    const login = await call("login", { username: USER, password: PASSWORD, token: "" });
    if (!login.ok) fail("login: " + login.msg);
    for (let i = 0; i < 50 && monitorList === null; i++) await new Promise((r) => setTimeout(r, 100));

    const existing = Object.values(monitorList || {});
    const ids = [];
    for (const m of MONITORS) {
      const found = existing.find((e) => e.name === m.name);
      if (found) { ids.push(found.id); console.log("exists  " + m.name); continue; }
      const r = await call("add", m);
      if (!r.ok) fail("add " + m.name + ": " + r.msg);
      ids.push(r.monitorID);
      console.log("added   " + m.name);
    }

    const created = await call("addStatusPage", "ITOPS office services", SLUG);
    if (!created.ok && !/slug/i.test(created.msg || "")) fail("addStatusPage: " + created.msg);
    const config = {
      slug: SLUG, title: "ITOPS office services", description: "Small-office homelab (lab simulation)",
      icon: "/icon.svg", theme: "dark", published: true, showTags: false, domainNameList: [],
      customCSS: "", footerText: "Lab simulation - all services bound to localhost",
      showPoweredBy: false, googleAnalyticsId: null, showCertificateExpiry: false,
    };
    const groups = [{ name: "Office services", monitorList: ids.map((id) => ({ id })) }];
    const saved = await call("saveStatusPage", SLUG, config, "/icon.svg", groups);
    if (!saved.ok) fail("saveStatusPage: " + saved.msg);
    console.log("Status page ready: /status/" + SLUG + " with " + ids.length + " monitors");
    process.exit(0);
  } catch (e) { fail(e.message); }
});
socket.on("connect_error", (e) => fail("connect: " + e.message));
setTimeout(() => fail("timed out"), 60000);
