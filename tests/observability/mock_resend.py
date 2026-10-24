"""VM-only Resend and application stand-in; never used on deployed hosts."""

import http.server
import json
import os


class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        payload = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        with open("/var/lib/mock-resend/messages", "a", encoding="utf-8") as handle:
            handle.write(json.dumps(payload) + "\n")
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'{"id":"mock-id"}')

    def do_GET(self):
        self.send_response(302 if self.path == "/login" else 200)
        if self.path == "/login":
            self.send_header("Location", "https://files.example.org/oauth2/start?rd=test")
        self.end_headers()
        self.wfile.write(b"healthy")


os.makedirs("/var/lib/mock-resend", exist_ok=True)
http.server.HTTPServer(("127.0.0.1", 9088), Handler).serve_forever()
