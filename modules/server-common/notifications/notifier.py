"""Local, durable incident notifications. Only the worker needs a Resend key."""

import argparse
import contextlib
import datetime
import email.utils
import http.client
import http.server
import json
import os
import sqlite3
import subprocess
import threading
import time
import urllib.error
import urllib.request
import uuid


class Store:
    def __init__(self, config):
        self.config = config
        self.path = config["database"]
        os.makedirs(os.path.dirname(self.path), mode=0o750, exist_ok=True)
        with self.connect() as db:
            db.executescript("""
                CREATE TABLE IF NOT EXISTS incidents (
                    key TEXT PRIMARY KEY, source TEXT NOT NULL, active INTEGER NOT NULL,
                    last_notice REAL NOT NULL, summary TEXT NOT NULL, details TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS queue (
                    id TEXT PRIMARY KEY, payload TEXT NOT NULL, created REAL NOT NULL,
                    due REAL NOT NULL, attempts INTEGER NOT NULL DEFAULT 0,
                    state TEXT NOT NULL DEFAULT 'pending', error TEXT
                );
                CREATE TABLE IF NOT EXISTS samples (
                    key TEXT PRIMARY KEY, since REAL NOT NULL, last REAL NOT NULL,
                    successes INTEGER NOT NULL
                );
            """)

    @contextlib.contextmanager
    def connect(self):
        db = sqlite3.connect(self.path, timeout=30)
        db.row_factory = sqlite3.Row
        db.execute("PRAGMA journal_mode=WAL")
        db.execute("PRAGMA synchronous=FULL")
        try:
            with db:
                yield db
        finally:
            db.close()

    def submit(self, key, source, status, summary, details="", now=None):
        if status not in ("firing", "resolved"):
            raise ValueError("status must be firing or resolved")
        if not all(isinstance(v, str) for v in (key, source, summary, details)):
            raise ValueError("notification fields must be strings")
        if not key or not summary or max(map(len, (key, source, summary))) > 1024:
            raise ValueError("missing or oversized notification fields")
        if len(details) > 32768:
            raise ValueError("notification details exceed 32 KiB")
        now = time.time() if now is None else now
        active = status == "firing"
        with self.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            old = db.execute("SELECT * FROM incidents WHERE key=?", (key,)).fetchone()
            if not active and (old is None or not old["active"]):
                return False
            if active and old and old["active"] and now - old["last_notice"] < self.config["reminderSeconds"]:
                return False
            timestamp = datetime.datetime.fromtimestamp(now, datetime.timezone.utc).isoformat()
            payload = {
                "from": self.config["sender"], "to": [self.config["recipient"]],
                "subject": f"[{self.config['host']}] {status.upper()}: {summary}",
                "text": f"Host: {self.config['host']}\nSource: {source}\nIncident: {key}\nStatus: {status}\nTime: {timestamp}\n\n{summary}\n\n{details}",
            }
            db.execute("INSERT INTO queue(id,payload,created,due) VALUES(?,?,?,?)",
                       (str(uuid.uuid4()), json.dumps(payload), now, now))
            db.execute("INSERT OR REPLACE INTO incidents VALUES(?,?,?,?,?,?)",
                       (key, source, active, now, summary, details))
        return True

    def sample(self, key, failed, summary, details, delay=120, recoveries=2, now=None):
        now = time.time() if now is None else now
        with self.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            old = db.execute("SELECT * FROM samples WHERE key=?", (key,)).fetchone()
            continuous = old is not None and now - old["last"] <= 90
            since = old["since"] if continuous and old["successes"] == 0 else now
            successes = 0 if failed else (old["successes"] + 1 if continuous else 1)
            db.execute("INSERT OR REPLACE INTO samples VALUES(?,?,?,?)", (key, since, now, successes))
        if failed and now - since >= delay:
            self.submit(key, "healthcheck", "firing", summary, details, now)
        elif not failed and successes >= recoveries:
            self.submit(key, "healthcheck", "resolved", summary, details, now)

    def webhook(self, body):
        if not isinstance(body, dict) or not isinstance(body.get("alerts"), list) or not body["alerts"]:
            raise ValueError("expected Alertmanager alerts")
        events = []
        for alert in body["alerts"]:
            if not isinstance(alert, dict):
                raise ValueError("expected alert object")
            labels = alert["labels"]
            annotations = alert.get("annotations", {})
            if not isinstance(labels, dict) or not isinstance(annotations, dict):
                raise ValueError("expected labels and annotations objects")
            fingerprint = alert["fingerprint"]
            if not isinstance(fingerprint, str) or not fingerprint:
                raise ValueError("missing fingerprint")
            status = alert["status"]
            if status not in ("firing", "resolved"):
                raise ValueError("invalid alert status")
            # StartsAt distinguishes a new occurrence from a reminder or webhook retry.
            key = "prometheus:" + fingerprint + ":" + alert["startsAt"]
            summary = annotations.get("summary", labels["alertname"])
            details = json.dumps({"labels": labels, "annotations": annotations}, sort_keys=True)
            if len(key) > 1024 or not isinstance(summary, str) or len(summary) > 1024 or len(details) > 32768:
                raise ValueError("oversized alert")
            events.append((key, "prometheus", status, summary, details))
        for event in events:
            self.submit(*event)

    def metrics(self):
        with self.connect() as db:
            pending = db.execute("SELECT count(*),min(created) FROM queue WHERE state='pending'").fetchone()
            failed = db.execute("SELECT count(*) FROM queue WHERE state='failed'").fetchone()[0]
        age = max(0, time.time() - pending[1]) if pending[1] else 0
        return (f"notifications_pending {pending[0]}\nnotifications_failed {failed}\n"
                f"notifications_oldest_pending_seconds {age}\n")


def deliver(store, key, now=None):
    """Single worker; an ambiguous delivery is retried with the same idempotency key."""
    now = time.time() if now is None else now
    with store.connect() as db:
        row = db.execute("SELECT * FROM queue WHERE state='pending' ORDER BY created,rowid LIMIT 1").fetchone()
    if row is None or row["due"] > now:
        return
    request = urllib.request.Request(
        store.config.get("resendUrl", "https://api.resend.com/emails"),
        data=row["payload"].encode(),
        headers={"Authorization": "Bearer " + key, "Content-Type": "application/json",
                 "Idempotency-Key": row["id"], "User-Agent": "homelab-notifications/1"},
        method="POST",
    )
    state, error, retry_after = "sent", None, 0
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            if response.status != 200:
                raise ValueError("unexpected Resend response")
            result = json.load(response)
            if not isinstance(result.get("id"), str):
                raise ValueError("missing delivery ID")
    except urllib.error.HTTPError as exc:
        error = f"HTTP {exc.code}"
        state = "pending" if exc.code in (408, 429) or exc.code >= 500 else "failed"
        raw = exc.headers.get("Retry-After", "0")
        try:
            retry_after = max(0, float(raw))
        except ValueError:
            try:
                retry_after = max(0, email.utils.parsedate_to_datetime(raw).timestamp() - now)
            except (ValueError, TypeError, OverflowError):
                pass
        exc.close()
    except (OSError, ValueError, http.client.HTTPException):
        state, error = "pending", "network failure or invalid response"
    attempts = row["attempts"] + 1
    delay = max(retry_after, min(900, 30 * 2 ** min(attempts - 1, 5)))
    with store.connect() as db:
        db.execute("UPDATE queue SET state=?,error=?,attempts=?,due=? WHERE id=?",
                   (state, error, attempts, now + delay, row["id"]))
        db.execute("DELETE FROM queue WHERE state='sent' AND created < ?", (now - 7 * 86400,))
        db.execute("DELETE FROM incidents WHERE active=0 AND last_notice < ?", (now - 7 * 86400,))
    if error:
        print(f"delivery {row['id']}: {error} ({state})", flush=True)


def serve(store):
    credential = os.path.join(os.environ["CREDENTIALS_DIRECTORY"], "resend-api-key")
    with open(credential, encoding="utf-8") as handle:
        key = handle.read().strip()
    if not key:
        raise ValueError("empty Resend credential")

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def do_GET(self):
            if self.path != "/metrics":
                self.send_error(404)
                return
            payload = store.metrics().encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def do_POST(self):
            if self.path != "/alertmanager":
                self.send_error(404)
                return
            try:
                length = int(self.headers.get("Content-Length", "0"))
                if not 0 < length <= 1024 * 1024:
                    self.send_error(413)
                    return
                self.connection.settimeout(10)
                store.webhook(json.loads(self.rfile.read(length)))
            except (ValueError, KeyError, TypeError, OSError):
                self.send_error(400)
                return
            except sqlite3.Error:
                self.send_error(503)
                return
            self.send_response(202)
            self.end_headers()

    server = http.server.ThreadingHTTPServer(("127.0.0.1", store.config["port"]), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    while thread.is_alive():
        deliver(store, key)
        time.sleep(1)
    raise RuntimeError("notification HTTP server stopped")


def unit_details(unit):
    result = subprocess.run(
        ["systemctl", "show", "--property=Id,ActiveState,Result,ExecMainCode,ExecMainStatus", "--", unit],
        capture_output=True, text=True, timeout=10, check=True,
    )
    return result.stdout + f"\nInspect: systemctl status -- {unit}\nJournal: journalctl -u {unit}"


def unit_failure(store, unit):
    if unit.startswith("notification-failure@"):
        return
    store.submit("systemd:" + unit, "systemd", "firing", f"Unit failed: {unit}", unit_details(unit))


def check_health(store):
    config = store.config
    result = subprocess.run(["ping", "-n", "-c", "1", "-W", "3", config["peer"]],
                            capture_output=True, timeout=5, check=False)
    store.sample("peer:" + config["peer"], result.returncode != 0,
                 "WireGuard peer unreachable", f"Peer: {config['peer']}", delay=config["failureSeconds"])
    for name, url in config["readiness"].items():
        try:
            with urllib.request.urlopen(url, timeout=5) as response:
                healthy = response.status == 200
        except (OSError, ValueError):
            healthy = False
        store.sample("readiness:" + name, not healthy, f"{name} is not ready", url,
                     delay=config["failureSeconds"])
    result = subprocess.run(["systemctl", "list-units", "--all", "--state=failed", "--output=json", "--no-pager"],
                            capture_output=True, text=True, timeout=15, check=True)
    failed = {item["unit"] for item in json.loads(result.stdout)}
    for unit in sorted(failed):
        unit_failure(store, unit)
    with store.connect() as db:
        active = db.execute("SELECT key FROM incidents WHERE source='systemd' AND active=1").fetchall()
    for row in active:
        unit = row["key"].removeprefix("systemd:")
        if unit not in failed:
            store.submit(row["key"], "systemd", "resolved", f"Unit failed state cleared: {unit}",
                         "The unit no longer appears in systemd's failed-unit list.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("serve")
    sub.add_parser("check")
    sub.add_parser("queue")
    retry = sub.add_parser("retry")
    retry.add_argument("id")
    failure = sub.add_parser("unit-failure")
    failure.add_argument("unit")
    submit = sub.add_parser("submit")
    submit.add_argument("--key", required=True)
    submit.add_argument("--source", default="manual")
    submit.add_argument("--status", choices=["firing", "resolved"], default="firing")
    submit.add_argument("--summary", required=True)
    submit.add_argument("--details", default="")
    args = parser.parse_args()
    with open(args.config, encoding="utf-8") as handle:
        store = Store(json.load(handle))
    if args.command == "serve":
        serve(store)
    elif args.command == "check":
        check_health(store)
    elif args.command == "unit-failure":
        unit_failure(store, args.unit)
    elif args.command == "submit":
        store.submit(args.key, args.source, args.status, args.summary, args.details)
    elif args.command == "queue":
        with store.connect() as db:
            print(json.dumps([dict(row) for row in db.execute(
                "SELECT id,created,state,attempts,error FROM queue WHERE state!='sent' ORDER BY created"
            )], indent=2))
    elif args.command == "retry":
        with store.connect() as db:
            result = db.execute("UPDATE queue SET state='pending',due=0 WHERE id=? AND state!='sent'", (args.id,))
            if not result.rowcount:
                raise SystemExit("no pending or failed message with that ID")


if __name__ == "__main__":
    main()
