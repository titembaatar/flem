#!/bin/bash

# Install tree if not already installed
echo "🌳 Installing 'tree' package to display directory structure..."
sudo apt update -y
sudo apt install -y tree

# Create the directory structure under /data
echo "📂 Creating /data directory structure..."
mkdir -p /data/{documents,photos,media/{books/{audiobooks,ebooks},movies,music,podcasts,shows/{anime,tv}},torrents/{books/{audiobooks,ebooks},movies,music/{slskd,incomplete},podcasts,shows/{anime,tv}},usenet/{incomplete,complete/{books/{audiobooks,ebooks},movies,music,podcasts,shows/{anime,tv}}}}

# Create the directory structure under /config
echo "📂 Creating /config directory structure..."
mkdir -p /config/{config,docker-compose}

# Display the created directory trees
echo "🌲 Displaying /data directory structure:"
tree /data

echo "🌲 Displaying /config directory structure:"
tree /config

echo "🎉 Directories have been successfully created !"
