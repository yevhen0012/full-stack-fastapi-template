#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Deploy Ghost to a Hetzner Cloud VPS with no public SSH access.

Required environment variables:
  HCLOUD_TOKEN       Hetzner Cloud API token
  CF_TUNNEL_TOKEN    Cloudflare Tunnel token for a remotely-managed tunnel
  GHOST_HOSTNAME     Public hostname routed by the Cloudflare Tunnel

Optional environment variables:
  SERVER_NAME        Hetzner server name (default: ghost-blog)
  HCLOUD_LOCATION    Hetzner location (default: fsn1)
  HCLOUD_SERVER_TYPE Hetzner server type (default: cax11)
  HCLOUD_IMAGE       Hetzner image (default: ubuntu-24.04)
  FIREWALL_NAME      Hetzner firewall name (default: ghost-tunnel-only)

Example:
  export HCLOUD_TOKEN=...
  export CF_TUNNEL_TOKEN=...
  export GHOST_HOSTNAME=blog.example.com
  ./infra/ghost/deploy-ghost-hetzner.sh
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

require_command hcloud
require_command openssl

: "${HCLOUD_TOKEN:?Set HCLOUD_TOKEN to a Hetzner Cloud API token}"
: "${CF_TUNNEL_TOKEN:?Set CF_TUNNEL_TOKEN to a Cloudflare Tunnel token}"
: "${GHOST_HOSTNAME:?Set GHOST_HOSTNAME to the public blog hostname}"

SERVER_NAME="${SERVER_NAME:-ghost-blog}"
HCLOUD_LOCATION="${HCLOUD_LOCATION:-fsn1}"
HCLOUD_SERVER_TYPE="${HCLOUD_SERVER_TYPE:-cax11}"
HCLOUD_IMAGE="${HCLOUD_IMAGE:-ubuntu-24.04}"
FIREWALL_NAME="${FIREWALL_NAME:-ghost-tunnel-only}"

export HCLOUD_TOKEN

if hcloud server describe "$SERVER_NAME" >/dev/null 2>&1; then
  die "A Hetzner server named '$SERVER_NAME' already exists"
fi

if ! hcloud firewall describe "$FIREWALL_NAME" >/dev/null 2>&1; then
  echo "Creating inbound-deny firewall: $FIREWALL_NAME"
  hcloud firewall create --name "$FIREWALL_NAME" >/dev/null
fi

MYSQL_ROOT_PASSWORD="$(openssl rand -hex 32)"
MYSQL_PASSWORD="$(openssl rand -hex 32)"
GHOST_URL="https://${GHOST_HOSTNAME}"
CLOUD_INIT_FILE="$(mktemp)"

cleanup() {
  rm -f "$CLOUD_INIT_FILE"
}
trap cleanup EXIT

cat >"$CLOUD_INIT_FILE" <<EOF
#cloud-config
package_update: true
package_upgrade: true

bootcmd:
  - mkdir -p /opt/ghost

write_files:
  - path: /opt/ghost/.env
    permissions: "0600"
    owner: root:root
    content: |
      GHOST_URL=${GHOST_URL}
      MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      MYSQL_PASSWORD=${MYSQL_PASSWORD}
      CF_TUNNEL_TOKEN=${CF_TUNNEL_TOKEN}
  - path: /opt/ghost/docker-compose.yml
    permissions: "0644"
    owner: root:root
    content: |
      services:
        mysql:
          image: mysql:8.4
          restart: unless-stopped
          environment:
            MYSQL_ROOT_PASSWORD: \${MYSQL_ROOT_PASSWORD}
            MYSQL_DATABASE: ghost
            MYSQL_USER: ghost
            MYSQL_PASSWORD: \${MYSQL_PASSWORD}
          volumes:
            - mysql-data:/var/lib/mysql
          healthcheck:
            test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
            interval: 10s
            timeout: 5s
            retries: 10

        ghost:
          image: ghost:5-alpine
          restart: unless-stopped
          depends_on:
            mysql:
              condition: service_healthy
          environment:
            url: \${GHOST_URL}
            database__client: mysql
            database__connection__host: mysql
            database__connection__user: ghost
            database__connection__password: \${MYSQL_PASSWORD}
            database__connection__database: ghost
          volumes:
            - ghost-content:/var/lib/ghost/content
          expose:
            - "2368"

        cloudflared:
          image: cloudflare/cloudflared:latest
          restart: unless-stopped
          command: tunnel --no-autoupdate run --token \${CF_TUNNEL_TOKEN}
          depends_on:
            - ghost

      volumes:
        mysql-data:
        ghost-content:
  - path: /etc/motd
    permissions: "0644"
    owner: root:root
    content: |
      Ghost is managed by Docker Compose in /opt/ghost.
      Public SSH is intentionally disabled. Use Hetzner console for emergency access.

runcmd:
  - mkdir -p /opt/ghost
  - ufw default deny incoming
  - ufw default allow outgoing
  - ufw --force enable
  - systemctl disable --now ssh || systemctl disable --now sshd || true
  - curl -fsSL https://get.docker.com | sh
  - systemctl enable --now docker
  - cd /opt/ghost && docker compose up -d
  - echo "Ghost bootstrap finished for ${GHOST_URL}" >/var/log/ghost-bootstrap.log
EOF

echo "Creating Hetzner server: $SERVER_NAME"
hcloud server create \
  --name "$SERVER_NAME" \
  --type "$HCLOUD_SERVER_TYPE" \
  --image "$HCLOUD_IMAGE" \
  --location "$HCLOUD_LOCATION" \
  --firewall "$FIREWALL_NAME" \
  --user-data-from-file "$CLOUD_INIT_FILE" \
  --label app=ghost \
  --label access=tunnel-only

cat <<EOF

Provisioning started.

Ghost URL:
  ${GHOST_URL}

Cloudflare Tunnel requirement:
  In Cloudflare Zero Trust, the public hostname ${GHOST_HOSTNAME}
  must point to service http://ghost:2368 for the tunnel token you supplied.

Security model:
  - Hetzner firewall has no inbound allow rules.
  - SSH is disabled by cloud-init.
  - Ghost is exposed only through the outbound Cloudflare Tunnel.

Bootstrap usually takes 3-5 minutes after the server is created.
Use the Hetzner web console for emergency diagnostics; public SSH is intentionally unavailable.
EOF
