"""Verify the example proxy protects a real dashboard with synthetic data.

Set CADDY_BINARY to a trusted Caddy executable. This test uses a self-signed local
certificate and never installs a CA, changes DNS, or touches real queue data.
"""

import base64
import http.client
import json
import os
from pathlib import Path
import socket
import ssl
import subprocess
import tempfile
import time
import urllib.error
import urllib.request

CADDY = os.environ["CADDY_BINARY"]
EXAMPLE = Path(__file__).with_name("Caddyfile.example")
ROOT = Path(__file__).resolve().parents[3]
SERVER = ROOT / "tools" / "queue-dashboard" / "server.mjs"
TEST_HASH = "$2a$14$Zkx19XLiW6VYouLHR5NmfOFU0z2GTNmpkT/5qqR7hx4IjWJPDhjvG"


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


with tempfile.TemporaryDirectory(prefix="queue-proxy-test-") as raw:
    root = Path(raw)
    queue = root / "queue"
    queue.mkdir()
    study = queue / "STUDY.md"
    study.write_text("## Reading\n- [ ] Synthetic chapter\n", encoding="utf-8")
    upstream_port = free_port()
    proxy_port = free_port()
    config = root / "Caddyfile"
    config.write_text(
        "{\n    local_certs\n    skip_install_trust\n    auto_https disable_redirects\n}\n"
        + EXAMPLE.read_text(encoding="utf-8").replace("unix//run/queuebridge/queue.sock", f"127.0.0.1:{upstream_port}"),
        encoding="utf-8",
    )
    env = {
        **os.environ,
        "QUEUE_HOST": f"localhost:{proxy_port}",
        "QUEUE_BASIC_HASH": TEST_HASH,
        "XDG_DATA_HOME": str(root / "data"),
        "XDG_CONFIG_HOME": str(root / "config"),
    }
    dashboard_env = {
        **os.environ,
        "QUEUE_DIR": str(queue),
        "QUEUE_TOKEN": "synthetic-dashboard-token",
        "PORT": str(upstream_port),
        "QUEUE_PUBLIC_ORIGIN": f"https://localhost:{proxy_port}",
    }
    dashboard = subprocess.Popen(
        ["node", str(SERVER)], cwd=ROOT, env=dashboard_env,
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    proxy = subprocess.Popen(
        [CADDY, "run", "--config", str(config), "--adapter", "caddyfile"],
        env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    try:
        for _ in range(100):
            if dashboard.poll() is not None:
                raise AssertionError("dashboard exited before accepting requests")
            try:
                with socket.create_connection(("127.0.0.1", upstream_port), timeout=0.2):
                    break
            except OSError:
                time.sleep(0.1)
        else:
            raise AssertionError("dashboard did not start")
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
        basic_headers = {"Authorization": f"Basic {credentials}"}
        request = urllib.request.Request(url, headers=basic_headers)
        try:
            urllib.request.urlopen(request, context=tls, timeout=5)
            raise AssertionError("dashboard unexpectedly bypassed its own login")
        except urllib.error.HTTPError as error:
            assert error.code == 401, f"unexpected dashboard-login response: {error.code}"

        connection = http.client.HTTPSConnection("localhost", proxy_port, context=tls, timeout=5)
        connection.request(
            "POST", "/unlock", body=b"token=synthetic-dashboard-token",
            headers={**basic_headers, "Origin": url.rstrip("/"), "Content-Type": "application/x-www-form-urlencoded"},
        )
        login = connection.getresponse()
        assert login.status == 303, f"unexpected dashboard login status: {login.status}"
        cookie = login.getheader("Set-Cookie")
        assert cookie and "; Secure" in cookie and "; HttpOnly" in cookie and "; SameSite=Strict" in cookie
        login.read()
        connection.close()

        headers = {**basic_headers, "Cookie": cookie.split(";", 1)[0]}
        request = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(request, context=tls, timeout=5) as response:
            assert response.status == 200
            assert b"Queue" in response.read()
            assert response.headers.get("Cache-Control") == "no-store"

        payload = json.dumps({"index": 0, "done": True, "text": "Synthetic chapter"}).encode()
        attack = urllib.request.Request(
            url + "api/study", data=payload,
            headers={**headers, "Origin": "https://attacker.example", "Content-Type": "application/json"},
            method="POST",
        )
        try:
            urllib.request.urlopen(attack, context=tls, timeout=5)
            raise AssertionError("cross-origin write unexpectedly succeeded")
        except urllib.error.HTTPError as error:
            assert error.code == 403, f"unexpected cross-origin response: {error.code}"
        assert "- [ ]" in study.read_text(encoding="utf-8")

        legitimate = urllib.request.Request(
            url + "api/study", data=payload,
            headers={**headers, "Origin": url.rstrip("/"), "Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(legitimate, context=tls, timeout=5) as response:
            assert response.status == 200
        assert "- [x]" in study.read_text(encoding="utf-8")
    finally:
        proxy.terminate()
        try:
            proxy.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proxy.kill()
            proxy.wait(timeout=5)
        dashboard.terminate()
        try:
            dashboard.wait(timeout=5)
        except subprocess.TimeoutExpired:
            dashboard.kill()
            dashboard.wait(timeout=5)
