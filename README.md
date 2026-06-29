# Homelab Docker Stack

This repository contains the Docker Compose configuration for my homelab. The main entry point is `docker-compose.main.yaml`, which defines shared networks and secrets, then includes individual service stacks from `active/`.

The stack is built around Traefik, Cloudflare DNS, OAuth forward auth, and per-application Compose files. Most web services attach to the shared `t3_proxy` network and are exposed through Traefik using hosts under `$DOMAINNAME`.

## Repository Layout

| Path | Purpose |
| --- | --- |
| `docker-compose.main.yaml` | Main Compose file. Defines global networks, secrets, and the included active stacks. |
| `active/` | Service stack fragments. Each file usually owns one app, plus any app-specific database, cache, or worker containers. |
| `inactive/` | Disabled or parked stack fragments. These are not launched by the main Compose file. |
| `.env.example` | Template for required environment variables. |
| `homelab-configs/` | Local configuration material for deployed services. |

## Core Architecture

- **Reverse proxy:** Traefik 3 terminates HTTPS on ports `80` and `443`, routes by hostname, and uses the Docker provider plus file-provider rules from `$DOCKERDIR/appdata/traefik3/rules`.
- **TLS:** Traefik uses the Cloudflare DNS challenge for Let's Encrypt wildcard certificates.
- **Authentication:** Most private services use `chain-oauth@file`, backed by `traefik-forward-auth` and Google OAuth. Some public or invite flows intentionally use `chain-no-auth@file`.
- **Docker API access:** Traefik, Portainer, Gatus, Watchtower, and other tooling use the `socket_proxy` network where possible.
- **Persistence:** App configuration normally lives in `$DOCKERDIR/appdata/...`; larger media and data libraries live under `$DATADIR` or `$INTERNALDIR`.

## Shared Networks

| Network | Subnet | Purpose |
| --- | --- | --- |
| `t3_proxy` | `192.168.90.0/24` | Shared reverse-proxy network for Traefik-routed services. |
| `socket_proxy` | `192.168.91.0/24` | Isolated Docker socket proxy network. |
| `default` | Docker bridge | Default network for services that do not need proxy access. |

Several stacks also define private per-app bridge networks, such as `airtrail_network`, `immich_network`, `dawarich_network`, `tubesync_network`, and `aveon-network`.

## Required Configuration

Create a local `.env` from `.env.example` and fill in the host paths, identity values, domain settings, and provider credentials.

Important variables include:

- `PUID`, `PGID`, `TZ`
- `USERDIR`, `DOCKERDIR`, `DATADIR`, `INTERNALDIR`, `SECRETSDIR`
- `DOMAINNAME`, `HOSTURL`
- `CLOUDFLARE_EMAIL`, `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ZONEID`, `CLOUDFLARE_IPS`
- `LOCAL_IPS`, `SERVER_IP`
- `TRAEFIK_AUTH_BYPASS_KEY`
- App-specific variables for Immich, AirTrail, Aveon, Time Machine, and other stacks that reference `${...}` values.

Secrets are read from `$SECRETSDIR` by `docker-compose.main.yaml`, including:

- `basic_auth_credentials`
- `cf_dns_api_token`
- `traefik_forward_auth`
- `shoutrrr_telegram_secret`
- Authelia and Guacamole secrets retained for inactive or optional stacks

## Common Commands

Validate the complete Compose model:

```bash
docker compose -f docker-compose.main.yaml config
```

Start or update the included stacks:

```bash
docker compose -f docker-compose.main.yaml up -d
```

Pull current images for included stacks:

```bash
docker compose -f docker-compose.main.yaml pull
```

Stop the included stacks:

```bash
docker compose -f docker-compose.main.yaml down
```

View logs for one service:

```bash
docker compose -f docker-compose.main.yaml logs -f traefik
```

## Currently Included Stacks

These files are included by `docker-compose.main.yaml` as of this README update:

| Stack | Main service(s) | Purpose | Traefik hosts |
| --- | --- | --- | --- |
| `actual-server.yaml` | Actual Budget | Personal budgeting | `actual-server.$DOMAINNAME`, `as.$DOMAINNAME` |
| `adguard.yaml` | AdGuard Home | DNS sinkhole and filtering | Direct ports `3000`, `53/tcp`, `53/udp` |
| `airtrail.yaml` | AirTrail, Postgres | Travel history and flight tracking | `airtrail.$DOMAINNAME` |
| `anythingllm.yaml` | AnythingLLM | Local LLM workspace | `llm.$DOMAINNAME` |
| `audio-book-request.yaml` | Audiobook Request | Audiobook requests | `audiobookrequest.$DOMAINNAME` |
| `aveon.yaml` | Aveon, Postgres, Redis | Custom flight search app | `aveon.$DOMAINNAME` |
| `bazarr.yaml` | Bazarr | Subtitle management | `bazarr.$DOMAINNAME` |
| `calibre.yaml` | Calibre | Ebook library management | `calibre.$DOMAINNAME`, `c.$DOMAINNAME` |
| `changedetectionio.yaml` | changedetection.io, sockpuppetbrowser | Website change monitoring | `changedetection.$DOMAINNAME`, `cd.$DOMAINNAME` |
| `cyberchef.yaml` | CyberChef | Data transformation toolbox | `cyberchef.$DOMAINNAME` |
| `dawarich.yaml` | Dawarich, PostGIS, Redis, Sidekiq | Location timeline | `dawarich.$DOMAINNAME` |
| `ddclient.yaml` | ddclient | Dynamic DNS updater | None |
| `discovarr.yaml` | Discovarr | Media discovery automation | `discovarr.$DOMAINNAME` |
| `facil-map.yaml` | FacilMap, PostGIS | Collaborative maps | `facilmap.$DOMAINNAME` |
| `flaresolverr.yaml` | FlareSolverr | Cloudflare challenge solver for indexers | Direct port only |
| `gatus.yaml` | Gatus | Status page and monitoring | `gatus.$DOMAINNAME`, `status.$DOMAINNAME` |
| `home-assistant.yaml` | Home Assistant | Home automation | Host networking |
| `huntarr.yaml` | Huntarr | Arr queue and media automation helper | `huntarr.$DOMAINNAME` |
| `immich.yaml` | Immich, ML, Valkey, Postgres | Photo and video backup | `immich.$DOMAINNAME` |
| `it-tools.yaml` | IT Tools | Browser-based utilities | `tools.$DOMAINNAME` |
| `jellyfin.yaml` | Jellyfin | Media server | `jellyfin.$DOMAINNAME` |
| `kavita.yaml` | Kavita | Reading server | `kavita.$DOMAINNAME` |
| `kitchen-owl.yaml` | KitchenOwl frontend/backend | Groceries and meal planning | `kitchenowl.$DOMAINNAME`, `kitchenowlbackend.$DOMAINNAME` |
| `lazylibrarian.yaml` | LazyLibrarian | Book/audiobook automation | `lazylibrarian.$DOMAINNAME`, `ll.$DOMAINNAME` |
| `lucurlings.nl.yaml` | Personal website | Root website | `$DOMAINNAME` |
| `mqtt.yaml` | Mosquitto | MQTT broker | Direct MQTT ports |
| `n8n.yaml` | n8n | Workflow automation | `n8n.$DOMAINNAME` |
| `nextcloud.yaml` | Nextcloud, MariaDB, Redis, cron, backup | File sync and collaboration | `nextcloud.$DOMAINNAME` |
| `oauth.yaml` | traefik-forward-auth | Google OAuth middleware backend | `oauth.$DOMAINNAME` |
| `ollama.yaml` | Ollama | Local model runtime | `ollama.$DOMAINNAME`, direct port `11434` |
| `open-webui.yaml` | Open WebUI | Chat UI for Ollama | `open-webui.$DOMAINNAME` |
| `portainer.yaml` | Portainer EE | Docker management UI | `portainer.$DOMAINNAME`, direct port `9443` |
| `prowlarr.yaml` | Prowlarr | Indexer management | `prowlarr.$DOMAINNAME` |
| `radarr.yaml` | Radarr | Movie automation | `radarr.$DOMAINNAME` |
| `ruview.yaml` | Ruvnet WiFi DensePose | WiFi sensing experiment | `ruvnet.$DOMAINNAME` |
| `sabnzbd.yaml` | SABnzbd | Usenet downloader | `sabnzbd.$DOMAINNAME`, direct port `8084` |
| `seerr.yaml` | Seerr/Jellyseerr | Media requests | `jellyseerr.$DOMAINNAME`, `seerr.$DOMAINNAME` |
| `socket-proxy.yaml` | Docker Socket Proxy | Restricted Docker API access | Direct port `2375` |
| `sonarr.yaml` | Sonarr | TV automation | `sonarr.$DOMAINNAME` |
| `timemachine.yaml` | Time Machine | macOS network backups | Host networking |
| `traefik.yaml` | Traefik | Reverse proxy and TLS | `traefik.$DOMAINNAME` |
| `tubesync.yaml` | TubeSync, Postgres | YouTube archive/download manager | `tubesync.$DOMAINNAME` |
| `watchtower.yaml` | Watchtower | Automated image updates | Direct port `8086` for metrics/API |
| `whoami.yaml` | Traefik Whoami | Routing test endpoint | `whoami.$DOMAINNAME` |
| `wizarr.yaml` | Wizarr | Media onboarding and invites | `wizarr.$DOMAINNAME` |

## Active Files Not Included By Main Compose

These files exist under `active/`, but are currently not launched by `docker-compose.main.yaml` because their include lines are commented out or absent:

| Stack | Purpose | Notes |
| --- | --- | --- |
| `deluge.yaml` | Torrent client | Uses `network_mode: service:gluetun`. |
| `gluetun.yaml` | VPN network container | Exposes Deluge through Traefik when enabled. |
| `qbittorrent.yaml` | Torrent client | Uses `network_mode: service:gluetun`; not referenced by main compose. |
| `readarr.yaml` | Book automation | File exists, include line is commented out. |

## Service Patterns

Most application stacks follow the same conventions:

- `restart: unless-stopped` for long-running applications.
- LinuxServer.io containers use `PUID`, `PGID`, and `TZ`.
- Traefik labels set `entrypoints=websecure`, a hostname rule, an optional middleware chain, and an internal service port.
- Public or semi-public flows such as Gatus status and Wizarr invites use `chain-no-auth@file`.
- Arr apps and SABnzbd define a higher-priority auth-bypass router using `traefik-auth-bypass-key` for trusted automation clients.

## Operational Notes

- Traefik depends on the socket proxy at `tcp://socket-proxy:2375`.
- The Docker socket proxy publishes `2375`; keep that reachable only on trusted networks.
- Watchtower is configured to run daily at `04:00`, clean up old images, revive stopped containers, and send notifications through the `shoutrrr_telegram_secret` secret.
- Home Assistant and Time Machine use host networking because they need LAN discovery or native network behavior.
- Immich uses hardware devices under `/dev/dri` and a render group id of `993`; verify this matches the host.
- Some stacks intentionally expose direct host ports in addition to Traefik routes for LAN or API use.

## Adding Or Enabling A Stack

1. Add or edit a stack file under `active/`.
2. Attach web apps to `t3_proxy` and add Traefik labels when they need HTTPS routing.
3. Add private bridge networks inside the app file when databases, caches, or workers should not be globally reachable.
4. Add required environment variables to `.env.example`.
5. Add the stack path to the `include:` list in `docker-compose.main.yaml`.
6. Run `docker compose -f docker-compose.main.yaml config` before starting the stack.

## Security Checklist

- Keep `.env`, app-specific env files, and `$SECRETSDIR` out of git.
- Do not expose `socket-proxy:2375` to the internet.
- Use Cloudflare DNS API tokens with the smallest practical scope.
- Review services that use `chain-no-auth@file` before publishing DNS records.
- Check direct host ports whenever adding a new stack.
