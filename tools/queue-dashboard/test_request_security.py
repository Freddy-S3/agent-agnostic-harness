"""Exercise security guards against a real dashboard with synthetic files."""

import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
SERVER = ROOT / "tools" / "queue-dashboard" / "server.mjs"

with tempfile.TemporaryDirectory(prefix="queue-security-") as directory:
    queue = Path(directory)
    study = queue / "STUDY.md"
    study.write_text("## Reading\n- [ ] Read one chapter\n", encoding="utf-8")
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
    base = f"http://127.0.0.1:{port}"
    env = {**os.environ, "PORT": str(port), "QUEUE_DIR": str(queue), "QUEUE_TOKEN": "synthetic-token"}
    server = subprocess.Popen(["node", str(SERVER)], cwd=ROOT, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        for _ in range(80):
            try:
                with socket.create_connection(("127.0.0.1", port), timeout=0.2):
                    break
            except OSError:
                time.sleep(0.1)
        else:
            raise AssertionError("dashboard did not start")

        def post(data, origin=None, cookie=True):
            headers = {"Content-Type": "application/json"}
            if cookie:
                headers["Cookie"] = "qd=synthetic-token"
            if origin is not None:
                headers["Origin"] = origin
            request = urllib.request.Request(base + "/api/study", data=data, headers=headers, method="POST")
            try:
                with urllib.request.urlopen(request, timeout=5) as response:
                    return response.status
            except urllib.error.HTTPError as error:
                return error.code

        body = json.dumps({"index": 0, "done": True, "text": "Read one chapter"}).encode()
        assert post(body, "https://attacker.example") == 403
        assert post(body) == 403
        assert post(body, base, cookie=False) == 401
        assert post(b"x" * 65_537, base) == 413
        assert "- [ ]" in study.read_text(encoding="utf-8")
        assert post(body, base) == 200
        assert "- [x]" in study.read_text(encoding="utf-8")
    finally:
        server.terminate()
        try:
            server.wait(timeout=5)
        except subprocess.TimeoutExpired:
            server.kill()
            server.wait(timeout=5)
