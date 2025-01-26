#!/bin/bash
set -e

clear  # Clear the terminal at the start

# Success tracker
success_messages=()

# Function to update the success tracker with a scrolling list
update_success_tracker() {
  if (( ${#success_messages[@]} > 5 )); then
    success_messages=("${success_messages[@]:1}")  # Remove the oldest message
  fi

  tput sc
  tput cup 0 0
  for i in "${!success_messages[@]}"; do
    tput el
    echo "${success_messages[i]}"
  done
  for ((i=${#success_messages[@]}; i<5; i++)); do
    tput el
    echo ""
  done
  tput rc
}

# ASCII Banner with Rounded Corners
echo "
╭───────────────────────────────────────────────────╮
│         _                          __             │
│        | |                        / _|            │
│        | | __ _ _____   _     ___| |_ ___         │
│        | |/ _\` |_  / | | |   |_  /  _/ __|        │
│        | | (_| |/ /| |_| |    / /| | \\__ \\        │
│        |_|\__,_/___|\\__, |   /___|_| |___/        │
│                      __/ |_____                   │
│                     |___/______|                  │
│                                                   │
│  lazy_zfs: lazyfy your ZFS Setup                  │
│    v0.1.0                                         │
│      by titem, bc lazy                            │
│                                                   │
╰───────────────────────────────────────────────────╯
"

# Reserve 5 lines at the top for success messages
tput sc
for i in $(seq 1 5); do echo ""; done
tput rc

# Logging
LOG_FILE="/var/log/lazy_zfs_$(date '+%Y-%m-%d_%H-%M-%S').log"
exec > >(tee -i "$LOG_FILE") 2>&1
echo "Logging to $LOG_FILE"

# Trap for cleanup on errors
cleanup() {
  if zpool list | grep -qw "$POOL_NAME"; then
    echo "⚠️  Cleaning up partially created pool '$POOL_NAME'..."
    zpool destroy "$POOL_NAME"
    echo "✅ Partially created pool '$POOL_NAME' has been destroyed."
  fi
  echo "❌ An error occurred. See $LOG_FILE for details."
  exit 1
}
trap cleanup ERR

# Pool name
read -p "Enter ZFS pool name: " POOL_NAME
if [[ -z "$POOL_NAME" ]]; then
  echo "❌ Pool name cannot be empty."
  exit 1
fi

# Check if the pool name already exists
existing_pools=$(zpool list -H -o name 2>/dev/null || true)
if echo "$existing_pools" | grep -qw "$POOL_NAME"; then
  echo "⚠️  Pool name '$POOL_NAME' already exists."
  read -p "Do you want to overwrite it? (y/N): " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "❌ Operation canceled."
    exit 1
  fi
  read -p "Are you sure you want to overwrite the pool? Type 'yes' to confirm: " final_confirm
  if [[ "$final_confirm" != "yes" ]]; then
    echo "❌ Operation canceled."
    exit 1
  fi
  echo "⚙️ Destroying existing pool '$POOL_NAME'..."
  zpool destroy "$POOL_NAME"
  echo "📁 Pool '$POOL_NAME' destroyed ✔️"
  success_messages+=("📁 Existing pool '$POOL_NAME' destroyed")
  update_success_tracker
fi

success_messages+=("📁 Pool name '$POOL_NAME' verified")
update_success_tracker

# Disk selection
echo "📁 Checking available disks"
list_disks() {
  local i=1
  disks=()
  while IFS= read -r line; do
    disk_name=$(echo "$line" | awk '{print $1}')  # Extract only the device name
    disks+=("/dev/$disk_name")
    echo "  $i) $line"
    ((i++))
  done < <(lsblk -dn -o NAME,SIZE | awk '{print $1, $2}')
}
list_disks

read -p "Enter the number(s) corresponding to the disk(s) you want to use (e.g., 1 2): " disk_numbers
selected_disks=()
for num in $disk_numbers; do
  if [[ "$num" =~ ^[0-9]+$ ]] && (( num > 0 && num <= ${#disks[@]} )); then
    selected_disks+=("${disks[$((num-1))]}")
  else
    echo "Invalid selection: $num"
    exit 1
  fi
done
DISK_ARGS=$(printf "%s " "${selected_disks[@]}")
DISK_ARGS=${DISK_ARGS% }  # Remove trailing space
success_messages+=("📁 Disks selected: ${selected_disks[*]}")
update_success_tracker

# RAID level
echo "⚙️ Setting up RAID level (default: RAIDZ)"
raid_levels=("Single Disk" "Mirror" "RAIDZ" "RAIDZ2" "RAIDZ3")
for i in "${!raid_levels[@]}"; do
  echo "  $((i+1))) ${raid_levels[i]}"
done
read -p "Enter your choice (1-${#raid_levels[@]}): " raid_choice
RAID_LEVEL=${raid_levels[$((raid_choice-1))]:-"RAIDZ"}

# Map user-friendly RAID level names to ZFS-compatible RAID levels
declare -A raid_map
raid_map=(
  ["Single Disk"]=""
  ["Mirror"]="mirror"
  ["RAIDZ"]="raidz"
  ["RAIDZ2"]="raidz2"
  ["RAIDZ3"]="raidz3"
)

# Convert selected RAID level to ZFS-compatible format
ZFS_RAID_LEVEL=${raid_map[$RAID_LEVEL]}
success_messages+=("⚙️ RAID level set to $RAID_LEVEL")
update_success_tracker

# Compression
echo "⚙️ Setting compression algorithm (default: lz4)"
COMPRESSION="lz4"
success_messages+=("⚙️ Compression set to $COMPRESSION")
update_success_tracker

# Create ZFS pool
echo "📁 Creating ZFS pool '$POOL_NAME'"
echo "DEBUG: RAID_LEVEL='$ZFS_RAID_LEVEL'"
echo "DEBUG: DISK_ARGS='$DISK_ARGS'"
echo "DEBUG: Executing: zpool create -f \"$POOL_NAME\" $ZFS_RAID_LEVEL $DISK_ARGS"

if [[ -z "$ZFS_RAID_LEVEL" ]]; then
  # No RAID level (Single Disk)
  if zpool create -f "$POOL_NAME" $DISK_ARGS; then
    echo "📁 Pool '$POOL_NAME' created ✔️"
    success_messages+=("📁 Pool '$POOL_NAME' created")
    update_success_tracker
  else
    echo "📁 Pool '$POOL_NAME' creation failed ❌"
    exit 1
  fi
else
  # RAID level specified
  if zpool create -f "$POOL_NAME" $ZFS_RAID_LEVEL $DISK_ARGS; then
    echo "📁 Pool '$POOL_NAME' created ✔️"
    success_messages+=("📁 Pool '$POOL_NAME' created")
    update_success_tracker
  else
    echo "📁 Pool '$POOL_NAME' creation failed ❌"
    exit 1
  fi
fi

# Add ZFS pool to Proxmox Datacenter Storage
echo "📁 Adding ZFS pool to Proxmox Datacenter Storage"

# Prompt for Storage ID
read -p "Enter a unique Storage ID for this ZFS pool (e.g., zfs_test_storage): " STORAGE_ID
if [[ -z "$STORAGE_ID" ]]; then
  echo "❌ Storage ID cannot be empty."
  exit 1
fi

# Determine available nodes
available_nodes=$(pvecm nodes 2>/dev/null | awk 'NR > 1 {print $2}')  # Get list of cluster nodes
if [[ -z "$available_nodes" ]]; then
  # Not in a cluster; default to the current node
  NODE_NAME=$(hostname)
  echo "ℹ️  This node is not part of a cluster. Defaulting to current node: $NODE_NAME"
else
  # In a cluster; prompt for node selection
  echo "Available Nodes:"
  i=1
  nodes=()
  while read -r node; do
    nodes+=("$node")
    echo "  $i) $node"
    ((i++))
  done <<< "$available_nodes"

  read -p "Select a node by number (default: 1): " node_choice
  node_choice=${node_choice:-1}
  if (( node_choice < 1 || node_choice > ${#nodes[@]} )); then
    echo "❌ Invalid node selection."
    exit 1
  fi
  NODE_NAME=${nodes[$((node_choice-1))]}
fi

# Check if the Storage ID already exists
if pvesm status | grep -qw "$STORAGE_ID"; then
  echo "ℹ️  Storage ID '$STORAGE_ID' already exists."
  read -p "Do you want to overwrite it? (y/N): " overwrite
  if [[ "$overwrite" != "y" && "$overwrite" != "Y" ]]; then
    echo "❌ Operation canceled. Please choose a different Storage ID."
    exit 1
  fi

  read -p "Are you sure you want to overwrite the storage ID '$STORAGE_ID'? Type 'yes' to confirm: " final_confirm
  if [[ "$final_confirm" != "yes" ]]; then
    echo "❌ Operation canceled."
    exit 1
  fi

  echo "⚙️ Removing existing storage '$STORAGE_ID'..."
  if pvesm remove "$STORAGE_ID"; then
    echo "📁 Storage '$STORAGE_ID' removed ✔️"
  else
    echo "❌ Failed to remove existing storage '$STORAGE_ID'."
    exit 1
  fi
fi

# Add the new storage
if pvesm add zfspool "$STORAGE_ID" -pool "$POOL_NAME" -content images,rootdir -nodes "$NODE_NAME"; then
    echo "📁 ZFS pool added to Proxmox storage ✔️"
    success_messages+=("📁 ZFS pool added to Proxmox storage as '$STORAGE_ID'")
    update_success_tracker
else
    echo "❌ Failed to add ZFS pool to Proxmox storage."
    exit 1
fi
