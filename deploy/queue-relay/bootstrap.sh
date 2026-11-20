#!/usr/bin/env bash
set -Eeuo pipefail

# Install or activate the private queue relay on a dedicated Ubuntu 24.04 Lightsail
# instance. This script never needs AWS credentials on the host. Stage first, verify the
# authenticated loopback service, then activate TLS after DNS points at the relay.

MODE="${1:-stage}"
SOURCE_DIR="${SOURCE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/tools/queue-dashboard}"
APP_DIR="${APP_DIR:-/opt/queue-relay/app}"
DATA_DIR="${QUEUE_DIR:-/var/lib/queue-relay/queue}"
SERVICE_USER="${SERVICE_USER:-queue-relay}"
DOMAIN="${QUEUE_DOMAIN:-}"
ENV_DIR="/etc/queue-relay"
ENV_FILE="$ENV_DIR/queue-relay.env"
SERVICE_FILE="/etc/systemd/system/queue-relay.service"
NGINX_FILE="/etc/nginx/sites-available/queue-relay"

die() { echo "queue-relay bootstrap: $*" >&2; exit 1; }
[[ "$(id -u)" == "0" ]] || die "run as root (sudo bash deploy/queue-relay/bootstrap.sh stage)"

install_packages() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y ca-certificates curl git nginx certbot nodejs openssl ufw
}

ensure_user() {
  if ! id -u "$SERVICE_USER" >/dev/null 2>&1; then
    useradd --system --home-dir /var/lib/queue-relay --create-home --shell /usr/sbin/nologin "$SERVICE_USER"
  fi
  install -d -o "$SERVICE_USER" -g "$SERVICE_USER" -m 0750 "$APP_DIR" "$DATA_DIR"
  install -d -o root -g root -m 0750 "$ENV_DIR"
}

install_app() {
  [[ -d "$SOURCE_DIR" ]] || die "missing queue dashboard source at $SOURCE_DIR"
  for file in server.mjs action-contract.mjs adapters.mjs control-center.mjs; do
    [[ -f "$SOURCE_DIR/$file" ]] || die "missing queue dashboard file $SOURCE_DIR/$file"
    install -o root -g root -m 0644 "$SOURCE_DIR/$file" "$APP_DIR/$file"
  done
  chown -R "$SERVICE_USER:$SERVICE_USER" "$APP_DIR" "$DATA_DIR"
}

ensure_env() {
  if [[ ! -f "$ENV_FILE" ]]; then
    local token snapshot tmp
    token="$(openssl rand -hex 24)"
    snapshot="$(openssl rand -hex 32)"
    tmp="$(mktemp)"
    umask 077
    {
      printf 'QUEUE_DIR=%s\n' "$DATA_DIR"
      printf 'PORT=4317\n'
      printf 'QUEUE_TOKEN=%s\n' "$token"
      printf 'QUEUE_SNAPSHOT_KEY=%s\n' "$snapshot"
      printf 'QUEUE_OFFLINE=0\n'
    } > "$tmp"
    install -o root -g root -m 0600 "$tmp" "$ENV_FILE"
    rm -f "$tmp"
  fi
  grep -q '^QUEUE_DIR=' "$ENV_FILE" || printf 'QUEUE_DIR=%s\n' "$DATA_DIR" >> "$ENV_FILE"
  grep -q '^PORT=' "$ENV_FILE" || printf 'PORT=4317\n' >> "$ENV_FILE"
  chmod 0600 "$ENV_FILE"
}

install_service() {
  install -o root -g root -m 0644 "$SOURCE_DIR/../../deploy/queue-relay/queue-relay.service" "$SERVICE_FILE"
  sed -i "s|@APP_DIR@|$APP_DIR|g; s|@DATA_DIR@|$DATA_DIR|g; s|@SERVICE_USER@|$SERVICE_USER|g; s|@ENV_FILE@|$ENV_FILE|g" "$SERVICE_FILE"
  systemctl daemon-reload
  systemctl enable queue-relay.service >/dev/null
  systemctl restart queue-relay.service
}

lock_firewall() {
  ufw default deny incoming
  ufw default allow outgoing
  ufw delete allow 22/tcp >/dev/null 2>&1 || true
  ufw delete allow 80/tcp >/dev/null 2>&1 || true
  ufw allow 443/tcp
  ufw deny 22/tcp >/dev/null 2>&1 || true
  ufw deny 80/tcp >/dev/null 2>&1 || true
  ufw --force enable
}

check_loopback() {
  local status
  status="$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' http://127.0.0.1:4317/ || true)"
  [[ "$status" == "401" ]] || die "queue relay did not return 401 on loopback (got $status)"
}

stage() {
  install_packages
  ensure_user
  install_app
  ensure_env
  install_service
  systemctl disable --now nginx >/dev/null 2>&1 || true
  lock_firewall
  check_loopback
  echo "queue-relay staged: authenticated loopback service is healthy; public TLS is not enabled"
}

activate() {
  [[ -n "$DOMAIN" ]] || die "QUEUE_DOMAIN is required for activate"
  [[ "$DOMAIN" != *"/"* ]] || die "QUEUE_DOMAIN must be a hostname"
  [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]] || {
    systemctl stop nginx >/dev/null 2>&1 || true
    certbot_args=(certonly --standalone --preferred-challenges tls-alpn-01 --non-interactive --agree-tos --keep-until-expiring -d "$DOMAIN")
    if [[ -n "${CERTBOT_EMAIL:-}" ]]; then
      certbot_args+=(--email "$CERTBOT_EMAIL")
    else
      certbot_args+=(--register-unsafely-without-email)
    fi
    certbot "${certbot_args[@]}"
  }
  install -o root -g root -m 0644 "$SOURCE_DIR/../../deploy/queue-relay/nginx.conf.template" "$NGINX_FILE"
  sed -i "s|@DOMAIN@|$DOMAIN|g" "$NGINX_FILE"
  ln -sfn "$NGINX_FILE" /etc/nginx/sites-enabled/queue-relay
  rm -f /etc/nginx/sites-enabled/default
  nginx -t
  systemctl enable nginx >/dev/null
  systemctl restart nginx
  lock_firewall
  local status
  status="$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' --resolve "$DOMAIN:443:127.0.0.1" "https://$DOMAIN/" || true)"
  [[ "$status" == "401" ]] || die "TLS proxy did not return 401 (got $status)"
  echo "queue-relay active: https://$DOMAIN/ returns 401 until the owner unlocks it"
}

case "$MODE" in
  stage) stage ;;
  activate) activate ;;
  *) die "usage: $0 stage|activate" ;;
esac
