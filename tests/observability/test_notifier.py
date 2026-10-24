import concurrent.futures
import importlib.util
import io
import json
import pathlib
import tempfile
import unittest
import urllib.error
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "notifier", pathlib.Path(__file__).parents[2] / "modules/server-common/notifications/notifier.py"
)
notifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(notifier)


class Response(io.BytesIO):
    status = 200


class NotificationsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.config = {
            "database": self.temp.name + "/queue.sqlite", "host": "test-host",
            "sender": "alerts@example.org", "recipient": "test@example.org",
            "reminderSeconds": 21600,
        }
        self.store = notifier.Store(self.config)

    def rows(self):
        with self.store.connect() as db:
            return [dict(row) for row in db.execute("SELECT * FROM queue ORDER BY created,rowid")]

    def submit(self, **kwargs):
        return self.store.submit("test", "test", "firing", "Example failure", now=100, **kwargs)

    def test_transitions_reminders_and_restart(self):
        self.assertTrue(self.submit())
        self.assertFalse(self.submit())
        self.store = notifier.Store(self.config)
        self.assertFalse(self.store.submit("test", "test", "firing", "Example failure", now=21699))
        self.assertTrue(self.store.submit("test", "test", "firing", "Example failure", now=21700))
        self.assertTrue(self.store.submit("test", "test", "resolved", "Recovered", now=21701))
        self.assertFalse(self.store.submit("test", "test", "resolved", "Recovered", now=21702))
        self.assertTrue(self.store.submit("test", "test", "firing", "New failure", now=21703))
        self.assertEqual(len(self.rows()), 4)

    def test_concurrent_submission_is_deduplicated(self):
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            results = list(pool.map(lambda _: self.submit(), range(32)))
        self.assertEqual(sum(results), 1)
        self.assertEqual(len(self.rows()), 1)

    def test_short_outage_and_recovery_debounce(self):
        for now in (0, 30, 60, 90):
            self.store.sample("peer", True, "Peer down", "details", now=now)
        self.assertEqual(self.rows(), [])
        self.store.sample("peer", True, "Peer down", "details", now=120)
        self.assertEqual(len(self.rows()), 1)
        self.store.sample("peer", False, "Peer down", "details", now=150)
        self.assertEqual(len(self.rows()), 1)
        self.store.sample("peer", False, "Peer down", "details", now=180)
        self.assertEqual(len(self.rows()), 2)

    def test_sampling_gap_does_not_count_as_observed_outage(self):
        self.store.sample("peer", True, "Peer down", "details", now=0)
        self.store.sample("peer", True, "Peer down", "details", now=3600)
        self.assertEqual(self.rows(), [])

    def test_successful_delivery_retains_immutable_message(self):
        self.submit()
        before = self.rows()[0]
        with patch.object(notifier.urllib.request, "urlopen", return_value=Response(b'{"id":"resend-123"}')) as send:
            notifier.deliver(self.store, "test-key", now=100)
        request = send.call_args.args[0]
        self.assertEqual(request.get_header("Idempotency-key"), before["id"])
        self.assertEqual(request.data.decode(), before["payload"])
        self.assertEqual(self.rows()[0]["state"], "sent")

    def test_timeout_and_server_error_retry_same_key(self):
        self.submit()
        identity = self.rows()[0]["id"]
        for now, error in [(100, TimeoutError()), (130, urllib.error.HTTPError("test", 503, "bad", {}, None))]:
            with patch.object(notifier.urllib.request, "urlopen", side_effect=error):
                notifier.deliver(self.store, "test-key", now=now)
        row = self.rows()[0]
        self.assertEqual(row["id"], identity)
        self.assertEqual(row["state"], "pending")
        self.assertEqual(row["attempts"], 2)
        self.assertEqual(row["due"], 190)

    def test_rate_limit_honors_retry_after(self):
        self.submit()
        error = urllib.error.HTTPError("test", 429, "rate limit", {"Retry-After": "1200"}, None)
        with patch.object(notifier.urllib.request, "urlopen", side_effect=error):
            notifier.deliver(self.store, "test-key", now=100)
        self.assertEqual(self.rows()[0]["due"], 1300)

    def test_permanent_rejection_is_retained_and_does_not_block_queue(self):
        self.submit()
        self.store.submit("second", "test", "firing", "Another", now=101)
        error = urllib.error.HTTPError("test", 403, "denied", {}, None)
        with patch.object(notifier.urllib.request, "urlopen", side_effect=error):
            notifier.deliver(self.store, "test-key", now=102)
        with patch.object(notifier.urllib.request, "urlopen", return_value=Response(b'{"id":"second"}')):
            notifier.deliver(self.store, "test-key", now=103)
        self.assertEqual([row["state"] for row in self.rows()], ["failed", "sent"])
        self.assertIn("notifications_failed 1", self.store.metrics())

    def test_queue_preserves_firing_before_resolution_during_backoff(self):
        self.submit()
        self.store.submit("test", "test", "resolved", "Recovered", now=101)
        with patch.object(notifier.urllib.request, "urlopen", side_effect=TimeoutError()):
            notifier.deliver(self.store, "test-key", now=102)
        with patch.object(notifier.urllib.request, "urlopen") as send:
            notifier.deliver(self.store, "test-key", now=103)
        send.assert_not_called()

    def test_alertmanager_delivery_and_retries(self):
        body = {"alerts": [{"fingerprint": "abc", "startsAt": "2026-01-01T00:00:00Z",
                            "status": "firing", "labels": {"alertname": "Test"},
                            "annotations": {"summary": "test alert"}}]}
        self.store.webhook(body)
        self.store.webhook(body)
        self.assertEqual(len(self.rows()), 1)
        body["alerts"][0]["status"] = "resolved"
        self.store.webhook(body)
        self.assertEqual(len(self.rows()), 2)
        self.assertIn("RESOLVED", json.loads(self.rows()[1]["payload"])["subject"])

    def test_malformed_webhook_does_not_enqueue(self):
        for body in ({}, {"alerts": []}, {"alerts": [{}]}, {"alerts": "bad"}):
            with self.assertRaises((ValueError, KeyError, TypeError)):
                self.store.webhook(body)
        self.assertEqual(self.rows(), [])

    def test_handler_cannot_notify_its_own_failure(self):
        notifier.unit_failure(self.store, "notification-failure@foo.service.service")
        self.assertEqual(self.rows(), [])


if __name__ == "__main__":
    unittest.main()
