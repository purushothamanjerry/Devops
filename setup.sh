#!/bin/bash

echo "=== Redis Cluster Lifecycle Tool Setup ==="

# Step 1: Generate SSH key if not exists
if [ ! -f ~/.ssh/id_rsa ]; then
    echo "Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
fi

# Step 2: Copy public key to infra/
echo "Copying public key..."
cp ~/.ssh/id_rsa.pub infra/authorized_keys
echo "authorized_keys created!"

# Step 3: Detect container runtime
if command -v podman &> /dev/null; then
    RUNTIME="podman"
    COMPOSE="podman-compose"
elif command -v docker &> /dev/null; then
    RUNTIME="docker"
    # Check if docker compose v2 works
    if docker compose version &> /dev/null 2>&1; then
        COMPOSE="docker compose"
    else
        COMPOSE="docker-compose"
    fi
else
    echo "ERROR: No container runtime found!"
    echo "Install Docker: https://docs.docker.com/engine/install/"
    echo "Install Podman: https://podman.io/docs/installation"
    exit 1
fi

echo "Using: $RUNTIME"

# Step 4: Clean old networks
echo "Cleaning old networks..."
if [ "$RUNTIME" = "podman" ]; then
    podman network rm infra_redis-net 2>/dev/null || true
else
    docker network rm infra_redis-net 2>/dev/null || true
fi

# Step 5: Build and start containers
echo "Starting containers..."
cd infra/
$COMPOSE up -d --build
cd ..

# Step 6: Wait for SSH
echo "Waiting for containers..."
sleep 5

# Step 7: Test SSH
echo "Testing SSH..."
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -p 2221 root@localhost "hostname"

echo ""
echo "=== Setup Complete! ==="
echo "Now run: ./redis-tool provision --version 7.0.15 --masters 3 --replicas-per-master 1"
