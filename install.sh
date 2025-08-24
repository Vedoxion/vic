#!/data/data/com.termux/files/usr/bin/bash
# Fancy Arix Theme Installer for Pterodactyl (Termux)

PTERO_PATH="/var/www/pterodactyl"
ARIX_PATH="$HOME/arix-theme"
GIT_URL="https://github.com/YOUR_USERNAME/arix-theme.git"   # <-- change this

# Colors
BLUE="\033[1;34m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
NC="\033[0m" # reset color

# Loading bar function
loading_bar() {
    echo -ne "${BLUE}>>> $1 ["
    for i in {1..20}; do
        echo -ne "#"
        sleep 0.05
    done
    echo -e "]${NC}"
}

echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}     Arix v1.2 Theme Installer (Pro)     ${NC}"
echo -e "${BLUE}=========================================${NC}"

# Step 1 - Clone repo
loading_bar "Cloning GitHub repo"
rm -rf "$ARIX_PATH"
git clone "$GIT_URL" "$ARIX_PATH" || { echo -e "${RED}ERROR: Git clone failed!${NC}"; exit 1; }

# Step 2 - Backup old files
read -p ">>> Do you want to backup old files before install? (y/n): " choice
if [[ "$choice" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}>>> Backing up old panel files...${NC}"
    mkdir -p "$HOME/ptero-backup"
    cp -r "$PTERO_PATH/public" "$HOME/ptero-backup/public-$(date +%F-%H%M)"
    cp -r "$PTERO_PATH/resources/views" "$HOME/ptero-backup/views-$(date +%F-%H%M)"
    echo -e "${GREEN}>>> Backup complete!${NC}"
else
    echo -e "${YELLOW}>>> Skipping backup...${NC}"
fi

# Step 3 - Copy files
loading_bar "Copying theme files"
cp -r "$ARIX_PATH/pterodactyl/"* "$PTERO_PATH/"

# Step 4 - Run migrations
read -p ">>> Run PHP database migrations? (y/n): " migrate_choice
if [[ "$migrate_choice" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}>>> Running: php artisan migrate --force${NC}"
    cd "$PTERO_PATH" || exit
    php artisan migrate --force \
        && echo -e "${GREEN}>>> Migrations successful!${NC}" \
        || echo -e "${RED}>>> Migration failed!${NC}"
else
    echo -e "${YELLOW}>>> Skipping migrations...${NC}"
fi

# Step 5 - Clear caches
loading_bar "Clearing PHP caches"
php artisan view:clear
php artisan config:clear
php artisan cache:clear

# Step 6 - Rebuild frontend
read -p ">>> Run NPM build (install + production)? (y/n): " build_choice
if [[ "$build_choice" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}>>> Running: npm install${NC}"
    npm install

    echo -e "${BLUE}>>> Running: npm run build:production${NC}"
    npm run build:production \
        && echo -e "${GREEN}>>> Frontend build complete!${NC}" \
        || echo -e "${RED}>>> Frontend build failed!${NC}"
else
    echo -e "${YELLOW}>>> Skipping frontend build...${NC}"
fi

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}✅ Arix v1.2 installed successfully!${NC}"
echo -e "${YELLOW}Restart your panel with:${NC}"
echo -e "   pkill -f artisan && php artisan serve --host=0.0.0.0 --port=8080"
echo -e "${GREEN}=========================================${NC}"
