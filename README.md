# Redis Cluster Lifecycle Tool

A CLI tool that wraps Ansible to provision, operate, and perform a rolling upgrade of a Redis Cluster with zero downtime and verified data integrity.

## Prerequisites

- Docker Engine or Podman (Podman preferred)
- Ansible 2.10+
- Python 3.x
- SSH key pair (generated automatically by setup.sh)

## Quick Start

### Step 1 — Run setup script first!

```bash
chmod +x setup.sh
./setup.sh
```

This will:
- Generate SSH key if needed
- Copy public key into infra/ folder
- Start all 6 containers
- Verify SSH access works

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

6 Ubuntu 22.04 containers simulating real servers:

| Container | IP | SSH Port |
|---|---|---|
| redis-node-1 | 10.10.0.11 | 2221 |
| redis-node-2 | 10.10.0.12 | 2222 |
| redis-node-3 | 10.10.0.13 | 2223 |
| redis-node-4 | 10.10.0.14 | 2224 |
| redis-node-5 | 10.10.0.15 | 2225 |
| redis-node-6 | 10.10.0.16 | 2226 |

## Manual Setup (if setup.sh fails)

```bash
# Generate SSH key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""

# Copy public key
cp ~/.ssh/id_rsa.pub infra/authorized_keys

# Start containers (Docker)
cd infra && docker compose up -d --build

# OR start containers (Podman)
cd infra && podman-compose up -d
```

## Rolling Upgrade Strategy

1. Pre-flight checks — verify cluster healthy
2. Upgrade replicas first (one at a time, safe)
3. Upgrade masters with CLUSTER FAILOVER (zero downtime)
4. Post-upgrade data verification

## Assumptions and Trade-offs

- Redis compiled from source for exact version control
- Containers use port mapping (2221-2226) for SSH
- No systemd in containers — Redis started via nohup
- Data cleared on re-provision

## Known Limitations

- Provision takes 5-10 min (compiles from source)
- Containers lose Redis on restart — re-run provision
- WSL users: use localhost ports not container IPs
