#!/bin/bash

# Lazy Uptime Kuma Script
# Sets up Uptime Kuma with Docker and configures environment variables.

echo "🚀 Setting up Uptime Kuma with Docker..."

# Step 1 : Create an install directory
read -p "📂 Choose installation directory: " INSTALL_DIR
INSTALL_DIR="${INSTALL_DIR%/}/"
echo "📂 Checking ${INSTALL_DIR}uptime-kuma/ directory..."
if [ ! -d "${INSTALL_DIR}uptime-kuma/" ]; then
    echo "📂 Creating directory: ${INSTALL_DIR}uptime-kuma/"
    mkdir -p ${INSTALL_DIR}uptime-kuma/
    echo "📂 ${INSTALL_DIR}uptime-kuma/ created ✅"
else
    echo "📂 Directory ${INSTALL_DIR}uptime-kuma/ already exists ✅"
fi
cd ${INSTALL_DIR}uptime-kuma/ || exit

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

# .env
cat <<EOF > .env
TZ=Europe/Paris
PUID=1000
PGID=1000
MY_DOMAIN=${MY_DOMAIN}
EOF
echo "✅ Environment variables saved to .env."

# docker-compose.yaml
echo "🐋 Writing docker-compose.yaml for Uptime Kuma..."
cat <<EOF > docker-compose.yaml
services:
  kuma:
    image: louislam/uptime-kuma:latest
    container_name: uptime-kuma
    ports:
      - 3001:3001
    environment:
      - TZ=\${TZ}
      - PUID=\${PUID}
      - PGID=\${PGID}
    volumes:
      - ./config:/app/data
      - /var/run/docker.sock:/var/run/docker.sock:ro
    restart: unless-stopped
    labels:
      caddy: uptime-kuma.${MY_DOMAIN}
      caddy.reverse_proxy: "{{upstreams 3001}}"
    networks:
      - ${NETWORK}

networks:
  ${NETWORK}:
    external: true
EOF

# Step 4: Starting the container
echo "🏗️ Starting the Uptime Kuma container..."
docker-compose up -d

# Finished
echo "✅ Uptime Kuma setup complete! Access it at https://uptime-kuma.${MY_DOMAIN}"
