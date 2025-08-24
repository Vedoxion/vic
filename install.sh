#!/bin/bash
# VictusCloud Installer Script

# Colors
BLUE="\e[34m"
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

# Progress bar function
progress_bar() {
    local duration=$1
    local i=0
    while [ $i -le $duration ]; do
        printf "\r${BLUE}[%-${duration}s] %d%%${RESET}" $(printf "#%.0s" $(seq 1 $i)) $((i * 100 / duration))
        sleep 0.1
        ((i++))
    done
    echo ""
}

# Banner
echo -e "${BLUE}"
echo "===================================="
echo "     VictusCloud Auto Installer     "
echo "===================================="
echo -e "${RESET}"

# Check for git
if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}[INFO]${RESET} Git not found. Installing..."
    pkg install -y git || apt-get install -y git
fi

# Clone repo
echo -e "${BLUE}[STEP]${RESET} Cloning repository..."
git clone https://github.com/Vedoxion/vic.git vic-install
cd vic-install || exit

# Install PHP
if ! command -v php &> /dev/null; then
    echo -e "${YELLOW}[INFO]${RESET} PHP not found. Installing..."
    pkg install -y php || apt-get install -y php
else
    echo -e "${GREEN}[OK]${RESET} PHP already installed."
fi

# Install Node.js
if ! command -v npm &> /dev/null; then
    echo -e "${YELLOW}[INFO]${RESET} Node.js not found. Installing..."
    pkg install -y nodejs || apt-get install -y nodejs npm
else
    echo -e "${GREEN}[OK]${RESET} Node.js already installed."
fi

# Progress bar (randomly show sometimes)
if [ $((RANDOM % 2)) -eq 0 ]; then
    echo -e "${BLUE}[STEP]${RESET} Preparing environment..."
    progress_bar 20
fi

# Install Node dependencies
echo -e "${BLUE}[STEP]${RESET} Installing npm dependencies..."
npm install

# Migration confirmation
echo -e "${YELLOW}[QUESTION]${RESET} Do you want to run database migration? (y/n)"
read -r choice
if [[ "$choice" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}[STEP]${RESET} Running migration..."
    php artisan migrate --force
    echo -e "${GREEN}[OK]${RESET} Migration complete."
else
    echo -e "${RED}[SKIPPED]${RESET} Migration skipped."
fi

# Finish
echo -e "${GREEN}===================================="
echo " VictusCloud installed successfully!"
echo "====================================${RESET}"
