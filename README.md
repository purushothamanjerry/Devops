# Redis Cluster Lifecycle Tool

A CLI tool that wraps Ansible to provision, operate, and perform a rolling upgrade of a Redis Cluster with zero downtime and verified data integrity.

## Prerequisites

- Docker Engine or Podman (Podman preferred)
- Ansible 2.10+
- Python 3.x
- SSH key pair at ~/.ssh/id_rsa

## Infrastructure Setup

### 1. Build and start containers

```bash
cd infra/
docker compose up -d --build
# or
podman-compose up -d --build
```

This starts 6 Ubuntu 22.04 containers simulating real servers:

| Container | IP | Port |
|---|---|---|
| redis-node-1 | 10.10.0.11 | 2221 |
| redis-node-2 | 10.10.0.12 | 2222 |
| redis-node-3 | 10.10.0.13 | 2223 |
| redis-node-4 | 10.10.0.14 | 2224 |
| redis-node-5 | 10.10.0.15 | 2225 |
| redis-node-6 | 10.10.0.16 | 2226 |

### 2. Verify SSH access

```bash
ssh -i ~/.ssh/id_rsa -p 2221 root@localhost "hostname"
```

## Usage

All commands run from the submission/ directory:

### Provision Redis Cluster

```bash
./redis-tool provision --version 7.0.15 --masters 3 --replicas-per-master 1
```

### Check Cluster Status

```bash
./redis-tool status
```

### Seed Data

```bash
./redis-tool data seed --keys 1000
```

### Verify Data

```bash
./redis-tool data verify
```

### Rolling Upgrade

```bash
./redis-tool upgrade --target-version 7.2.6 --strategy rolling
```

### Full Verification

```bash
./redis-tool verify --full
```

## Rolling Upgrade Strategy

The upgrade follows this order to achieve zero downtime:

1. **Pre-flight checks** — verify cluster is healthy before starting
2. **Upgrade replicas first** (one at a time)
   - Stop Redis on replica
   - Install new version
   - Start Redis
   - Wait for rejoin
   - Verify cluster still ok
3. **Upgrade masters** (one at a time with failover)
   - Trigger CLUSTER FAILOVER on replica → replica becomes master
   - Stop old master
   - Install new version
   - Start Redis as replica
   - Verify cluster still ok
4. **Post-upgrade verification**
   - Verify all 1000 keys intact
   - Verify all nodes on new version

This strategy ensures zero client-visible downtime because at every point there is always an active master serving requests.

## Project Structure
## Assumptions and Trade-offs

- Redis is compiled from source to ensure exact version control
- Containers use port mapping (2221-2226) for SSH since WSL cannot directly reach Docker bridge IPs
- No systemd in containers — Redis started directly via nohup
- Data is cleared on re-provision (clean slate approach)

## Known Limitations

- Provision command always recompiles Redis from source (slow ~5-10 min)
- Containers lose Redis process on restart — must re-run provision
- WSL users must use localhost ports instead of container IPs
