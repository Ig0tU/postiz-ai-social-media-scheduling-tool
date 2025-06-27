#!/bin/bash

# Exit on any error
set -e

echo "🚀 Starting Postiz container launch automation..."

# Function to check if a container exists
container_exists() {
    docker ps -a --format '{{.Names}}' | grep -q "^$1$"
}

# Function to check if a container is running
container_running() {
    docker ps --format '{{.Names}}' | grep -q "^$1$"
}

# Stop and remove existing containers if they exist
echo "🧹 Cleaning up existing containers..."
containers=("postiz" "postiz-postgres" "postiz-redis" "postiz-pg-admin" "postiz-redisinsight")
for container in "${containers[@]}"; do
    if container_exists "$container"; then
        echo "Stopping and removing $container..."
        docker stop "$container" 2>/dev/null || true
        docker rm "$container" 2>/dev/null || true
    fi
done

# Start dependencies using docker-compose
echo "🔄 Starting dependency services..."
docker-compose -f docker-compose.dev.yaml up -d

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
until docker exec postiz-postgres pg_isready -U postiz-local 2>/dev/null; do
    echo "PostgreSQL is not ready yet... waiting 2 seconds"
    sleep 2
done

# Build Postiz container
echo "🏗️ Building Postiz container..."
bash var/docker/docker-build.sh

# Create and start Postiz container
echo "🚀 Creating and starting Postiz container..."
bash var/docker/docker-create.sh
docker start postiz

# Verify all containers are running
echo "✅ Verifying container status..."
all_running=true
for container in "${containers[@]}"; do
    if ! container_running "$container"; then
        echo "❌ Error: $container is not running!"
        all_running=false
    fi
done

if [ "$all_running" = true ]; then
    echo """
🎉 Postiz containers successfully launched!

Services available at:
- Postiz: http://localhost:3000
- PostgreSQL: localhost:5432
- Redis: localhost:6379
- pgAdmin: http://localhost:8081
- RedisInsight: http://localhost:5540

To view logs: docker logs postiz
To stop all containers: docker-compose -f docker-compose.dev.yaml down && docker stop postiz
"""
else
    echo "❌ Some containers failed to start. Please check the logs for more details."
    exit 1
fi
