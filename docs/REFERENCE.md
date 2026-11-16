# Quick Reference: URLs, Commands, Network

> ⚠️ **If you lose internet connection (+ local DNS users):** If you configured Pi-hole as your router's DNS server, stopping it (e.g., `docker compose down`) kills DNS for your entire network. To recover:
> 1. Connect to mobile hotspot (or manually set DNS to 8.8.8.8)
> 2. SSH to NAS and run: `docker compose -f docker-compose.arr-stack.yml up -d pihole`
> 3. Switch back to your normal network
>
> **Tip:** When doing full stack restarts, use mobile hotspot first, or restart with a single command:
> ```bash
> docker compose -f docker-compose.arr-stack.yml up -d  # Recreates without full down
> ```

## Service Access

| Service | Core (IP:port) | + local DNS | + remote access |
|---------|----------------|-------------|-----------------|
| Plex | `NAS_IP:32400` | `http://plex.lan` | `https://plex.DOMAIN` |
| Seerr | `NAS_IP:5055` | `http://seerr.lan` | `https://seerr.DOMAIN` |
| Sonarr | `NAS_IP:8989` | `http://sonarr.lan` | — |
| Radarr | `NAS_IP:7878` | `http://radarr.lan` | — |
| Prowlarr | `NAS_IP:9696` | `http://prowlarr.lan` | — |
| Lidarr | `NAS_IP:8686` | `http://lidarr.lan` | — |
| Bazarr | `NAS_IP:6767` | `http://bazarr.lan` | — |
| qBittorrent | `NAS_IP:8085` | `http://qbit.lan` | — |
| slskd | `NAS_IP:5030` | `http://slskd.lan` | — |
| Agregarr | `NAS_IP:7171` | `http://agregarr.lan` | — |
| Tautulli | `NAS_IP:8181` | `http://tautulli.lan` | — |
| Chaptarr | `NAS_IP:8789` | `http://chaptarr.lan` | — |
| Traefik | `NAS_IP:9090` | `http://traefik.lan` | — |
| Uptime Kuma | `NAS_IP:3001` | `http://uptime.lan` | — |
| duc | `NAS_IP:8838` | `http://duc.lan` | — |
| Beszel | `NAS_IP:8090` | `http://beszel.lan` | — |


**Legend:**
- **Core** — Always works on your LAN
- **+ local DNS** — Requires [Traefik setup](LOCAL-DNS.md)
- **+ remote access** — Requires [Cloudflare Tunnel setup](REMOTE-ACCESS.md). Services marked "—" are LAN-only (not exposed to internet).

## Services & Network

**Core** (`docker-compose.arr-stack.yml`):

| Service | IP | Port | Notes |
|---------|-----|------|-------|
| **Gluetun** | **172.20.0.3** | — | VPN gateway |
| ↳ qBittorrent | (via Gluetun) | 8085 | Torrent client |
| ↳ Sonarr | (via Gluetun) | 8989 | TV management |
| ↳ Radarr | (via Gluetun) | 7878 | Movie management |
| ↳ Prowlarr | (via Gluetun) | 9696 | Indexer manager |
| ↳ Lidarr | (via Gluetun) | 8686 | Music management |
| ↳ slskd | (via Gluetun) | 5030 | Soulseek client |
| ↳ Soularr | (via Gluetun) | — | Lidarr/slskd bridge (no UI) |
| ↳ Chaptarr | (via Gluetun) | 8789 | Ebook/audiobook manager |
| ↳ FlareSolverr | (via Gluetun) | 8191 | Cloudflare bypass (no UI) |
| Plex | 172.20.0.4 | 32400 | Media server |
| Seerr | 172.20.0.8 | 5055 | Request management |
| Bazarr | 172.20.0.9 | 6767 | Subtitles |
| Agregarr | 172.20.0.11 | 7171 | Media management |
| Tautulli | 172.20.0.12 | 8181 | Plex stats & monitoring |

**+ local DNS** (`docker-compose.traefik.yml`):

| Service | IP | Port | Notes |
|---------|-----|------|-------|
| Traefik | 172.20.0.2 | 80 (macvlan) / 9090 (dashboard) | Reverse proxy |
| Whoami | 172.20.0.16 | 80 | Diagnostic test endpoint |

**+ remote access** (`docker-compose.cloudflared.yml`):

| Service | IP | Port | Notes |
|---------|-----|------|-------|
| Cloudflared | 172.20.0.20 | — | Cloudflare Tunnel (no UI) |

**Optional** (`docker-compose.utilities.yml`):

| Service | IP | Port | Notes |
|---------|-----|------|-------|
| deunhealth | — | — | Auto-restart on VPN failure (no UI) |
| Uptime Kuma | 172.20.0.13 | 3001 | Service monitoring |
| duc | 172.20.0.14 | 8838 | Disk usage analyzer |
| Beszel | 172.20.0.15 | 8090 | System monitoring |
| beszel-agent | host network | 45876 | Beszel metrics collector (no UI) |

### Service Connection Guide

**VPN-protected services** share Gluetun's network via `network_mode: service:gluetun`. This means:

| From | To | Use | Why |
|------|-----|-----|-----|
| Sonarr | qBittorrent | `localhost:8085` | Same network stack |
| Radarr | qBittorrent | `localhost:8085` | Same network stack |
| Prowlarr | Sonarr | `localhost:8989` | Same network stack |
| Prowlarr | Radarr | `localhost:7878` | Same network stack |
| Prowlarr | Lidarr | `localhost:8686` | Same network stack |
| Prowlarr | Chaptarr | `localhost:8789` | Same network stack (add as Readarr-type) |
| Prowlarr | FlareSolverr | `localhost:8191` | Same network stack |
| Lidarr | slskd | `localhost:5030` | Same network stack |
| Seerr | Sonarr | `gluetun:8989` | Must go through gluetun |
| Seerr | Radarr | `gluetun:7878` | Must go through gluetun |
| Seerr | Plex | `172.20.0.4:32400` | Both have own IPs |
| Bazarr | Sonarr | `gluetun:8989` | Must go through gluetun |
| Bazarr | Radarr | `gluetun:7878` | Must go through gluetun |

> **Why `gluetun` not `sonarr`?** Services sharing gluetun's network don't get their own Docker DNS entries. Seerr/Bazarr must use `gluetun` hostname (or `172.20.0.3`) to reach them.

## Common Commands

```bash
# All commands below run on your NAS via SSH

# View all containers
docker ps

# View logs
docker logs -f <container_name>

# Restart single service
docker compose -f docker-compose.arr-stack.yml restart <service_name>

# Restart entire stack (safe - Pi-hole restarts immediately)
docker compose -f docker-compose.arr-stack.yml up -d --force-recreate

# Pull repo updates then redeploy
git pull origin main
docker compose -f docker-compose.arr-stack.yml up -d --force-recreate

# Update container images
docker compose -f docker-compose.arr-stack.yml pull
docker compose -f docker-compose.arr-stack.yml up -d
```

> ⚠️ **Never use `docker compose down` (+ local DNS users)** - if your router uses Pi-hole for DNS, stopping it kills DNS for your entire network. Use `up -d --force-recreate` instead.

## Networks

| Network | Subnet | Purpose |
|---------|--------|---------|
| arr-stack | 172.20.0.0/24 | Service communication |
| vpn-net | 10.8.1.0/24 | Internal VPN routing (WireGuard peers) |
| traefik-lan | (your LAN)/24 | macvlan for .lan domains (+ local DNS only) |

> **Note:** `docker compose up` shows these as `arr-stack`, `arr-stack_vpn-net`, and `arr-stack_traefik-lan`. The `arr-stack_` prefix is normal — Docker adds the project name to networks that don't have an explicit `name:` set.

## Startup Order

Services start in dependency order (handled automatically by `depends_on`):

1. **Pi-hole** → DNS ready (for containers; optionally your LAN)
2. **Gluetun** → VPN connected (uses Pi-hole for internal DNS)
3. **Sonarr, Radarr, Prowlarr, qBittorrent, SABnzbd** → VPN-protected services
4. **Seerr, Bazarr** → Connect to Sonarr/Radarr via Gluetun
5. **FlareSolverr** → Cloudflare bypass (via Gluetun, shares VPN with Prowlarr)
6. **Jellyfin, WireGuard** → Independent, start anytime

## Compose Files

### `docker-compose.arr-stack.yml` (Core)

| Service | Description |
|---------|-------------|
| Gluetun | VPN gateway |
| Plex | Media streaming |
| Seerr | Request system |
| Sonarr | TV management |
| Radarr | Movie management |
| Prowlarr | Indexer manager |
| Lidarr | Music management |
| qBittorrent | Torrent client |
| slskd | Soulseek client |
| Soularr | Lidarr/slskd bridge |
| Bazarr | Subtitles |
| Agregarr | Media management |
| Tautulli | Plex stats |
| FlareSolverr | Cloudflare bypass |
| Chaptarr | Ebook/audiobook manager |

### `docker-compose.traefik.yml` (+ local DNS)

| Service | Description |
|---------|-------------|
| Traefik | Reverse proxy for .lan domains |
| Whoami | Diagnostic test endpoint |

### `docker-compose.cloudflared.yml` (+ remote access)

| Service | Description |
|---------|-------------|
| Cloudflared | Tunnel to Cloudflare for external access |

### `docker-compose.utilities.yml` (Optional)

| Service | Description |
|---------|-------------|
| deunhealth | Auto-restart on VPN reconnect |
| Uptime Kuma | Service uptime monitoring |
| duc | Disk usage treemap |
| Beszel | System metrics (CPU, RAM, disk, containers) |
| beszel-agent | Metrics collector for Beszel |
