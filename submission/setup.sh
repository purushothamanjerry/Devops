#!/bin/bash

set -e

echo "=== Redis Cluster Lifecycle Tool Setup ==="

# Step 1: Generate SSH key if not exists
if [ ! -f ~/.ssh/id_rsa ]; then
    echo "Generating SSH key..."
    mkdir -p ~/.ssh
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
fi

# Step 2: Copy public key to infra/
echo "Copying public key..."
cp ~/.ssh/id_rsa.pub infra/authorized_keys
echo "  ✓ authorized_keys created"

# Step 3: Detect container runtime and compose tool
RUNTIME=""
COMPOSE_CMD=""

if command -v podman-compose &> /dev/null; then
    COMPOSE_CMD="podman-compose"
    RUNTIME="podman"
    echo "  ✓ Using: podman-compose"
elif podman compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="podman compose"
    RUNTIME="podman"
    echo "  ✓ Using: podman compose"
elif docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
    RUNTIME="docker"
    echo "  ✓ Using: docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
    RUNTIME="docker"
    echo "  ✓ Using: docker-compose"
else
    echo "  ✗ ERROR: No compose tool found!"
    echo "    Install Podman (recommended): https://podman.io/docs/installation"
    echo "    Install Docker: https://docs.docker.com/engine/install/"
    exit 1
fi

# Step 4: Clean old networks (using detected runtime only)
echo "Cleaning old networks..."
if [ "$RUNTIME" = "podman" ]; then
    podman network rm infra_redis-net 2>/dev/null || true
else
    docker network rm infra_redis-net 2>/dev/null || true
fi

# Step 5: Build and start containers
echo "Starting containers..."
cd infra/

if [ "$COMPOSE_CMD" = "podman-compose" ]; then
    podman-compose up -d --build
elif [ "$COMPOSE_CMD" = "podman compose" ]; then
    podman compose up -d --build
elif [ "$COMPOSE_CMD" = "docker compose" ]; then
    docker compose up -d --build
else
    docker-compose up -d --build
fi

cd ..

# Step 6: Wait for SSH to become available
echo "Waiting for containers to start..."
sleep 5

# Step 7: Test SSH access to all nodes
echo "Testing SSH access..."
all_ok=true
for port in 2221 2222 2223 2224 2225 2226; do
    node=$((port - 2220))
    result=$(ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o ConnectTimeout=5 -p $port root@localhost "hostname" 2>/dev/null)
    if [ -n "$result" ]; then
        echo "  redis-node-$node → $result ✓"
    else
        echo "  redis-node-$node → FAILED ✗"
        all_ok=false
    fi
done

echo ""
if [ "$all_ok" = true ]; then
    echo "=== Setup Complete! ==="
    echo ""
    echo "Now run:"
    echo "  chmod +x redis-tool"
    echo "  ./redis-tool provision --version 7.0.15 --masters 3 --replicas-per-master 1"
else
    echo "=== Setup completed with errors ==="
    echo "Some nodes were not reachable. Try waiting a few seconds and re-testing:"
    echo "  ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -p 2221 root@localhost hostname"
fi
