# Architecture Overview

This guide explains how the stack fits together and why it's designed this way.

## The Request-to-Watch Flow

When someone requests a movie or TV show, here's what happens:

```
┌─────────────┐     ┌──────────────┐     ┌───────────┐     ┌─────────────┐     ┌──────────┐
│   Seerr     │────▶│ Sonarr/Radarr│────▶│ Prowlarr  │────▶│ qBittorrent │────▶│ Jellyfin │
│ (request)   │     │ (manage)     │     │ (indexers)│     │   SABnzbd   │     │ (watch)  │
│             │     │              │     │           │     │ (download)  │     │          │
└─────────────┘     └──────────────┘     └───────────┘     └─────────────┘     └──────────┘
      │                    │                   │                  │                  │
      │                    │                   │                  │                  │
      └────────────────────┴───────────────────┴──────────────────┘                  │
                           Through VPN (Gluetun)                              Not through VPN
```

1. **Seerr** - User requests a show or movie
2. **Sonarr/Radarr** - Searches for releases, sends to download client
3. **Prowlarr** - Provides indexers (torrent + Usenet) to Sonarr/Radarr
4. **qBittorrent** - Downloads torrents (through VPN)
5. **SABnzbd** - Downloads from Usenet (through VPN)
6. **Jellyfin** - Streams the completed files

> **Why both qBittorrent and SABnzbd?** Torrents are free but can be slow/unreliable. Usenet costs ~$5/month but is faster, more reliable, and has no ratio requirements. Most users configure both - Sonarr/Radarr will try Usenet first, fall back to torrents.

## VPN Protection

**Why VPN?** Your ISP can see BitTorrent traffic. The VPN encrypts this so they only see "encrypted traffic to VPN server".

**Why not everything through VPN?** Streaming from Jellyfin doesn't need protection (you're watching your own files) and VPN would slow it down.

```
                              ┌─────────────────────────────────────────┐
                              │            GLUETUN (VPN)                │
                              │                                         │
Internet ◄───VPN Tunnel───────│  qBit  Sonarr  Radarr  Prowlarr  Flare  │
                              │       ▲         ▲       ▲        ▲      │
                              │       │         │       │        │      │
                              │       └─────────┴───────┴────────┘      │
                              │         All share localhost             │
                              └─────────────────────────────────────────┘
                                                 │
                                    ─ ─ ─ ─ ─ ─ ─│─ ─ ─ ─ ─ ─ ─
                                                 │
                              ┌──────────────────┴──────────────────────┐
Internet ◄──Cloudflare Tunnel─│  Jellyfin    Seerr                     │
  (remote)                    │  (stream)    (requests)                 │
                              │                                         │
LAN only ◄────────────────────│  Pi-hole     Sonarr      Radarr   ...  │
  (local)                     │  (DNS)       (manage)    (manage)       │
                              └─────────────────────────────────────────┘
```

> **Note:** Download services go through VPN to hide torrent traffic from your ISP. Streaming services don't need VPN protection. Remote access uses Cloudflare Tunnel (not VPN) - see [Access Levels](#access-levels).

## Service Connections

Services inside Gluetun's network use `localhost` to talk to each other. Services outside must use the `gluetun` hostname.

```
Inside Gluetun (same network):       Outside Gluetun:
─────────────────────────────        ─────────────────
Sonarr → qBittorrent                 Seerr → Sonarr
  └── localhost:8085                   └── gluetun:8989

Radarr → qBittorrent                 Bazarr → Radarr
  └── localhost:8085                   └── gluetun:7878

Prowlarr → Sonarr
  └── localhost:8989
```

## Network Layout

All services run on the `arr-stack` network with static IPs:

```
arr-stack network (172.20.0.0/24)
────────────────────────────────────────────────────────────────────────────────────────
│ IP           │ Service            │ Port(s)              │ Compose file     │
├──────────────┼────────────────────┼──────────────────────┼──────────────────┤
│ 172.20.0.2   │ Traefik            │ 80 (macvlan) / 9090  │ traefik.yml      │
│ 172.20.0.3   │ Gluetun            │ — (VPN gateway)      │ arr-stack.yml    │
│   (via .3)   │ ↳ qBittorrent      │ 8085                 │ arr-stack.yml    │
│   (via .3)   │ ↳ Sonarr           │ 8989                 │ arr-stack.yml    │
│   (via .3)   │ ↳ Radarr           │ 7878                 │ arr-stack.yml    │
│   (via .3)   │ ↳ Prowlarr         │ 9696                 │ arr-stack.yml    │
│   (via .3)   │ ↳ Lidarr           │ 8686                 │ arr-stack.yml    │
│   (via .3)   │ ↳ slskd            │ 5030                 │ arr-stack.yml    │
│   (via .3)   │ ↳ Soularr          │ — (no UI)            │ arr-stack.yml    │
│   (via .3)   │ ↳ Chaptarr         │ 8789                 │ arr-stack.yml    │
│   (via .3)   │ ↳ FlareSolverr     │ 8191 (no UI)         │ arr-stack.yml    │
│ 172.20.0.4   │ Plex               │ 32400                │ arr-stack.yml    │
│ 172.20.0.8   │ Seerr              │ 5055                 │ arr-stack.yml    │
│ 172.20.0.9   │ Bazarr             │ 6767                 │ arr-stack.yml    │
│ 172.20.0.11  │ Agregarr           │ 7171                 │ arr-stack.yml    │
│ 172.20.0.12  │ Tautulli           │ 8181                 │ arr-stack.yml    │
│ 172.20.0.13  │ Uptime Kuma        │ 3001                 │ utilities.yml    │
│ 172.20.0.14  │ duc                │ 8838                 │ utilities.yml    │
│ 172.20.0.15  │ Beszel             │ 8090                 │ utilities.yml    │
│ 172.20.0.16  │ Whoami             │ 80                   │ traefik.yml      │
│ 172.20.0.18  │ Calibre Server     │ 8282 / 8084          │ arr-stack.yml    │
│ 172.20.0.20  │ Cloudflared        │ — (no UI)            │ cloudflared.yml  │
────────────────────────────────────────────────────────────────────────────────────────
```

> **Note:** `.5`–`.7`, `.19` are unassigned.

## Access Levels

```
┌─────────────────────────────────────────────────────────────────────────┐
│                             CORE                                         │
│                      Access via NAS_IP:port                              │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐            │
│  │ :8096     │  │ :8989     │  │ :7878     │  │ :5055     │  ...       │
│  │ Jellyfin  │  │ Sonarr    │  │ Radarr    │  │   Seerr   │            │
│  └───────────┘  └───────────┘  └───────────┘  └───────────┘            │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ + Pi-hole + Traefik
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          + LOCAL DNS                                     │
│                      Access via .lan domains                             │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐               │
│  │ jellyfin.lan  │  │ sonarr.lan    │  │ radarr.lan    │  ...          │
│  └───────────────┘  └───────────────┘  └───────────────┘               │
│                                                                          │
│  Your device → Pi-hole (DNS) → Traefik → Service                        │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ + Cloudflare Tunnel
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        + REMOTE ACCESS                                   │
│                   Access from outside your home                          │
│  ┌─────────────────────┐  ┌─────────────────────┐                       │
│  │ jellyfin.domain.com │  │ seerr.domain.com     │  ...                 │
│  └─────────────────────┘  └─────────────────────┘                       │
│                                                                          │
│  Phone → Cloudflare → Tunnel → Traefik → Service                        │
└─────────────────────────────────────────────────────────────────────────┘
```

## Design Decisions

**Static IPs:** Prevents "container not found" errors after restarts. Services always know where to find each other.

**Separate compose files:** Deploy only what you need. Core users don't need Traefik or Cloudflared.

**VPN for downloads only:** Protects privacy where it matters, doesn't slow down streaming.

**Pi-hole for DNS:** Provides internal Docker DNS and ad-blocking. Optionally enables `.lan` domains (+ local DNS).

**Named volumes:** Data persists across container updates. Easy to backup with the included script.
