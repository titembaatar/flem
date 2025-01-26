
#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root or with sudo."
  exit 1
fi

# Create a New Admin User
read -p "Enter the username for the new admin user: " NEW_USER
if id -u "$NEW_USER" >/dev/null 2>&1; then
  echo "✅ User '$NEW_USER' already exists."
else
  sudo adduser "$NEW_USER"
  sudo usermod -aG sudo "$NEW_USER"
  echo "✅ User '$NEW_USER' created and added to the sudo group."
fi

# Configure Timezone
read -p "Enter your desired timezone (default: Europe/Paris): " TIMEZONE
TIMEZONE=${TIMEZONE:-Europe/Paris}
if timedatectl set-timezone "$TIMEZONE"; then
  echo "✅ Timezone set to $TIMEZONE."
else
  echo "❌ Failed to set timezone. Please check the input."
fi

# Update and Upgrade the System
echo "🔄 Updating and upgrading the system..."
sudo apt update && sudo apt upgrade -y

# Install Common Tools
echo "🔧 Installing common tools..."
sudo apt install -y curl wget git htop ufw unzip tar

# Secure the SSH Service
echo "🔒 Securing SSH service..."
SSH_CONFIG="/etc/ssh/sshd_config"
if [ -f "$SSH_CONFIG" ]; then
  sudo sed -i 's/^#?PermitRootLogin.*/PermitRootLogin no/' "$SSH_CONFIG"
  sudo sed -i 's/^#?PasswordAuthentication.*/PasswordAuthentication yes/' "$SSH_CONFIG"
  sudo sed -i 's/^#?Port.*/Port 2222/' "$SSH_CONFIG"
  echo "✅ SSH configuration updated."
  echo "Restarting SSH service..."
  sudo systemctl restart sshd
else
  echo "❌ SSH configuration file not found at $SSH_CONFIG."
fi

echo "🎉 Post-installation steps completed!"
