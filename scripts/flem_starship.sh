
#!/bin/bash

# Lazy Starship Script
# Installs Starship on a Linux system and creates a starship.toml
# with a custom prompt order using Rose Pine palette.
# It also checks for ~/.bashrc and ~/.zshrc and adds "eval $(starship init ...)" automatically.

echo "🚀 Setting up Starship with Rose Pine palette..."

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

# Step 2: Install Starship if not present
if ! command -v starship &> /dev/null; then
    echo "📦 Installing Starship..."
    curl -fsSL https://starship.rs/install.sh | bash -s -- -y
else
    echo "✅ Starship is already installed."
fi

# Step 3: Create a minimal starship.toml with your specified modules and Rose Pine colors
CONFIG_DIR="$HOME/.config"
STARSHIP_CONFIG="$CONFIG_DIR/starship.toml"

echo "📂 Ensuring $CONFIG_DIR directory exists..."
mkdir -p "$CONFIG_DIR"

if [ -f "$STARSHIP_CONFIG" ]; then
    echo "⚠️  $STARSHIP_CONFIG already exists."
    read -p "Overwrite with Rose Pine config? [y/N]: " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        rm "$STARSHIP_CONFIG"
        echo "✅ Overwriting existing starship.toml."
    else
        echo "❌ Skipping creation of new config."
        exit 0
    fi
fi

echo "📝 Writing starship.toml..."
cat <<EOF > "$STARSHIP_CONFIG"
prompt_order = [
  "username",
  "hostname",
  "custom.localip",
  "directory",
  "git_branch",
  "git_commit",
  "git_state",
  "git_metrics",
  "docker_context",
  "lua",
  "custom.sudo",
  "status",
  "container",
  "line_break",
  "character"
]

[username]
show_always = true
style_user = "bold #9ccfd8"
style_root = "bold #eb6f92"

[hostname]
ssh_only = true
style = "bold #c4a7e7"

[[ custom.localip ]]
command = "hostname -I"
when = 'env_var("SSH_CONNECTION") != ""'
shell = "bash"
style = "bold #f6c177"

[directory]
truncation_length = 3
truncation_symbol = "…/"
style = "#ebbcba"

[docker_context]
symbol = "🐳 "
style = "#9ccfd8"

[lua]
symbol = "🌙 "
style = "#c4a7e7"

[[ custom.sudo ]]
command = '''
if [ "\$(id -u)" -eq 0 ]; then
  echo "ROOT!"
fi
'''
shell = "bash"
style = "bold #eb6f92"

[status]
symbol = "✖"
style = "bold #eb6f92"

[container]
symbol = "⬢ "
style = "bold #6e6a86"

[line_break]
disabled = false

[character]
success_symbol = "[❯](bold #9ccfd8) "
error_symbol = "[✖](bold #eb6f92) "
EOF

echo "✅ Rose Pine starship.toml created at $STARSHIP_CONFIG"

# Step 4: Ensure starship init is in ~/.bashrc and ~/.zshrc

add_starship_init_line() {
    local rcfile="$1"
    local shell_type="$2"
    local init_line="eval \"\$(starship init $shell_type)\""

    if [ -f "$rcfile" ]; then
        # If file exists, check if line is already present
        if grep -Fxq "$init_line" "$rcfile"; then
            echo "✅ Starship init line already in $rcfile"
        else
            echo "$init_line" >> "$rcfile"
            echo "✅ Added starship init line to $rcfile"
        fi
    else
        # If file doesn't exist, prompt to create
        read -p "No $rcfile found. Create it with Starship init line? [y/N]: " answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            echo "$init_line" > "$rcfile"
            echo "✅ Created $rcfile with Starship init line."
        else
            echo "❌ Skipped creating $rcfile."
        fi
    fi
}

add_starship_init_line "$HOME/.bashrc" "bash"
add_starship_init_line "$HOME/.zshrc" "zsh"

echo "🎉 Starship setup complete with Rose Pine palette!"
