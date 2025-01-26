#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root or with sudo."
  exit 1
fi

# Update package index and install prerequisites
echo "🛠️  Updating package index and installing prerequisites..."
sudo apt update -y
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
    gnupg

# Add Docker's official GPG key
echo "🔑 Adding Docker's GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up the stable Docker repository
echo "📦 Setting up the Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index again to include Docker packages
echo "🔄 Updating package index for Docker packages..."
sudo apt update -y

# Install Docker Engine, CLI, and containerd
echo "🐳 Installing Docker Engine..."
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Install Docker Compose plugin
echo "📜 Installing Docker Compose plugin..."
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Enable and start Docker service
echo "🚀 Enabling and starting Docker service..."
sudo systemctl enable docker
sudo systemctl start docker

# Verify installation
echo "✅ Verifying Docker and Docker Compose installation..."
docker --version
docker-compose --version

# Add current user to the Docker group (optional but recommended)
echo "👤 Adding the current user to the Docker group (you may need to log out and back in)..."
sudo usermod -aG docker $USER

# Create a simple Dockerfile for testing
echo "📄 Creating a test Dockerfile..."
cat <<EOF > Dockerfile
# Simple Dockerfile for testing
FROM alpine:latest
CMD ["echo", "Hello, Docker!"]
EOF

# Build and test the Docker image
echo "🏗️  Building and testing the Docker image..."
docker build -t test-image .

# Run the built image
echo "▶️ Running the test Docker image..."
docker run test-image

# Clean up test image and Dockerfile
echo "🧹 Cleaning up test artifacts..."
rm Dockerfile
docker rmi test-image -f

# Apply the updated group membership immediately
echo "🔄 Applying updated group membership for Docker..."
newgrp docker

echo "🎉 Docker Engine, Docker Compose, and test build complete!"
