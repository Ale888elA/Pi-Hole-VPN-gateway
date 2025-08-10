#!/bin/bash
# Script by Ale888elA
# https://github.com/Ale888elA/Pi-Hole-VPN-gateway

set -e

############################################
# VARIABLES TO SET
############################################

# Name assigned to remote during rclone configuration
# should coincide with name of remote folder for your backup files
#REMOTE_FOLDER="wireguard_backup"
REMOTE_FOLDER="rpi_backup"

############################################
# AUTO-DETECTED VARIABLES
############################################
# Rclone configuration file path
RCLONE_CONF="/home/$(logname)/.config/rclone/rclone.conf"

# Remote cloud storage service chosen during rclone configuration
if [[ -f "$RCLONE_CONF" ]]; then
    # Take first name of cloud storage from config file  (you can change head -n 1 if you want to choose manually)
    REMOTE_SERVICE=$(grep -oP '^\[\K[^\]]+' "$RCLONE_CONF" | head -n 1)

else
    echo "⚠️  No rclone configuration found. Please configure rclone first."
    exit 1
fi

# Rclone Remote
RCLONE_REMOTE="$REMOTE_SERVICE:$REMOTE_FOLDER"

# BACKUP PASSWORD FILE
PASS_FILE="/root/.backup_pass"
if [[ ! -f "$PASS_FILE" ]]; then
    echo "Enter a password to protect backups:"
    read -rs PASS
    echo "$PASS" > "$PASS_FILE"
    chmod 600 "$PASS_FILE"
else
    PASS=$(cat "$PASS_FILE")
fi

############################################
# BACKUP DIRECTORIES AND FILES
############################################
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_NAME="rpi_backup_$TIMESTAMP.zip"
TEMP_DIR="/tmp/rpi_backup"

echo "📦 Creating backup directory..."
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# 1. WireGuard configuration
if command -v wg >/dev/null; then
    mkdir -p "$TEMP_DIR/wireguard"
    cp -r /etc/wireguard "$TEMP_DIR/wireguard"
fi

# 2. Pi-hole configuration
if command -v pihole >/dev/null; then
    mkdir -p "$TEMP_DIR/pihole"
    mkdir -p "$TEMP_DIR/dnsmasq.d"

    # Copy Pi-hole config excluding gravity_old.db and other cache files
    rsync -a --exclude 'gravity_old.db' --exclude '*.log' --exclude '*.tmp' /etc/pihole/ "$TEMP_DIR/pihole/"
    cp -r /etc/dnsmasq.d "$TEMP_DIR/dnsmasq.d"
fi


# 3. ddclient configuration
if [[ -f /etc/ddclient.conf ]]; then
    cp /etc/ddclient.conf "$TEMP_DIR/"
fi

# 4. SSH authorized keys
mkdir -p "$TEMP_DIR/ssh"
cp "/home/$(logname)/.ssh/authorized_keys" "$TEMP_DIR/ssh/"

# 5. Scripts in /usr/local/bin
mkdir -p "$TEMP_DIR/usr_local_bin"
cp -r /usr/local/bin/* "$TEMP_DIR/usr_local_bin/" 2>/dev/null || true

# 6. unattended-upgrades configuration
if [[ -d /etc/apt/apt.conf.d ]]; then
    mkdir -p "$TEMP_DIR/unattended-upgrades"
    cp /etc/apt/apt.conf.d/20auto-upgrades "$TEMP_DIR/unattended-upgrades/" 2>/dev/null || true
    cp /etc/apt/apt.conf.d/50unattended-upgrades "$TEMP_DIR/unattended-upgrades/" 2>/dev/null || true
fi

# 7. Cron jobs
mkdir -p "$TEMP_DIR/cron"
crontab -u "$RPI_USERID" -l > "$TEMP_DIR/cron/$RPI_USERID.cron" 2>/dev/null || true
crontab -u root -l > "$TEMP_DIR/cron/root.cron" 2>/dev/null || true

# 8. watchdog service and timer
if [[ -f /etc/systemd/system/watchdog.service ]]; then
    cp /etc/systemd/system/watchdog.service "$TEMP_DIR/"
fi
if [[ -f /etc/systemd/system/watchdog.timer ]]; then
    cp /etc/systemd/system/watchdog.timer "$TEMP_DIR/"
fi

# 9. nftables configuration
if [[ -f /etc/nftables.conf ]]; then
    cp /etc/nftables.conf "$TEMP_DIR/"
fi

# 10. rclone configuration
if [[ -f "$RCLONE_CONF" ]]; then
    mkdir -p "$TEMP_DIR/rclone"
    cp "$RCLONE_CONF" "$TEMP_DIR/rclone/"
fi

############################################
# CREATE PASSWORD-PROTECTED ARCHIVE
############################################
echo "🔐 Creating encrypted backup archive..."
cd "$TEMP_DIR"
zip -r -P "$PASS" "/tmp/$BACKUP_NAME" . > /dev/null
cd -

############################################
# UPLOAD TO CLOUD USING RCLONE
############################################
echo "☁️ Uploading $BACKUP_NAME to cloud storage ($RCLONE_REMOTE)..."
rclone copy "/tmp/$BACKUP_NAME" "$RCLONE_REMOTE" --quiet --config "/home/$(logname)/.config/rclone/rclone.conf"

############################################
# CLEANUP
############################################
rm -rf "$TEMP_DIR"
rm -f "/tmp/$BACKUP_NAME"

# === Delete Old Backups from cloud storage ===
echo "🗑️  Removing remote backups older than 15 days..."
rclone delete --min-age 15d "$RCLONE_REMOTE" --config "/home/$(logname)/.config/rclone/rclone.conf"

echo "✅ Backup completed and uploaded to $RCLONE_REMOTE"

