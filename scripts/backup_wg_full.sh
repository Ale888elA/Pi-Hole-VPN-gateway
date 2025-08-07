#!/bin/bash

# RPI Variable to set
RPI_USERID="userID"
# RCLONE variables to set
REMOTE_TYPE="gdrive"
REMOTE_NAME="mario_backup"
# === CONFIGURATION ===
DATE=$(date +"%Y%m%d")
TEMP_DIR="/tmp/wg_backup_$DATE"
BACKUP_NAME="wg_full_backup_$DATE.zip"
BACKUP_PASS=$(< /root/.backup_pass)
RCLONE_REMOTE="$REMOTE_TYPE:$REMOTE_NAME"

# Create temp dir
mkdir -p "$TEMP_DIR"

echo "🔄 Starting secure system backup..."

# 1. WireGuard
cp -r /etc/wireguard "$TEMP_DIR/wireguard"

# 2. nftables
nft list ruleset > "$TEMP_DIR/nftables.rules"
[ -f /etc/nftables.conf ] && cp /etc/nftables.conf "$TEMP_DIR/"

# 3. Pi-hole
if command -v pihole >/dev/null; then
    mkdir -p "$TEMP_DIR/pihole"
    rsync -a --exclude="gravity_old.db" /etc/pihole/ "$TEMP_DIR/pihole/"
    cp -r /etc/dnsmasq.d "$TEMP_DIR/dnsmasq.d"
fi

# 4. DNS
cp /etc/resolv.conf "$TEMP_DIR/"

# 5. Custom scripts
cp -r /usr/local/bin "$TEMP_DIR/usr_local_bin"

# 6. ddclient
[ -f /etc/ddclient.conf ] && cp /etc/ddclient.conf "$TEMP_DIR/"

# 7. SSH
cp /etc/ssh/sshd_config "$TEMP_DIR/"
mkdir -p "$TEMP_DIR/ssh_keys"
for user in /home/*; do
    u=$(basename "$user")
    if [ -f "$user/.ssh/authorized_keys" ]; then
        mkdir -p "$TEMP_DIR/ssh_keys/$u"
        cp "$user/.ssh/authorized_keys" "$TEMP_DIR/ssh_keys/$u/"
    fi
done

# 8. Metadata
hostnamectl > "$TEMP_DIR/system_info.txt"
ip a > "$TEMP_DIR/ip_info.txt"
wg show > "$TEMP_DIR/wg_status.txt" 2>/dev/null

# === Create Encrypted Archive ===
cd /tmp || exit 1
zip -r -P "$BACKUP_PASS" "$BACKUP_NAME" "wg_backup_$DATE" >/dev/null

# === Upload to cloud storage ===
echo "☁️ Uploading $BACKUP_NAME to Google Drive ($RCLONE_REMOTE)..."
rclone copy "$BACKUP_NAME" "$RCLONE_REMOTE" --quiet --config "/home/$RPI_USERID/.config/rclone/rclone.conf"

# === Cleanup Local ===
rm -rf "$TEMP_DIR" "/tmp/$BACKUP_NAME"
echo "🧹 Temp files cleaned."

# === Delete Old Backups from cloud storage ===
echo "🗑️  Removing remote backups older than 15 days..."
rclone delete --min-age 15d "$RCLONE_REMOTE" --config "/home/$RPI_USERID/.config/rclone/rclone.conf"

echo "✅ Backup complete and uploaded securely."
