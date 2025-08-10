#!/bin/bash
set -e

############################################
# SETTINGS
############################################
PASS_FILE="/root/.backup_pass"
RCLONE_CONF="/home/$(logname)/.config/rclone/rclone.conf"
TEMP_DIR="/tmp/rpi_restore"

# Backup sections
SECTIONS=("unattended-upgrades" "SSH" "nftables" "Pi-hole" "WireGuard" "ddclient" "scripts" "watchdog" "cron jobs" "rclone")

############################################
# FUNCTIONS
############################################
install_packages() {
    echo "📦 Installing required packages..."
    sudo apt update
    sudo apt install -y zip unzip unattended-upgrades bsd-mailx nftables wireguard ddclient qrencode rclone curl wget
    curl -sSL https://install.pi-hole.net | bash
}

enable_ip_forwarding_disable_ipv6() {
    echo "🔧 Enabling IP forwarding..."
    sudo sysctl -w net.ipv4.ip_forward=1
    sudo sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

    echo "🚫 Disabling IPv6..."
    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
    sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
}

choose_backup_source() {
    echo "Choose backup source:"
    select src in "Cloud (rclone)" "URL" "Local file"; do
        case $REPLY in
            1)
                if [[ -f "$RCLONE_CONF" ]]; then
                    echo "Downloading latest backup from cloud..."
                    REMOTE_SERVICE=$(grep -oP '^\[\K[^\]]+' "$RCLONE_CONF" | head -n 1)
                    REMOTE_FOLDER="rpi_backup"
                    RCLONE_REMOTE="$REMOTE_SERVICE:$REMOTE_FOLDER"
                    rclone copy "$RCLONE_REMOTE" /tmp --config "$RCLONE_CONF" --include "*.zip" --max-age 30d
                    BACKUP_FILE=$(ls -t /tmp/rpi_backup_*.zip | head -n 1)
                    break
                else
                    echo "❌ Rclone config not found!"
                fi
                ;;
            2)
                read -rp "Enter backup file URL: " BACKUP_URL
                BACKUP_FILE="/tmp/restore_backup.zip"
                wget -O "$BACKUP_FILE" "$BACKUP_URL"
                break
                ;;
            3)
                echo "Available local backups in /home/$(logname):"
                select f in /home/$(logname)/*.zip; do
                    BACKUP_FILE="$f"
                    break
                done
                break
                ;;
            *)
                echo "Invalid choice."
                ;;
        esac
    done
}

restore_section() {
    local section="$1"
    echo "♻️ Restoring $section..."
    case "$section" in
        unattended-upgrades)
            cp -r "$TEMP_DIR/unattended-upgrades"/* "/etc/apt/apt.conf.d/" 2>/dev/null || true
            ;;
        SSH)
            mkdir -p "/home/$(logname)/.ssh"
            cp "$TEMP_DIR/ssh/authorized_keys" "/home/$(logname)/.ssh/" 2>/dev/null || true
            ;;
        nftables)
            cp "$TEMP_DIR/nftables.conf" "/etc/nftables.conf" 2>/dev/null || true
            ;;
        Pi-hole)
            cp -r "$TEMP_DIR/pihole" "/etc/" 2>/dev/null || true
            cp -r "$TEMP_DIR/dnsmasq.d" "/etc/" 2>/dev/null || true
            ;;
        WireGuard)
            cp -r "$TEMP_DIR/wireguard" "/etc/" 2>/dev/null || true
            ;;
        ddclient)
            cp "$TEMP_DIR/ddclient.conf" "/etc/" 2>/dev/null || true
            ;;
        scripts)
            cp -r "$TEMP_DIR/usr_local_bin"/* "/usr/local/bin/" 2>/dev/null || true
            ;;
        watchdog)
            cp "$TEMP_DIR/watchdog.service" "/etc/systemd/system/" 2>/dev/null || true
            cp "$TEMP_DIR/watchdog.timer" "/etc/systemd/system/" 2>/dev/null || true
            ;;
        cron\ jobs)
            crontab -u "$(logname)" "$TEMP_DIR/cron/$(logname).cron" 2>/dev/null || true
            crontab -u root "$TEMP_DIR/cron/root.cron" 2>/dev/null || true
            ;;
        rclone)
            mkdir -p "/home/$(logname)/.config/rclone"
            cp "$TEMP_DIR/rclone/rclone.conf" "/home/$(logname)/.config/rclone/" 2>/dev/null || true
            ;;
    esac
}

############################################
# MAIN SCRIPT
############################################

if [[ ! -f "$PASS_FILE" ]]; then
    echo "🔑 No password found. Enter backup password:"
    read -rs PASS
    echo "$PASS" > "$PASS_FILE"
    chmod 600 "$PASS_FILE"
    choose_backup_source
    install_packages
    mkdir -p "$TEMP_DIR"
    unzip -P "$PASS" "$BACKUP_FILE" -d "$TEMP_DIR"
    echo "🔄 Performing FULL restore..."
    for s in "${SECTIONS[@]}"; do restore_section "$s"; done
    enable_ip_forwarding_disable_ipv6
else
    PASS=$(cat "$PASS_FILE")
    choose_backup_source
    mkdir -p "$TEMP_DIR"
    unzip -P "$PASS" "$BACKUP_FILE" -d "$TEMP_DIR"
    echo "Choose restore option:"
    echo "1-10 = Single section, 11 = FULL restore"
    select opt in "${SECTIONS[@]}" "FULL_RESTORE"; do
        if [[ "$REPLY" == "666" ]]; then
            install_packages
            for s in "${SECTIONS[@]}"; do restore_section "$s"; done
            enable_ip_forwarding_disable_ipv6
        fi
        # === Enable & restart Pi-hole ===
	    if command -v pihole >/dev/null; then
    		echo "⚙️  Enabling Pi-hole..."
    		sudo systemctl enable --now pihole-FTL
    		sudo pihole restartdns
	    fi

	    # === Enable & restart WireGuard ===
	    if command -v wg >/dev/null; then
    		echo "⚙️  Enabling WireGuard..."
    		sudo systemctl enable --now wg-quick@wg0
	    fi

	    # === Enable & restart nftables ===
	    if command -v nft >/dev/null; then
    		echo "⚙️  Enabling nftables..."
    		sudo systemctl enable --now nftables
	    fi

	    # === Enable & restart watchdog ===
	    if [[ -f /etc/systemd/system/watchdog.service ]]; then
    		echo "⚙️  Enabling watchdog..."
    		sudo systemctl enable --now watchdog.service
	    fi
	    
	    if [[ -f /etc/systemd/system/watchdog.timer ]]; then
    		sudo systemctl enable --now watchdog.timer
	    break
        elif [[ "$REPLY" -ge 1 && "$REPLY" -le ${#SECTIONS[@]} ]]; then
            restore_section "${SECTIONS[$REPLY-1]}"
        else
            echo "Invalid choice"
        fi
    done
fi

#Cleaning temo folder
read -rp "🔄 Clean temp folder? (y/n): " clean_temp
[[ "$clean_temp" =~ ^[Yy]$ ]] && sudo rm -r /tmp/rpi_restore/*

#Rebooting system
read -rp "🔄 Reboot system now? (y/n): " reboot_choice
[[ "$reboot_choice" =~ ^[Yy]$ ]] && sudo reboot
