# Homelab Docker Stack

## Run It Now

Run these commands from the deployment host. They validate, pull, and start the always-on core first, then the restartable application stack:

```bash
cd /home/luc/docker/homelab

docker compose --project-name homelab --env-file homelab-configs/.env -f docker-compose.core.yaml config --quiet
docker compose --project-name homelab --env-file homelab-configs/.env -f docker-compose.core.yaml pull
docker compose --project-name homelab --env-file homelab-configs/.env -f docker-compose.core.yaml up -d

docker compose --project-name homelab --env-file homelab-configs/.env -f docker-compose.main.yaml config --quiet
docker compose --project-name homelab --env-file homelab-configs/.env -f docker-compose.main.yaml pull
docker compose --project-name homelab --env-file homelab-configs/.env -f docker-compose.main.yaml up -d
```

For an ordinary restart of application workloads without touching core infrastructure:

```bash
docker compose --project-name homelab --env-file homelab-configs/.env -f docker-compose.main.yaml restart
```

Use `up -d` instead of `restart` after changing Compose configuration. Do not combine the two root files into one Compose command; they are intentionally separate lifecycle boundaries.

## Architecture

The deployment has two root Compose models:

- `docker-compose.core.yaml` owns always-on infrastructure, shared networks, and file-backed secrets.

- `docker-compose.main.yaml` owns application workloads that can be restarted without interrupting DNS, ingress, authentication, monitoring, or Docker management.

Both use the Compose project name `homelab`. Service definitions live in `active/` and are pulled into a root model with Compose `include` entries.

### Core stack

| File | Service | Purpose | Access |
| --- | --- | --- | --- |
| `socket-proxy.yaml` | Docker Socket Proxy | Restricted Docker API for Traefik and Portainer | Host port `2375` |
| `traefik.yaml` | Traefik | HTTPS ingress, TLS, dashboard, and Minecraft TCP routing | Ports `80`, `443`, `25565`; `traefik.$DOMAINNAME` |
| `oauth.yaml` | Traefik Forward Auth | Google OAuth middleware backend | `oauth.$DOMAINNAME` |
| `adguard.yaml` | AdGuard Home | LAN DNS filtering | Ports `53/tcp`, `53/udp`, `3000` |
| `ddclient.yaml` | ddclient | Dynamic DNS updates | No UI |
| `gatus.yaml` | Gatus | Availability monitoring and status page | `gatus.$DOMAINNAME`, `status.$DOMAINNAME` |
| `portainer.yaml` | Portainer EE | Docker management | Port `9000`; `portainer.$DOMAINNAME` |
| `watchtower.yaml` | Watchtower | Automated container image updates | Port `8086` |
| `rclone.yaml` | rclone | One-way configuration backup to Google Drive | No UI |

### Main stack

| File | Main service(s) | Purpose | Access |
| --- | --- | --- | --- |
| `timemachine.yaml` | Time Machine | macOS network backups | Host networking |
| `wizarr.yaml` | Wizarr | Media-server onboarding and invitations | `wizarr.$DOMAINNAME` |
| `lazylibrarian.yaml` | LazyLibrarian | Book and audiobook automation | `lazylibrarian.$DOMAINNAME`, `ll.$DOMAINNAME` |
| `umami.yaml` | Umami, PostgreSQL | Web analytics | `umami.$DOMAINNAME` |
| `bugsink.yaml` | Bugsink, PostgreSQL | Error tracking | `bugsink.$DOMAINNAME` |
| `lucurlings.nl.yaml` | Personal website | Public website | `$DOMAINNAME` |
| `atlas.yaml` | Atlas frontend and backend | Expeditions Through Time application | `atlas.$DOMAINNAME` |
| `watch-watchtower.yaml` | Web, workers, scheduler, PostgreSQL, RabbitMQ, MinIO, FlareSolverr | Watch marketplace monitoring application | `watch.$DOMAINNAME`, `watch-minio.$DOMAINNAME`, `watch-rabbitmq.$DOMAINNAME` |
| `agent-devstation.yaml` | Devstation, Docker-in-Docker, pruner, disk health | Browser-based development environment | `agent-devstation.$DOMAINNAME` |
| `minecraft.yaml` | Minecraft server | Game server | TCP port `25565` through Traefik |
| `aveon.yaml` | Aveon, PostgreSQL, Redis | Flight search application | `aveon.$DOMAINNAME` |
| `sonarr.yaml` | Sonarr | TV automation | Port `8989`; `sonarr.$DOMAINNAME` |
| `radarr.yaml` | Radarr | Movie automation | Port `7878`; `radarr.$DOMAINNAME` |
| `prowlarr.yaml` | Prowlarr | Indexer management | Port `9696`; `prowlarr.$DOMAINNAME` |
| `jellyfin.yaml` | Jellyfin | Media server | Port `8096`; `jellyfin.$DOMAINNAME` |
| `seerr.yaml` | Seerr | Media requests | `jellyseerr.$DOMAINNAME`, `seerr.$DOMAINNAME` |
| `whoami.yaml` | Traefik Whoami | Routing test endpoint | `whoami.$DOMAINNAME` |
| `sabnzbd.yaml` | SABnzbd | Usenet downloader | Port `8084`; `sabnzbd.$DOMAINNAME` |

## Networks

| Network | Owner | Subnet | Purpose |
| --- | --- | --- | --- |
| `t3_proxy` | Core | `192.168.90.0/24` | Shared network for Traefik-routed services |
| `socket_proxy` | Core | `192.168.91.0/24` | Restricted Docker API network |
| `homelab_core_default` | Core | Docker-assigned | Default network for core-only services |
| `homelab_main_default` | Main | Docker-assigned | Default network for main-only services |

The main model declares `t3_proxy` and `socket_proxy` as external, so core must be started first. Application-specific networks remain in their individual service files.

## Configuration and Secrets

The deployed environment file is `homelab-configs/.env`; `.env.example` is the repository template. Important shared settings include:

- Host identity and paths: `PUID`, `PGID`, `TZ`, `USERDIR`, `DOCKERDIR`, `DATADIR`, `INTERNALDIR`, `SECRETSDIR`.

- Routing: `DOMAINNAME`, `CLOUDFLARE_IPS`, `LOCAL_IPS`, and `TRAEFIK_AUTH_BYPASS_KEY`.

- Service-specific credentials and settings for Time Machine, Aveon, Bugsink, Umami, Watch Watchtower, Agent Devstation, and rclone.

The core model declares these files from `$SECRETSDIR`:

| Secret | Current use |
| --- | --- |
| `basic_auth_credentials` | Traefik basic-auth middleware data |
| `cf_dns_api_token` | Traefik Cloudflare DNS challenge |
| `traefik_forward_auth` | OAuth provider configuration |
| `shoutrrr_telegram_secret` | Watchtower notifications |
| `mysql_root_password` | Reserved for optional stacks |
| `authelia_jwt_secret` | Reserved for Authelia |
| `authelia_session_secret` | Reserved for Authelia |
| `authelia_storage_encryption_key` | Reserved for Authelia |
| `guac_db_name` | Reserved for Guacamole |
| `guac_mysql_user` | Reserved for Guacamole |
| `guac_mysql_password` | Reserved for Guacamole |

Keep the environment file, app-specific environment files, and `$SECRETSDIR` out of version control.

## Operations

Show current status:

```bash
docker compose --project-name homelab --env-file homelab-configs/.env -f docker-compose.core.yaml ps
docker compose --project-name homelab --env-file homelab-configs/.env -f docker-compose.main.yaml ps
```

Apply configuration or image changes to main without stopping core:

```bash
docker compose --project-name homelab --env-file homelab-configs/.env -f docker-compose.main.yaml pull
docker compose --project-name homelab --env-file homelab-configs/.env -f docker-compose.main.yaml up -d
```

Stop and recreate all main workloads:

```bash
docker compose --project-name homelab --env-file homelab-configs/.env -f docker-compose.main.yaml down
docker compose --project-name homelab --env-file homelab-configs/.env -f docker-compose.main.yaml up -d
```

View logs for one service using the root model that owns it:

```bash
docker compose --project-name homelab --env-file homelab-configs/.env -f docker-compose.core.yaml logs -f traefik
docker compose --project-name homelab --env-file homelab-configs/.env -f docker-compose.main.yaml logs -f jellyfin
```

Validate after editing:

```bash
docker compose --project-name homelab --env-file homelab-configs/.env -f docker-compose.core.yaml config --quiet
docker compose --project-name homelab --env-file homelab-configs/.env -f docker-compose.main.yaml config --quiet
```

## Rclone Google Drive Sync

The included `rclone` service mirrors `$DOCKERDIR` to the configured Google Drive remote. It runs once at startup and then every `RCLONE_SYNC_INTERVAL_SECONDS` seconds. Deletions are mirrored to the destination, and the local source is mounted read-only.

Create and verify the remote interactively before the first normal deployment:

```bash
docker compose --project-name homelab --env-file homelab-configs/.env -f docker-compose.main.yaml run --rm --no-deps --entrypoint rclone rclone config
docker compose --project-name homelab --env-file homelab-configs/.env -f docker-compose.main.yaml run --rm --no-deps --entrypoint rclone rclone lsd google-drive:
```

The defaults are remote name `google-drive`, destination `homelab-configs`, and a sync interval of 86400 seconds.

## Automatic Deployment

`.github/workflows/deploy.yml` runs on the self-hosted runner labelled `homelab`. On every push to `main`, it fast-forwards `/home/luc/docker/homelab`, pulls and validates both models, then deploys core before main.

Manual workflow runs support:

- `all` for core followed by main.

- `core` or `main` for one complete lifecycle group.

- An individual file from `active/`; the workflow automatically selects the matching core or main base model.

All deployments use the `homelab` project name and `homelab-configs/.env`.

## Inactive Stacks

Only Compose files included by a root model are kept under `active/`. Disabled definitions live under `inactive/` and are not offered by the deployment workflow.

The following stacks were moved from `active/` to `inactive/` during the core/main cleanup:

- `actual-server.yaml`, `airtrail.yaml`, `anythingllm.yaml`, `audio-book-request.yaml`

- `bazarr.yaml`, `calibre.yaml`, `changedetectionio.yaml`, `conaigh.yaml`, `cyberchef.yaml`

- `dawarich.yaml`, `deluge.yaml`, `discovarr.yaml`, `facil-map.yaml`, `flaresolverr.yaml`, `gluetun.yaml`

- `hermes-dev/compose.yml`, `home-assistant.yaml`, `immich.yaml`, `it-tools.yaml`

- `kavita.yaml`, `kitchen-owl.yaml`, `minio.yaml`, `mqtt.yaml`, `n8n.yaml`, `nextcloud.yaml`

- `ollama.yaml`, `open-webui.yaml`, `qbittorrent.yaml`, `readarr.yaml`, `ruview.yaml`, `tubesync.yaml`

The `inactive/` directory also contains older parked and experimental definitions that were already disabled. `deluge.yaml` and `qbittorrent.yaml` require `gluetun.yaml` because they use `network_mode: service:gluetun`.

## Repository Layout

| Path | Purpose |
| --- | --- |
| `docker-compose.core.yaml` | Always-on infrastructure, shared network ownership, and secrets |
| `docker-compose.main.yaml` | Restartable application workloads |
| `active/` | Enabled service fragments included by core or main |
| `inactive/` | Disabled, parked, or experimental service definitions |
| `.env.example` | Environment template |
| `homelab-configs/` | Deployed environment, secrets, and application configuration |

## Adding or Enabling a Stack

1. Add a new Compose file under `active/`, or move an existing definition there from `inactive/`.
2. Attach routed web services to `t3_proxy` and add Traefik labels.
3. Use a private application network for databases, caches, and workers.
4. Add required settings to `.env.example` and the deployed environment file.
5. Add infrastructure to `docker-compose.core.yaml`; add ordinary workloads to `docker-compose.main.yaml`.
6. Validate the owning root model with `docker compose ... config --quiet`.
7. Apply it with `docker compose ... up -d`.

## Security Notes

- Socket Proxy publishes port `2375`; restrict it at the host and network perimeter.

- Watchtower mounts `/var/run/docker.sock` directly and can update or restart any container.

- Use a narrowly scoped Cloudflare DNS token for certificate issuance.

- Review every route using `chain-no-auth@file` before publishing its DNS record.

- Review host port bindings when enabling a stack; several services intentionally expose both a direct LAN port and a Traefik route.
