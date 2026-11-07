# Private queue connection - preparation

The live queue stays on the PC and the dashboard continues to bind to loopback.
An outbound SSH tunnel can carry traffic from a separate HTTPS reverse proxy back to it.
The PC must be on, signed in, and running both the dashboard and the tunnel.

`start-ssh-tunnel.ps1` is the local tunnel runner.
It requires a dedicated SSH key and a separately verified pinned host key, fails if the
remote port cannot bind, and retries a disconnected tunnel.
It never accepts an unknown host key or forwards the dashboard directly to the internet.
Use `-DryRun` to inspect the SSH arguments without connecting.

This is preparation, not a complete or safe public deployment.
Before enabling access, the remote endpoint must enforce HTTPS and a separate
authentication gate, restrict its SSH account to loopback-only remote forwarding,
and be tested from an unauthenticated client.
The example Caddy and SSH configurations illustrate those boundaries.
Caddy 2.11.9 and OpenSSH 8.9 accepted the syntax in isolated local validation;
neither example has been installed or tested on a remote server.
The dashboard's `QUEUE_PUBLIC_ORIGIN` must exactly match the final HTTPS origin.
Do not publish queue files, access tokens, SSH private keys, passwords, or host credentials.

Run `pwsh -NoProfile -File tools/queue-dashboard/remote/test-ssh-tunnel.ps1` for the
local argument checks. With `CADDY_BINARY` set to a trusted Caddy executable, run
`python tools/queue-dashboard/remote/test-proxy.py` to check both authentication
layers and a safe write against the real dashboard with synthetic data. On Linux, set `SSHD_BINARY` and run
`sh tools/queue-dashboard/remote/test-sshd-config.sh` to check the effective
restrictions for the bridge account. A real tunnel and identity gate require
separate integration tests.
