#!/bin/bash

# Lazy Tailscale + Docker Network Script
# 1. Installs Tailscale on the LXC
# 2. Creates a Docker network called 'tailscale'
# 3. Automatically extracts the subnet from that Docker network
# 4. Advertises the subnet via Tailscale

# Function to display steps to add /dev/net/tun to LXC .conf
display_tun_instructions() {
    echo -e "\n❌ /dev/net/tun is not configured in the LXC. Please follow these steps to fix it:"
    echo -e "\n1. On the Proxmox host, edit the LXC configuration file:\n   \033[1;36mnano /etc/pve/lxc/<container-id>.conf\033[0m"
    echo -e "\n2. Add the following lines to the configuration file:\n   \033[1;32mlxc.cgroup2.devices.allow = c 10:200 rwm\n   lxc.mount.entry = /dev/net/tun dev/net/tun none bind,create=file\033[0m"
    echo -e "\n3. Restart the LXC to apply the changes:\n   \033[1;36mpct stop <container-id>\n   pct start <container-id>\033[0m"
    echo -e "\nAfter completing these steps, re-run this script."
}

# Prompt to check if /dev/net/tun is added
read -p "❓ Have you added /dev/net/tun to the LXC .conf? (yes/no): " TUN_CONFIRMATION
if [[ "$TUN_CONFIRMATION" != "yes" ]]; then
    display_tun_instructions
    exit 1
fi

echo "🚀 Setting up Tailscale on LXC with a dedicated Docker network..."

# Step 1: Check for prerequisites and install if missing
check_and_install() {
    if ! command -v "$1" &> /dev/null; then
        echo "📦 $1 is not installed. Installing..."
        sudo apt update -y && sudo apt install -y "$1"
    else
        echo "✅ $1 is already installed."
    fi
}

echo "🔍 Checking prerequisites..."
check_and_install curl
check_and_install gnupg
check_and_install docker.io
check_and_install docker-compose

# Step 2: Install Tailscale if not already installed
if ! command -v tailscale &> /dev/null; then
    echo "📦 Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
else
    echo "✅ Tailscale is already installed."
fi

# Step 2.1: Ensure the tailscaled service is started
echo "🔧 Starting and enabling the tailscaled service..."
sudo systemctl enable tailscaled
sudo systemctl start tailscaled

# Verify if the service is running
if ! systemctl is-active --quiet tailscaled; then
    echo "❌ Failed to start the tailscaled service. Check 'sudo systemctl status tailscaled' for more details."
    exit 1
else
    echo "✅ tailscaled service is running."
fi

# Step 3: Create or verify Docker network 'tailscale'
echo "🐳 Creating Docker network 'tailscale' (if it doesn't exist)..."
if ! docker network ls | grep -q "tailscale"; then
    docker network create \
        --driver bridge \
        tailscale
    echo "✅ Docker network 'tailscale' created."
else
    echo "✅ Docker network 'tailscale' already exists."
fi

# Step 4: Extract the subnet from the 'tailscale' Docker network
echo "🔍 Extracting the subnet from the 'tailscale' network..."
SUBNET=$(docker network inspect tailscale --format='{{(index .IPAM.Config 0).Subnet}}')

if [ -z "$SUBNET" ]; then
    echo "❌ Could not determine the subnet for the 'tailscale' network."
    echo "Make sure the network has a valid IPAM configuration."
    exit 1
fi

echo "✅ Found subnet for 'tailscale' network: $SUBNET"

# Step 5: Enable IP forwarding (for routing traffic from Tailscale)
echo "🌐 Enabling IP forwarding..."
sudo sysctl -w net.ipv4.ip_forward=1

# Step 6: Authenticate Tailscale and advertise the Docker network subnet
echo "🔑 Authenticating Tailscale..."
read -p "Enter your Tailscale auth key (or visit https://login.tailscale.com to generate one): " TAILSCALE_AUTH_KEY
if [ -z "$TAILSCALE_AUTH_KEY" ]; then
    echo "❌ Tailscale auth key is required. Exiting."
    exit 1
fi

# If Tailscale is already up, bring it down first to reconfigure
sudo tailscale down 2>/dev/null

echo "🌐 Bringing Tailscale up and advertising subnet: $SUBNET"
sudo tailscale up \
    --authkey="${TAILSCALE_AUTH_KEY}" \
    --advertise-routes="${SUBNET}" --accept-dns=false

# Final Message
echo "✅ Tailscale setup complete!"
echo "📡 The Docker network '$SUBNET' is now advertised over Tailscale."
echo "👉 Attach containers to the 'tailscale' network in your docker-compose.yaml or CLI to expose them via Tailscale."

