#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root or with sudo."
  exit 1
fi

# Update and upgrade system packages
echo "🛠️  Updating and upgrading system packages..."
sudo apt update -y
sudo apt upgrade -y

# Install necessary packages
echo "📥 Installing curl..."
sudo apt install curl -y

echo "📥 Installing samba..."
sudo apt install samba -y
sudo systemctl start smbd
sudo systemctl enable smbd
sudo systemctl start nmbd
sudo systemctl enable nmbd

echo "🖥️  Installing Cockpit..."
sudo apt install --no-install-recommends cockpit -y

echo "🌐 Installing WSDD (Web Services for Devices Daemon)..."
sudo apt install wsdd -y

# Download required .deb files
echo "📂 Downloading Cockpit File Sharing..."
curl -LO https://github.com/45Drives/cockpit-file-sharing/releases/download/v4.2.8/cockpit-file-sharing_4.2.8-1focal_all.deb
sudo apt install ./cockpit-file-sharing_4.2.8-1focal_all.deb -y

# Remove downloaded .deb files
echo "🧹 Cleaning up downloaded files..."
rm ./*.deb

echo "🎉 Cockpit and additional packages installation complete!"

# Create .ssh
sudo mkdir -p ~/.ssh/ && sudo touch ~/.config/.ssh/authorized_keys

# Step 1: Create a Group
read -p "Enter the name of the group to create: " GROUP_NAME
if getent group "$GROUP_NAME" >/dev/null; then
  echo "✅ Group '$GROUP_NAME' already exists."
else
  if sudo groupadd "$GROUP_NAME"; then
    echo "✅ Group '$GROUP_NAME' created successfully."
  else
    echo "❌ Failed to create group '$GROUP_NAME'."
    exit 1
  fi
fi
PGID=$(getent group "$GROUP_NAME" | cut -d: -f3)
echo "PGID for '$GROUP_NAME': $PGID"

# Step 2: Create a User
read -p "Enter the username to create: " USER_NAME
if id -u "$USER_NAME" >/dev/null 2>&1; then
  echo "✅ User '$USER_NAME' already exists."
else
  if sudo adduser "$USER_NAME"; then
    echo "✅ User '$USER_NAME' created successfully."
  else
    echo "❌ Failed to create user '$USER_NAME'."
    exit 1
  fi
fi
# Add user to groups
if sudo usermod -aG sudo "$USER_NAME" && \
   sudo usermod -aG users "$USER_NAME" && \
   sudo usermod -aG "$GROUP_NAME" "$USER_NAME"; then
  echo "✅ User '$USER_NAME' added to groups 'sudo', 'users', and '$GROUP_NAME'."
else
  echo "❌ Failed to add user '$USER_NAME' to groups."
  exit 1
fi
# Display PUID
PUID=$(id -u "$USER_NAME")
echo "PUID for '$USER_NAME': $PUID"

# Step 3: Check if Samba Password Exists
if sudo smbpasswd -e "$USER_NAME" 2>/dev/null | grep -q "enabled"; then
  echo "✅ Samba password already exists and is enabled for user '$USER_NAME'."
else
  # Set Samba Password
  while true; do
    read -s -p "Enter Samba password for user '$USER_NAME': " SAMBA_PASSWORD
    echo
    read -s -p "Confirm Samba password: " SAMBA_PASSWORD_CONFIRM
    echo
    if [ "$SAMBA_PASSWORD" = "$SAMBA_PASSWORD_CONFIRM" ]; then
      if echo -e "$SAMBA_PASSWORD\n$SAMBA_PASSWORD" | sudo smbpasswd -a "$USER_NAME"; then
        echo "✅ Samba password set for user '$USER_NAME'."
      else
        echo "❌ Failed to set Samba password for user '$USER_NAME'."
        exit 1
      fi
      break
    else
      echo "❌ Passwords do not match. Please try again."
    fi
  done
fi

# Step 4: Configure File Sharing
read -p "Enter Server Description: " SERVER_DESCRIPTION
read -p "Enter Workgroup (default: WORKGROUP): " WORKGROUP
WORKGROUP=${WORKGROUP:-WORKGROUP}

# Apply Server Configuration
if [ -f /etc/samba/smb.conf ]; then
  read -p "Samba configuration file already exists. Overwrite? (y/N): " OVERWRITE_CONF
  OVERWRITE_CONF=${OVERWRITE_CONF:-n}
  if [[ ! "$OVERWRITE_CONF" =~ ^[Yy]$ ]]; then
    echo "❌ Skipping Samba configuration update."
  else
    if sudo bash -c "cat > /etc/samba/smb.conf <<EOF
[global]
   server string = $SERVER_DESCRIPTION
   workgroup = $WORKGROUP
   security = user
   map to guest = Bad User
   include = registry
EOF"; then
      echo "✅ Samba global configuration applied."
    else
      echo "❌ Failed to apply Samba global configuration."
      exit 1
    fi
  fi
else
  if sudo bash -c "cat > /etc/samba/smb.conf <<EOF
[global]
   server string = $SERVER_DESCRIPTION
   workgroup = $WORKGROUP
   security = user
   map to guest = Bad User
   include = registry
EOF"; then
    echo "✅ Samba global configuration applied."
  else
    echo "❌ Failed to apply Samba global configuration."
    exit 1
  fi
fi

# Validate Samba Configuration
echo "🔍 Validating Samba configuration..."
if testparm -s > /dev/null 2>&1; then
  echo "✅ Samba configuration is valid."
else
  echo "❌ Samba configuration is invalid. Please check /etc/samba/smb.conf."
  exit 1
fi

# Migrate Shares to Registry Backend
while true; do
  read -p "Do you want to add a new share to the Samba registry? (y/N): " ADD_SHARE
  ADD_SHARE=${ADD_SHARE:-n}
  if [[ "$ADD_SHARE" =~ ^[Yy]$ ]]; then
    read -p "Enter Share Name: " SHARE_NAME
    read -p "Enter Share Description: " SHARE_DESCRIPTION
    read -p "Enter Path for the Share: " SHARE_PATH

    # Create the directory if it doesn't exist
    if [ ! -d "$SHARE_PATH" ]; then
      if sudo mkdir -p "$SHARE_PATH"; then
        echo "✅ Directory '$SHARE_PATH' created."
      else
        echo "❌ Failed to create directory '$SHARE_PATH'."
        exit 1
      fi
    fi

    # Change ownership and permissions
    if sudo chown "$USER_NAME:$GROUP_NAME" "$SHARE_PATH" && sudo chmod 775 "$SHARE_PATH"; then
      echo "✅ Permissions set to '775' with owner '$USER_NAME:$GROUP_NAME'."
    else
      echo "❌ Failed to set permissions for '$SHARE_PATH'."
      exit 1
    fi

    # Add the share to the Samba registry
    if sudo net conf addshare "$SHARE_NAME" "$SHARE_PATH" writeable=y guest_ok=n "$SHARE_DESCRIPTION"; then
      echo "✅ Share '$SHARE_NAME' added to Samba registry."
    else
      echo "❌ Failed to add share '$SHARE_NAME' to Samba registry."
      exit 1
    fi

    if sudo systemctl restart smbd; then
      echo "✅ Samba service restarted after adding share '$SHARE_NAME'."
    else
      echo "❌ Failed to restart Samba service after adding share '$SHARE_NAME'."
      exit 1
    fi
  else
    break
  fi
done

echo "🎉 Cockpit and Samba setup complete!"
