# One-Click Ghost on Hetzner With Tunnel-Only Access

This deploys Ghost to a Hetzner Cloud VPS without public SSH access. The server is provisioned with cloud-init, runs Ghost and MySQL with Docker Compose, and exposes Ghost only through an outbound Cloudflare Tunnel.

## Architecture

- Hetzner Cloud VPS running Ubuntu.
- Hetzner Cloud Firewall attached with no inbound allow rules.
- SSH disabled during cloud-init bootstrap.
- Docker Compose stack:
  - `ghost:5-alpine`
  - `mysql:8.4`
  - `cloudflare/cloudflared`
- Cloudflare Tunnel routes the public hostname to `http://ghost:2368`.

## Prerequisites

Install the Hetzner Cloud CLI:

```bash
brew install hcloud
```

Create:

- A Hetzner Cloud API token with read/write access.
- A Cloudflare Tunnel token from Cloudflare Zero Trust.
- A Cloudflare public hostname for the tunnel. Configure it to point to:

```text
http://ghost:2368
```

The `ghost` hostname works because `cloudflared` and `ghost` run in the same Docker Compose network on the VPS.

## Deploy

From the repository root:

```bash
export HCLOUD_TOKEN="your-hetzner-token"
export CF_TUNNEL_TOKEN="your-cloudflare-tunnel-token"
export GHOST_HOSTNAME="blog.example.com"

./infra/ghost/deploy-ghost-hetzner.sh
```

Optional overrides:

```bash
export SERVER_NAME="ghost-blog"
export HCLOUD_LOCATION="fsn1"
export HCLOUD_SERVER_TYPE="cax11"
export HCLOUD_IMAGE="ubuntu-24.04"
export FIREWALL_NAME="ghost-tunnel-only"
```

Bootstrap usually takes 3-5 minutes after Hetzner creates the server. Then open:

```text
https://blog.example.com/ghost
```

Ghost will show the first-run admin setup screen.

## Security Model

Public SSH is intentionally unavailable:

- The Hetzner firewall has no inbound allow rules.
- `ssh`/`sshd` is disabled by cloud-init.
- Ghost is not published on a public port.
- Cloudflare Tunnel is the only public path to the application.

For emergency diagnostics, use the Hetzner web console. On the machine, the stack lives in:

```text
/opt/ghost
```

The bootstrap marker is written to:

```text
/var/log/ghost-bootstrap.log
```

## Cleanup

Delete the server:

```bash
hcloud server delete ghost-blog
```

Delete the firewall if it is no longer used:

```bash
hcloud firewall delete ghost-tunnel-only
```

Remove or disable the Cloudflare Tunnel/public hostname in Cloudflare Zero Trust.
