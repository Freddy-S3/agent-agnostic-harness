# Private queue relay deployment

This is the reproducible bootstrap path for the dedicated Ubuntu 24.04 `queue-relay` Lightsail instance.

The host receives no personal AWS credentials and the application never binds a public port directly.
Node listens on `127.0.0.1:4317`; Nginx terminates TLS on 443 and proxies to it.
The host firewall and Lightsail firewall both leave SSH and HTTP closed.

## 1. Prepare the release

Push the branch containing this directory so the relay can fetch the exact source over HTTPS:

```bash
git push -u origin codex/private-queue-portal
```

Use the Lightsail browser-based SSH session from the AWS console to run the following on the relay.
This path does not create or copy an SSH private key.

```bash
sudo mkdir -p /opt/queue-relay
sudo git clone --depth 1 --branch codex/private-queue-portal \
  https://github.com/Freddy-S3/agent-agnostic-harness.git /opt/queue-relay/release
sudo bash /opt/queue-relay/release/deploy/queue-relay/bootstrap.sh stage
```

Stage is intentionally loopback-only.
Verify that it returns 401 before making a DNS or TLS change:

```bash
curl -i http://127.0.0.1:4317/
sudo systemctl --no-pager --full status queue-relay.service
```

The generated token and encrypted-snapshot key are stored in `/etc/queue-relay/queue-relay.env` with mode 0600.
The token is never committed, logged by the bootstrap script, or sent to the browser until the owner enters it on the unlock page.

## 2. Point the private hostname at the existing static IP

Only after the authenticated loopback check succeeds, create the single Route 53 A record:

```powershell
aws route53 change-resource-record-sets `
  --hosted-zone-id Z0486266VR1UTIWTG4VW `
  --profile AdministratorAccess-787400111062 `
  --change-batch '{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"queue.alazyengineer.com.","Type":"A","TTL":60,"ResourceRecords":[{"Value":"34.233.45.105"}]}}]}'
```

The two existing Amplify records are unrelated and must not be changed.

## 3. Activate TLS and the public private portal

After the A record resolves to `34.233.45.105`, run the activation stage from the same browser session:

```bash
sudo QUEUE_DOMAIN=queue.alazyengineer.com \
  bash /opt/queue-relay/release/deploy/queue-relay/bootstrap.sh activate
```

Certbot uses TLS-ALPN on 443, so HTTP never needs to be opened.
The script installs the certificate, configures Nginx, enables only 443 in UFW, and verifies that the HTTPS endpoint still returns 401 before unlock.

Verify from the local workstation:

```powershell
aws lightsail get-instance-port-states --instance-name queue-relay --region us-east-1 --profile AdministratorAccess-787400111062
curl.exe -I https://queue.alazyengineer.com/
```

The expected public state is one open TCP range: 443.
The first browser visit shows the unlock form; use the token from the protected env file through the console session, then let the browser retain the HttpOnly cookie.

## Adapter configuration

Cloud and desktop delivery are optional authenticated HTTPS adapters.
Configure their capability JSON and bearer tokens in `/etc/queue-relay/queue-relay.env` only when the corresponding host has been separately authorized:

```text
QUEUE_CLOUD_CAPABILITIES={"available":true,"repositories":["https://github.com/Freddy-S3/agent-agnostic-harness"],"tools":["queue-actions"]}
QUEUE_CLOUD_ADAPTER_URL=https://authorized-cloud-adapter.example/queue-actions
QUEUE_CLOUD_ADAPTER_TOKEN=<adapter-secret>
QUEUE_DESKTOP_CAPABILITIES={"available":true,"repositories":["C:/Users/faruk/Repo/agent-agnostic-harness"],"tools":["queue-actions"]}
QUEUE_DESKTOP_ADAPTER_URL=https://authorized-desktop-adapter.example/queue-actions
QUEUE_DESKTOP_ADAPTER_TOKEN=<adapter-secret>
```

An adapter is selected only when both its capability record and its authenticated endpoint are configured.
The portal sends one action with its idempotency key and never runs shell, merge, deploy, secret, billing, or public-publishing commands.
Missing or unavailable adapters leave the action durable and deferred.

## Recovery

To stage a new release, replace `/opt/queue-relay/release` with a fresh HTTPS clone and rerun `bootstrap.sh stage`.
The queue data and secrets remain under `/var/lib/queue-relay/queue` and `/etc/queue-relay`.
Do not open SSH as a standing workaround; use the Lightsail browser session for a bounded bootstrap and re-check that only 443 is open afterward.
