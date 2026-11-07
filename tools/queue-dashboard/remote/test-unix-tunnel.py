"""Exercise the real SSH socket tunnel in an isolated Linux mount namespace.

Run as root in a disposable test environment with SSHD_BINARY set. The script
re-executes itself inside a private mount namespace and never modifies host users,
network firewall rules, or system configuration. All credentials are synthetic.
"""

import http.server
import os
from pathlib import Path
import socket
import stat
import subprocess
import sys
import tempfile
import threading
import time

SSHD = os.environ["SSHD_BINARY"]
EXAMPLE = Path(__file__).with_name("sshd-queuebridge.conf.example")

if len(sys.argv) == 1:
    if os.geteuid() != 0:
        raise SystemExit("Run this isolated integration test as root")
    subprocess.run(
        ["unshare", "--mount", "--propagation", "private", "--", sys.executable, __file__, "--isolated"],
        check=True,
    )
    raise SystemExit(0)
if sys.argv[1:] != ["--isolated"]:
    raise SystemExit("Invalid test mode")
if os.geteuid() != 0:
    raise SystemExit("Run this isolated integration test as root")
if os.readlink("/proc/self/ns/mnt") == os.readlink(f"/proc/{os.getppid()}/ns/mnt"):
    raise SystemExit("Refusing to mount without a separate mount namespace")
for mount in Path("/proc/self/mountinfo").read_text(encoding="utf-8").splitlines():
    optional_fields = mount.split(" - ", 1)[0].split()[6:]
    if any(field.startswith("shared:") for field in optional_fields):
        raise SystemExit("Refusing to mount with shared propagation")


def run(*args, **kwargs):
    return subprocess.run(args, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, **kwargs)


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"synthetic queue")

    def log_message(self, *args):
        pass


with tempfile.TemporaryDirectory(prefix="queue-unix-tunnel-") as raw:
    root = Path(raw)
    root.chmod(0o755)
    subprocess.run(["mount", "-t", "tmpfs", "tmpfs", "/run"], check=True)
    Path("/run/sshd").mkdir(mode=0o755)
    socket_dir = Path("/run/queuebridge")
    socket_dir.mkdir(mode=0o750)
    os.chown(socket_dir, 12346, 12347)
    socket_dir.chmod(0o2750)

    passwd = root / "passwd"
    passwd.write_text(
        "root:x:0:0:root:/root:/bin/sh\n"
        "sshd:x:12345:12345:sshd:/run/sshd:/usr/sbin/nologin\n"
        f"queuebridge:x:12346:12346:bridge:{root}:/bin/sh\n"
        "caddy:x:12348:12347:caddy:/nonexistent:/usr/sbin/nologin\n",
        encoding="utf-8",
    )
    group = root / "group"
    group.write_text("root:x:0:\nsshd:x:12345:\nqueuebridge:x:12346:\ncaddy:x:12347:\n", encoding="utf-8")
    shadow = root / "shadow"
    shadow.write_text("root:!:1:0:99999:7:::\nqueuebridge:$6$test$synthetic:1:0:99999:7:::\n", encoding="utf-8")
    for source, destination in ((passwd, "/etc/passwd"), (group, "/etc/group"), (shadow, "/etc/shadow")):
        subprocess.run(["mount", "--bind", str(source), destination], check=True)

    host_key = root / "hostkey"
    client_key = root / "clientkey"
    run("ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(host_key))
    run("ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(client_key))
    authorized = root / "authorized_keys"
    authorized.write_text(client_key.with_suffix(".pub").read_text(encoding="utf-8"), encoding="utf-8")
    authorized.chmod(0o644)
    upstream = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=upstream.serve_forever, daemon=True).start()
    upstream_port = upstream.server_address[1]
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        ssh_port = listener.getsockname()[1]
    known_hosts = root / "known_hosts"
    known_hosts.write_text(f"[127.0.0.1]:{ssh_port} " + host_key.with_suffix(".pub").read_text(encoding="utf-8"), encoding="utf-8")
    config = root / "sshd_config"
    config.write_text(
        f"Port {ssh_port}\nListenAddress 127.0.0.1\nHostKey {host_key}\n"
        f"PidFile {root / 'sshd.pid'}\nAuthorizedKeysFile {authorized}\n"
        "UsePAM no\nStrictModes no\nAllowUsers queuebridge\nLogLevel VERBOSE\n"
        + EXAMPLE.read_text(encoding="utf-8"), encoding="utf-8",
    )
    server_log = (root / "sshd.log").open("w+", encoding="utf-8")
    server = subprocess.Popen([SSHD, "-D", "-e", "-f", str(config)], stdout=subprocess.DEVNULL, stderr=server_log, text=True)
    tunnel = None
    try:
        for _ in range(100):
            if server.poll() is not None:
                raise AssertionError("SSH server exited: " + (root / "sshd.log").read_text(encoding="utf-8"))
            try:
                with socket.create_connection(("127.0.0.1", ssh_port), timeout=0.2):
                    break
            except OSError:
                time.sleep(0.1)
        else:
            raise AssertionError("SSH server did not start")
        common = ["ssh", "-F", "/dev/null", "-o", "BatchMode=yes", "-o", "IdentitiesOnly=yes", "-o", "StrictHostKeyChecking=yes", "-o", f"UserKnownHostsFile={known_hosts}", "-o", "GlobalKnownHostsFile=/dev/null", "-i", str(client_key), "-p", str(ssh_port)]
        socket_path = socket_dir / "queue.sock"
        tunnel = subprocess.Popen(
            common + ["-N", "-T", "-o", "ExitOnForwardFailure=yes", "-R", f"{socket_path}:127.0.0.1:{upstream_port}", "queuebridge@127.0.0.1"],
            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True,
        )
        for _ in range(100):
            if tunnel.poll() is not None:
                raise AssertionError("SSH tunnel exited: " + tunnel.stderr.read() + "\n" + (root / "sshd.log").read_text(encoding="utf-8"))
            if socket_path.exists():
                break
            time.sleep(0.1)
        else:
            raise AssertionError("SSH tunnel did not create its socket")
        details = socket_path.stat()
        assert stat.S_IMODE(details.st_mode) == 0o660
        assert (details.st_uid, details.st_gid) == (12346, 12347)

        probe = "import socket,sys; s=socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); s.sendall(b'GET / HTTP/1.0\\r\\n\\r\\n'); assert b'200 OK' in s.recv(4096)"
        def credentials(uid, gid):
            def switch():
                os.setgroups([])
                os.setgid(gid)
                os.setuid(uid)
            return switch
        subprocess.run([sys.executable, "-c", probe, str(socket_path)], check=True, preexec_fn=credentials(12348, 12347), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        denied = subprocess.run([sys.executable, "-c", probe, str(socket_path)], preexec_fn=credentials(12349, 12349), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        assert denied.returncode != 0, "an unrelated user connected to the queue socket"
        create_probe = "import pathlib,sys; pathlib.Path(sys.argv[1]).touch()"
        for uid, gid in ((12348, 12347), (12349, 12349)):
            denied = subprocess.run([sys.executable, "-c", create_probe, str(socket_dir / "imposter.sock")], preexec_fn=credentials(uid, gid), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            assert denied.returncode != 0, "an unrelated process could replace the queue socket"

        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            forbidden_port = listener.getsockname()[1]
        try:
            tcp = subprocess.run(
                common + ["-N", "-T", "-o", "ExitOnForwardFailure=yes", "-R", f"127.0.0.1:{forbidden_port}:127.0.0.1:{upstream_port}", "queuebridge@127.0.0.1"],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5,
            )
            assert tcp.returncode != 0, "a TCP listener was unexpectedly allowed"
        except subprocess.TimeoutExpired as error:
            raise AssertionError("a TCP listener remained active") from error
        shell = subprocess.run(common + ["queuebridge@127.0.0.1", "id"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)
        assert shell.returncode != 0, "the bridge account obtained an interactive command"
    finally:
        if tunnel is not None:
            tunnel.terminate()
            tunnel.wait(timeout=5)
        server.terminate()
        server.wait(timeout=5)
        server_log.close()
        upstream.shutdown()
        upstream.server_close()
