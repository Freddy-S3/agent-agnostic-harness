#!/bin/sh
set -eu

: "${SSHD_BINARY:?Set SSHD_BINARY to an OpenSSH sshd executable}"
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
test_dir=$(mktemp -d /tmp/queue-sshd-test.XXXXXX)
case "$test_dir" in
  /tmp/queue-sshd-test.*) ;;
  *) echo 'Unexpected test directory' >&2; exit 1 ;;
esac
trap 'rm -f -- "$test_dir/hostkey" "$test_dir/hostkey.pub"; rmdir -- "$test_dir"' EXIT

ssh-keygen -q -t ed25519 -N '' -f "$test_dir/hostkey"
effective=$("$SSHD_BINARY" -T -f "$script_dir/sshd-queuebridge.conf.example" \
  -h "$test_dir/hostkey" -C user=queuebridge,host=localhost,addr=127.0.0.1)
for expected in \
  'passwordauthentication no' \
  'kbdinteractiveauthentication no' \
  'allowtcpforwarding remote' \
  'allowstreamlocalforwarding no' \
  'permitlisten 127.0.0.1:4317' \
  'permitopen none' \
  'gatewayports no' \
  'allowagentforwarding no' \
  'permittty no' \
  'forcecommand /usr/sbin/nologin'; do
  printf '%s\n' "$effective" | grep -Fqx "$expected" || {
    printf 'Missing effective SSH setting: %s\n' "$expected" >&2
    exit 1
  }
done
