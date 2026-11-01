# Docker Host Resource Limits

This directory is the version-controlled source of truth for the aggregate
resource limits applied to every Docker container on `aether`.

The host has 8 logical CPUs, 15,572,408 KiB of physical memory, and 4 GiB of
swap. The configured Docker slice provides containers with:

- at most 7.5 CPU cores in aggregate, reserving 0.5 core-equivalent for the
  host;
- a 13 GiB memory reclaim threshold;
- an absolute 14,183 MiB memory ceiling, leaving approximately 1 GiB of
  physical memory outside the Docker slice;
- at most 1 GiB of swap, preventing containers from exhausting host swap;
- lower I/O priority than the host during contention; and
- an aggregate limit of 8,192 processes and threads.

The live host paths are symlinks to the tracked files:

```text
/etc/systemd/system/docker.slice -> host-config/systemd/docker.slice
/etc/docker/daemon.json          -> host-config/docker/daemon.json
```

Docker's `cgroup-parent` setting places newly created containers in
`docker.slice`. Restarting Docker recreates the runtime tasks for the existing
containers under that parent on this host. The installer verifies every
running container after the restart and fails if any remain outside the slice.

Install the configuration, restart Docker, and verify the result with one
command from the repository root:

```bash
sudo ./scripts/install-docker-limits
```

The installer is idempotent when the expected symlinks already exist and
refuses to overwrite unrelated system configuration.

## Verification

Run the repository checker:

```bash
./scripts/check-docker-limits
```

For a direct systemd view:

```bash
systemctl status docker.slice
systemctl show docker.slice \
  -p CPUQuotaPerSecUSec \
  -p MemoryCurrent \
  -p MemoryHigh \
  -p MemoryMax \
  -p MemorySwapCurrent \
  -p MemorySwapMax \
  -p TasksCurrent \
  -p TasksMax
```

## Applying Changes

Validate both files before applying changes:

```bash
systemd-analyze verify host-config/systemd/docker.slice
sudo dockerd --validate --config-file=host-config/docker/daemon.json
```

After changing only the tracked slice limits, reload systemd. The active slice
retains its containers while systemd reapplies the resource properties:

```bash
sudo systemctl daemon-reload
```

If `daemon.json` changes, restart Docker and run the checker:

```bash
sudo systemctl restart docker
./scripts/check-docker-limits
```

Restarting Docker briefly interrupts DNS and ingress. If the checker ever
reports containers outside the slice, recreate the affected Compose lifecycle
group as the regular `luc` user so private-registry credentials are available.
Do not combine the core and main root Compose files into one command.
