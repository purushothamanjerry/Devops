# Redis Cluster Lifecycle Tool

A CLI tool that wraps Ansible to provision, operate, and perform a rolling upgrade of a Redis Cluster with zero downtime and verified data integrity.

## Prerequisites

- **Container Runtime**: Docker Engine or Podman (Podman preferred — fully open source, Apache 2.0)
- **Ansible 2.14+**: `ansible-playbook` must be available
- **Python 3.x**: For the CLI tool
- **SSH key pair**: Generated automatically by `setup.sh`

> The tool automatically checks for prerequisites on every command and will tell you exactly what to install if anything is missing.

### Install Podman (recommended)
See https://podman.io/docs/installation

### Install Docker (alternative)
See https://docs.docker.com/engine/install/

### Install Ansible 2.14+
```bash
pip install --upgrade ansible
```

## Quick Start

### Step 1 — Run setup script

```bash
chmod +x setup.sh redis-tool
./setup.sh
```

This will:
- Generate SSH key if needed
- Copy public key into `infra/`
- Detect your container runtime (podman-compose → podman compose → docker compose → docker-compose)
- Build images and start all 6 containers
- Verify SSH access works to every node

### Step 2 — Run commands

```bash
./redis-tool provision --version 7.0.15 --masters 3 --replicas-per-master 1
./redis-tool status
./redis-tool data seed --keys 1000
./redis-tool data verify
./redis-tool upgrade --target-version 7.2.6 --strategy rolling
./redis-tool verify --full
```

## Infrastructure

6 Ubuntu 22.04 containers simulating real servers with SSH access:

| Container    | IP          | SSH Port |
|--------------|-------------|----------|
| redis-node-1 | 10.10.0.11  | 2221     |
| redis-node-2 | 10.10.0.12  | 2222     |
| redis-node-3 | 10.10.0.13  | 2223     |
| redis-node-4 | 10.10.0.14  | 2224     |
| redis-node-5 | 10.10.0.15  | 2225     |
| redis-node-6 | 10.10.0.16  | 2226     |

Containers use a static subnet (`10.10.0.0/24`) so Ansible inventory has fixed IPs. SSH key-based authentication — no passwords.

## Manual Setup (if setup.sh fails)

```bash
# Generate SSH key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""

# Copy public key
cp ~/.ssh/id_rsa.pub infra/authorized_keys

# Start containers (Podman 4.x+)
cd infra && podman compose up -d --build

# OR start containers (Docker)
cd infra && docker compose up -d --build
```

## Rolling Upgrade Strategy

The upgrade achieves **zero client-visible downtime** — at no point are all copies of a hash-slot partition unavailable simultaneously.

1. **Pre-flight checks** — verify cluster is healthy (`cluster_state:ok`), all 6 nodes reachable, current version differs from target, pre-upgrade data integrity baseline
2. **Upgrade replicas first** (one at a time) — zero risk since replicas don't serve writes; each replica is stopped, upgraded, restarted, and verified to rejoin and sync before moving to the next
3. **Upgrade masters with CLUSTER FAILOVER** — for each master, its (already-upgraded) replica is promoted to master via `CLUSTER FAILOVER`, then the old master is stopped, upgraded, and rejoins as a replica; cluster state verified after each
4. **Post-upgrade verification** — data integrity check (all 1000 keys) + version confirmation across all 6 nodes

Progress is printed after each node: `[X/6] Upgraded <role> <hostname> (<ip>) — cluster: ok`

## Idempotency

- `provision` checks the installed Redis version before compiling. If the target version is already installed, it skips download, compile, and data wipe — only reapplying config and restarting Redis. Cluster formation is skipped if the cluster already exists.
- `upgrade` checks each node's version before upgrading. Nodes already at the target version are skipped. Running upgrade when all nodes are at the target version exits with a clear message.

## Assumptions and Trade-offs

- Redis compiled from source for exact version control (no package manager version pinning needed)
- Containers use port mapping (2221–2226) for SSH access from the host
- `cluster-announce-ip` is set per node to ensure correct IP advertisement within the container network
- No systemd in containers — Redis started via `nohup` (systemd unit file is present in the role but unused in this environment)
- Data is only cleared on provision when the version changes
- Data seeding uses deterministic SHA256 hashes (`key:XXXX` → `sha256(key:XXXX)`) for reproducible verification

## Known Limitations

- Initial provision takes 5–10 min per node (compiles Redis from source in parallel across all 6 nodes)
- Containers lose Redis state on restart — re-run `provision` to restore
- WSL users: use `localhost` ports (2221–2226), not container IPs, for direct SSH
- The tool supports both Docker and Podman but was primarily tested with Podman
