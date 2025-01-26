
#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root or with sudo."
  exit 1
fi

# Ensure the template is available
TEMPLATE="local:vztmpl/ubuntu-24.10-standard_24.10-1_amd64.tar.zst"
echo "🔍 Checking for template: $TEMPLATE..."
if ! pvesm list local | grep -q "ubuntu-24.10-standard_24.10-1_amd64.tar.zst"; then
  echo "📥 Template not found. Downloading..."
  pveam update
  pveam download local ubuntu-24.10-standard_24.10-1_amd64.tar.zst
fi

# Prompt for LXC Template Settings
read -p "Enter CT ID (default: 100): " CT_ID
CT_ID=${CT_ID:-100}

read -p "Enter Hostname (default: lxc): " HOSTNAME
HOSTNAME=${HOSTNAME:-lcx}

while true; do
    read -p "Enter Password for the container (default: 12345): " -s PASSWORD
  PASSWORD=${PASSWORD:-12345}
  echo
  read -p "Confirm Password (default: 12345): " -s PASSWORD_CONFIRM
  PASSWORD_CONFIRM=${PASSWORD_CONFIRM:-12345}
  echo
  if [ "$PASSWORD" == "$PASSWORD_CONFIRM" ]; then
    break
  else
    echo "❌ Passwords do not match. Please try again."
  fi
done
#
# Function to display available storage
list_storage_names() {
  echo -e "\nAvailable Storage Volumes:\n"
  pvesm status | awk 'NR > 1 {print "  - " $1}'
  echo
}

# Default values for Root Disk Storage and Size
list_storage_names
read -p "Enter Root Disk Name: " ROOT_STORAGE
ROOT_DISK_SIZE=16

# Prompt for Mount Points
MOUNT_POINTS=()
MOUNT_POINT_ID=0
while true; do
  read -p "Do you want to add a mount point? (y/N): " ADD_MP
  ADD_MP=${ADD_MP:-n}
  if [[ "$ADD_MP" =~ ^[Yy]$ ]]; then
    list_storage_names
    read -p "Enter mp${MOUNT_POINT_ID} Storage Name: " MP_STORAGE
    read -p "Enter mp${MOUNT_POINT_ID} Size in GB: " MP_SIZE
    read -p "Enter mp${MOUNT_POINT_ID} Path (e.g., /data): " MP_PATH
    read -p "Should mp${MOUNT_POINT_ID} be backed up? (y/N): " MP_BACKUP
    MP_BACKUP=${MP_BACKUP,,}  # Convert to lowercase
    MP_BACKUP_FLAG=$([[ "$MP_BACKUP" == "y" ]] && echo "1" || echo "0")
    MOUNT_POINTS+=("$MP_STORAGE:$MP_SIZE:$MP_PATH:$MP_BACKUP_FLAG")
    MOUNT_POINT_ID=$((MOUNT_POINT_ID + 1))
  else
    break
  fi
done

# Prompt for CPU, Memory, and Swap
read -p "Enter Number of CPU Cores (default: 2): " CPU_CORES
CPU_CORES=${CPU_CORES:-2}

read -p "Enter Memory in MB (default: 2048): " MEMORY
MEMORY=${MEMORY:-2048}

read -p "Enter Swap in MB (default: 2048): " SWAP
SWAP=${SWAP:-2048}

# Set Network Configuration
NET_CONFIG="name=eth0,bridge=vmbr0,ip=dhcp,ip6=dhcp"

# Set DNS Configuration
DNS_CONFIG=""

# Summary of Inputs
clear
echo "🚀 Summary of LXC Template Configuration"
echo "----------------------------------------"
echo "CT ID         : $CT_ID"
echo "Hostname      : $HOSTNAME"
echo "Root Storage  : $ROOT_STORAGE"
echo "Root Disk Size: ${ROOT_DISK_SIZE}G"
echo "CPU Cores     : $CPU_CORES"
echo "Memory        : ${MEMORY}MB"
echo "Swap          : ${SWAP}MB"
echo "Network Config: $NET_CONFIG"
echo "DNS Config    : $DNS_CONFIG"
echo "Mount Points  :"
for MP in "${MOUNT_POINTS[@]}"; do
  IFS=":" read -r MP_STORAGE MP_SIZE MP_PATH MP_BACKUP <<< "$MP"
  echo "  - Storage: $MP_STORAGE, Size: ${MP_SIZE}G, Path: $MP_PATH, Backup: $([[ "$MP_BACKUP" == "1" ]] && echo "Yes" || echo "No")"
done
read -p "Proceed with creating the template? (y/N): " CONFIRM
CONFIRM=${CONFIRM:-n}
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "❌ Operation canceled."
  exit 0
fi

# Create the LXC Template
echo "🔧 Creating LXC Template..."
pct create $CT_ID $TEMPLATE \
  --cores $CPU_CORES \
  --features nesting=1 \
  --hostname $HOSTNAME \
  --memory $MEMORY \
  --net0 "$NET_CONFIG" \
  --password $PASSWORD \
  --rootfs "$ROOT_STORAGE:$ROOT_DISK_SIZE" \
  --swap $SWAP \
  --unprivileged 1 \


# Add Mount Points by editing the LXC configuration file

LXC_CONF="/etc/pve/lxc/${CT_ID}.conf"
if [ -f "$LXC_CONF" ]; then
  echo "🔧 Adding mount points to $LXC_CONF..."
  MP_INDEX=0
  for MP in "${MOUNT_POINTS[@]}"; do
    IFS=":" read -r MP_STORAGE MP_SIZE MP_PATH MP_BACKUP <<< "$MP"
    read -p "Use default sub volumes for this mp${MP_INDEX}? (y/N): " IS_SUBVOL
    IS_SUBVOL=${IS_SUBVOL:-n}
    if [[ "$IS_SUBVOL" =~ ^[Yy]$ ]]; then
	echo "mp${MP_INDEX}: ${MP_STORAGE}:subvol-${CT_ID}-disk-1,mp=${MP_PATH},size=${MP_SIZE}G,backup=${MP_BACKUP}" >> "$LXC_CONF"
    else
	read -p "Enter Subvolume CT ID: " SUBVOL_CT_ID
	read -p "Enter Subvolume Disk ID: " SUBVOL_DISK_ID
	echo "mp${MP_INDEX}: ${MP_STORAGE}:subvol-${SUBVOL_CT_ID}-disk-${SUBVOL_DISK_ID},mp=${MP_PATH},size=${MP_SIZE}G,backup=${MP_BACKUP}" >> "$LXC_CONF"
    fi
    MP_INDEX=$((MP_INDEX + 1))
  done
else
  echo "❌ LXC configuration file $LXC_CONF not found. Skipping mount points."
fi

echo "✅ $CT_ID($HOSTNAME) created successfully!"
