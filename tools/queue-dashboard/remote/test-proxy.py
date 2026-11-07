"""Verify the example proxy protects a synthetic localhost service.

Set CADDY_BINARY to a trusted Caddy executable. This test uses a self-signed local
certificate and never installs a CA, changes DNS, or touches real queue data.
"""

import base64
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path
import socket
import ssl
import subprocess
import tempfile
import threading
import time
import urllib.error
import urllib.request

CADDY = os.environ["CADDY_BINARY"]
EXAMPLE = Path(__file__).with_name("Caddyfile.example")
TEST_HASH = "$2a$14$Zkx19XLiW6VYouLHR5NmfOFU0z2GTNmpkT/5qqR7hx4IjWJPDhjvG"


class SyntheticHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"synthetic queue")

    def log_message(self, *args):
        pass


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


with tempfile.TemporaryDirectory(prefix="queue-proxy-test-") as raw:
    root = Path(raw)
    upstream = ThreadingHTTPServer(("127.0.0.1", 0), SyntheticHandler)
    upstream_port = upstream.server_address[1]
    threading.Thread(target=upstream.serve_forever, daemon=True).start()
    proxy_port = free_port()
    config = root / "Caddyfile"
    config.write_text(
        "{\n    local_certs\n    skip_install_trust\n    auto_https disable_redirects\n}\n"
        + EXAMPLE.read_text(encoding="utf-8").replace("127.0.0.1:4317", f"127.0.0.1:{upstream_port}"),
        encoding="utf-8",
    )
    env = {
        **os.environ,
        "QUEUE_HOST": f"localhost:{proxy_port}",
        "QUEUE_BASIC_HASH": TEST_HASH,
        "XDG_DATA_HOME": str(root / "data"),
        "XDG_CONFIG_HOME": str(root / "config"),
    }
    proxy = subprocess.Popen(
        [CADDY, "run", "--config", str(config), "--adapter", "caddyfile"],
        env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    try:
        for _ in range(100):
            if proxy.poll() is not None:
                raise AssertionError("Caddy exited before accepting requests")
            try:
                with socket.create_connection(("127.0.0.1", proxy_port), timeout=0.2):
                    break
            except OSError:
                time.sleep(0.1)
        else:
            raise AssertionError("Caddy did not start")

        # This deliberately disables certificate verification only for the ephemeral
        # localhost test CA; production clients must validate a public certificate.
        tls = ssl.create_default_context()
        tls.check_hostname = False
        tls.verify_mode = ssl.CERT_NONE
        url = f"https://localhost:{proxy_port}/"
        try:
            urllib.request.urlopen(url, context=tls, timeout=5)
            raise AssertionError("unauthenticated request unexpectedly succeeded")
        except urllib.error.HTTPError as error:
            assert error.code == 401, f"unexpected unauthenticated response: {error.code}"

        wrong = base64.b64encode(b"queue:wrong-password").decode("ascii")
        request = urllib.request.Request(url, headers={"Authorization": f"Basic {wrong}"})
        try:
            urllib.request.urlopen(request, context=tls, timeout=5)
            raise AssertionError("incorrect password unexpectedly succeeded")
        except urllib.error.HTTPError as error:
            assert error.code == 401, f"unexpected incorrect-password response: {error.code}"

        credentials = base64.b64encode(b"queue:hiccup").decode("ascii")
        request = urllib.request.Request(url, headers={"Authorization": f"Basic {credentials}"})
        with urllib.request.urlopen(request, context=tls, timeout=5) as response:
            assert response.status == 200
            assert response.read() == b"synthetic queue"
            assert response.headers.get("Cache-Control") == "no-store"
    finally:
        proxy.terminate()
        try:
            proxy.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proxy.kill()
            proxy.wait(timeout=5)
        upstream.shutdown()
        upstream.server_close()
