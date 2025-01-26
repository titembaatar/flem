#!/bin/bash

# Lazy Caddy Script
# Sets up Caddy with Docker, builds from source with custom modules, and configures environment variables.

echo "🚀 Setting up Caddy with Docker..."

# Step 1 : Create an install directory
read -p "📂 Choose installation directory: " INSTALL_DIR
INSTALL_DIR="${INSTALL_DIR%/}/"
echo "📂 Checking ${INSTALL_DIR}caddy/ directory..."
if [ ! -d "${INSTALL_DIR}caddy/" ]; then
    echo "📂 Creating directory: ${INSTALL_DIR}caddy/"
    mkdir -p ${INSTALL_DIR}caddy/
    echo "📂 ${INSTALL_DIR}caddy/ created ✅"
else
    echo "📂 Directory ${INSTALL_DIR}/caddy/ already exists ✅"
fi
cd ${INSTALL_DIR}caddy/ || exit

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
check_and_install build-essential

# Special handling for xcaddy
if ! command -v xcaddy &> /dev/null; then
    echo "📦 xcaddy is not installed. Installing..."
    check_and_install debian-keyring
    check_and_install debian-archive-keyring 
    check_and_install apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/xcaddy/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-xcaddy-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/xcaddy/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-xcaddy.list
    sudo apt install xcaddy -y
    echo "✅ xcaddy installed successfully."
else
    echo "✅ xcaddy is already installed."
fi

# Step 3: Creating file used by caddy
echo "📝 Setting environment variables..."
read -p "Enter your public IP (MY_IP): " MY_IP
read -p "Enter your mail (MY_EMAIL): " MY_IP
read -p "Enter your domain name (MY_DOMAIN): " MY_DOMAIN
read -p "Enter your Cloudflare API token (CLOUDFLARE_API_TOKEN): " CLOUDFLARE_API_TOKEN
read -p "Enter the name of the Docker Network for caddy (NETWORK): " NETWORK

# .env
cat <<EOF > .env
MY_EMAIL=${MY_EMAIL}
MY_IP=${MY_IP}
MY_DOMAIN=${MY_DOMAIN}
CLOUDFLARE_API_TOKEN=${CLOUDFLARE_API_TOKEN}
NETWORK=${NETWORK}
EOF
echo "✅ Environment variables saved to .env."

# Caddyfile
echo "📝 Writing Caddyfile..."
cat <<EOF > Caddyfile
{
    email {\$MY_EMAIL}
    acme_dns cloudflare {\$CLOUDFLARE_API_TOKEN}
    log {
        output stdout
        format console
    }
}
EOF

# Dockerfile
echo "🐋 Writing Dockerfile..."
cat <<EOF > Dockerfile
FROM caddy:2.9.1-builder AS builder
RUN xcaddy build \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/lucaslorentz/caddy-docker-proxy/v2
FROM caddy:2.9.1
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
CMD ["caddy", "docker-proxy"]
EOF

# docker-compose.yaml
echo "🐋 Writing docker-compose.yaml..."
cat <<EOF > docker-compose.yaml
services:  
  caddy:
    build: ./
    container_name: caddy
    hostname: ${NETWORK}
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    environment:
      - MY_IP=\${MY_IP}
      - MY_DOMAIN=\${MY_DOMAIN}
      - MY_EMAIL=\$(MY_EMAIL}
      - CLOUDFLARE_API_TOKEN=\${CLOUDFLARE_API_TOKEN}
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./caddy_data:/data
      - ./caddy_config:/config
      - /var/run/docker.sock:/var/run/docker.sock

networks:
  ${NETWORK}:
    external: true
EOF

# Step 4 : Creating the Docker Network
echo "🌐 Checking if Docker Network ${NETWORK} exists..."
if docker network inspect ${NETWORK} >/dev/null 2>&1; then
    echo "🌐 Docker network ${NETWORK} exists ✅"
else
    echo "🌐 Creating Docker Network ${NETWORK}..."
    docker network create ${NETWORK}
    echo "🌐 Docker Network ${NETWORK} created ✅"
fi

# Step 5: Build and start the Docker container
echo "🏗️ Building and starting the Docker container..."
docker-compose up -d --build

# Final Message
echo "✅ Caddy setup complete! Use the following command to check logs:"
echo "   docker logs caddy -f"
