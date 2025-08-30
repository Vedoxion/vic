#!/bin/bash
# Victus Cloud Setup Script
# Made by Shady

echo "======================================"
echo "        Made by Shady 🚀"
echo "======================================"

# Install prerequisites
echo "[1/7] Installing prerequisites..."
sudo apt-get install -y ca-certificates curl gnupg

# Add NodeSource GPG key
echo "[2/7] Adding NodeSource GPG key..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

# Add Node.js 20 repo
echo "[3/7] Adding Node.js 20.x repo..."
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | \
  sudo tee /etc/apt/sources.list.d/nodesource.list

# Update and install Node.js
echo "[4/7] Installing Node.js 20..."
sudo apt-get update
sudo apt-get install -y nodejs

# Install Yarn globally
echo "[5/7] Installing Yarn..."
sudo npm i -g yarn

# Navigate to Pterodactyl directory & run yarn
echo "[6/7] Installing dependencies in /var/www/pterodactyl..."
cd /var/www/pterodactyl || { echo "Directory /var/www/pterodactyl not found!"; exit 1; }
yarn

# Install other dependencies
echo "[7/7] Installing zip/unzip/git/curl/wget..."
sudo apt install -y zip unzip git curl wget

# Download latest Blueprint Framework release
echo "[*] Downloading Blueprint Framework release..."
LATEST_URL=$(curl -s https://api.github.com/repos/BlueprintFramework/framework/releases/latest | grep 'browser_download_url' | cut -d '"' -f 4)
wget "$LATEST_URL" -O release.zip

# Move and extract release
mv release.zip /var/www/pterodactyl/release.zip
unzip -o release.zip

# Setup Blueprint config
touch /var/www/pterodactyl/.blueprintrc
chmod +x blueprint.sh

# Run Blueprint installer
echo "[*] Running Blueprint installer..."
bash blueprint.sh

echo "======================================"
echo "   ✅ Setup Complete - Made by Shady"
echo "======================================"
