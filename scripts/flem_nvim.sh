
#!/bin/bash

# Lazy Neovim Script
# 1. Installs Neovim from source on a Linux system
# 2. Cleans up build artifacts
# 3. Clones your Neovim config from Gitea into ~/.config/nvim

echo "🚀 Setting up Neovim from source..."

# Step 1: Check for prerequisites and install if missing
check_and_install() {
    if ! command -v "$1" &> /dev/null; then
        echo "📦 $1 is not installed. Installing..."
        sudo apt update -y && sudo apt install -y "$1"
    else
        echo "✅ $1 is already installed."
    fi
}

# Common build dependencies for Neovim
DEPENDENCIES=(
    git
    ninja-build
    gettext
    libtool
    libtool-bin
    autoconf
    automake
    cmake
    g++
    pkg-config
    unzip
)

echo "🔍 Checking prerequisites..."
for pkg in "${DEPENDENCIES[@]}"; do
    check_and_install "$pkg"
done

# Step 2: Clone Neovim repository
NVIM_DIR="$HOME/neovim-src"
REPO_BRANCH="stable"    # Change to 'nightly' or 'master' if desired

echo "📂 Cloning Neovim repository..."
if [ ! -d "$NVIM_DIR" ]; then
    git clone --branch "$REPO_BRANCH" https://github.com/neovim/neovim.git "$NVIM_DIR"
else
    echo "🔄 Neovim source directory already exists. Pulling latest changes..."
    cd "$NVIM_DIR" || exit
    git fetch
    git checkout "$REPO_BRANCH"
    git pull
    cd ..
fi

# Step 3: Build Neovim from source
echo "⚙️ Building Neovim..."
cd "$NVIM_DIR" || exit
make CMAKE_BUILD_TYPE=RelWithDebInfo

# Step 4: Install Neovim
echo "💿 Installing Neovim..."
sudo make install

# Step 5: Clean up build artifacts and source
echo "🧹 Cleaning up Neovim source directory..."
make clean
cd ..
rm -rf "$NVIM_DIR"

echo "✅ Neovim installation complete!"

# Step 6: Clone Neovim config from Gitea
CONFIG_DIR="$HOME/.config/nvim"
GITEA_REPO_URL="https://gitea.titem.top/titem/config.nvim.git"

echo "🚀 Cloning Neovim configuration from Gitea..."

# Check if ~/.config/nvim exists
if [ -d "$CONFIG_DIR" ]; then
    echo "⚠️  The directory '$CONFIG_DIR' already exists."
    read -p "Do you want to remove it and clone fresh? [y/N]: " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        rm -rf "$CONFIG_DIR"
        echo "✅ Removed old Neovim config directory."
    else
        echo "❌ Aborting clone to avoid overwriting existing config."
        exit 1
    fi
fi

echo "📂 Cloning repo: $GITEA_REPO_URL"
git clone "$GITEA_REPO_URL" "$CONFIG_DIR"

if [ $? -eq 0 ]; then
    echo "✅ Successfully cloned Neovim config into '$CONFIG_DIR'."
else
    echo "❌ Failed to clone Neovim config."
    exit 1
fi

# Optional: Install or sync plugins (uncomment if you want an automated approach)
# echo "🔧 Running Neovim plugin installation/sync..."
# nvim --headless +PackerSync +qa   # For packer
# or
# nvim --headless +Lazy! sync +qa   # For lazy.nvim

echo "🎉 Neovim config setup complete! Launch Neovim with 'nvim'."
