#!/data/data/com.termux/files/usr/bin/bash
# Arix v1.2 Launcher Installer (Termux)

PTERO_PATH="/var/www/pterodactyl"
ARIX_PATH="$HOME/vic"
GIT_URL="https://github.com/Vedoxion/vic.git"

# Colors
BLUE="\033[1;34m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
NC="\033[0m" # reset color

loading_bar() {
    echo -ne "${BLUE}>>> $1 ["
    for i in {1..20}; do
        echo -ne "#"
        sleep 0.05
    done
    echo -e "]${NC}"
}

echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}   Arix v1.2 Installer via GitHub Repo   ${NC}"
echo -e "${BLUE}=========================================${NC}"

# Step 1 - Clone or Update Repo
if [ -d "$ARIX_PATH" ]; then
    echo -e "${YELLOW}>>> Repo already exists, updating...${NC}"
    cd "$ARIX_PATH" && git pull
else
    loading_bar "Cloning GitHub repo"
    git clone "$GIT_URL" "$ARIX_PATH" || { echo -e "${RED}ERROR: Git clone failed!${NC}"; exit 1; }
fi

# Step 2 - Backup Option
read -p ">>> Backup old panel files before install? (y/n): " backup_choice
if [[ "$backup_choice" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}>>> Backing up old panel files...${NC}"
    mkdir -p "$HOME/ptero-backup"
    cp -r "$PTERO_PATH/public" "$HOME/ptero-backup/public-$(date +%F-%H%M)"
    cp -r "$PTERO_PATH/resources/views" "$HOME/ptero-backup/views-$(date +%F-%H%M)"
    echo -e "${GREEN}>>> Backup complete!${NC}"
else
    echo -e "${YELLOW}>>> Skipping backup...${NC}"
fi

# Step 3 - Run installer from repo
cd "$ARIX_PATH" || exit
echo -e "${BLUE}>>> Running repo installer: install.sh${NC}"
chmod +x install.sh
./install.sh

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}✅ Arix v1.2 installed successfully!${NC}"
echo -e "${YELLOW}Restart your panel with:${NC}"
echo -e "   pkill -f artisan && php artisan serve --host=0.0.0.0 --port=8080"
echo -e "${GREEN}=========================================${NC}"
