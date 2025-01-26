#!/bin/bash

# Lazy Dockge Script
# Sets up Dockge with Docker and configures environment variables.

echo "🚀 Setting up Dockge with Docker..."

# Step 1 : Create an install directory
read -p "📂 Choose installation directory: " INSTALL_DIR
INSTALL_DIR="${INSTALL_DIR%/}/"
echo "📂 Checking ${INSTALL_DIR}dockge/ directory..."
if [ ! -d "${INSTALL_DIR}dockge/" ]; then
    echo "📂 Creating directory: ${INSTALL_DIR}dockge/"
    mkdir -p ${INSTALL_DIR}dockge/
    echo "📂 ${INSTALL_DIR}dockge/ created ✅"
else
    echo "📂 Directory ${INSTALL_DIR}dockge/ already exists ✅"
fi
cd ${INSTALL_DIR}dockge/ || exit

# Step 2: Check for prerequisites and install if missing
check_and_install() {
    if ! command -v "$1" &> /dev/null; then
        echo "📦 $1 is not installed. Installing..."
        sudo apt update -y && sudo apt install -y "$1"
    else
        echo "📦 $1 is already installed ✅"
    fi
}

echo "🔍 Checking prerequisites..."
check_and_install git
check_and_install curl
check_and_install docker-compose

# Step 3: Creating .env and docker-compose.yaml
echo "📝 Setting environment variables..."
read -p "Enter your domain name (e.g., example.com): " MY_DOMAIN
read -p "Enter the name of the Docker Network for caddy: " NETWORK
read -p "Enter your stacks directory (e.g., /config/docker-compose): " DOCKGE_STACKS_DIR

# .env
cat <<EOF > .env
TZ=Europe/Paris
PUID=1000
PGID=1000
MY_DOMAIN=${MY_DOMAIN}
DOCKGE_STACKS_DIR=${DOCKGE_STACKS_DIR}
EOF
echo "✅ Environment variables saved to .env."

# docker-compose.yaml
echo "🐋 Writing docker-compose.yaml for Dockge..."
cat <<EOF > docker-compose.yaml
services:
  dockge:
    image: louislam/dockge:latest
    container_name: dockge
    restart: unless-stopped
    ports:
      - 5001:5001
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./data:/app/data
      - ${DOCKGE_STACKS_DIR}:/stacks
    environment:
      - DOCKGE_STACKS_DIR=\${DOCKGE_STACKS_DIR}
    labels:
      caddy: dockge.${MY_DOMAIN}
      caddy.reverse_proxy: "{{upstreams 5001}}"
    networks:
      - ${NETWORK}

networks:
  ${NETWORK}:
    external: true
EOF

# Step 4: Starting container
echo "🏗️ Starting the Dockge container..."
docker-compose up -d

# Final Message
echo "✅ Dockge setup complete! Access it at https://dockge.${MY_DOMAIN}"
