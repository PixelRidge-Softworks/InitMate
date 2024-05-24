#!/bin/bash

LOG_FILE="$(dirname "$0")/setup.log"

# ASCII Art Banner
cat << "EOF"
 _____       _ _   __  __       _
|_   _|     (_) | |  \/  |     | |
  | |  _ __  _| |_| \  / | __ _| |_ ___
  | | | '_ \| | __| |\/| |/ _` | __/ _ \
 _| |_| | | | | |_| |  | | (_| | ||  __/
|_____|_| |_|_|\__|_|  |_|\__,_|\__\___|
              By PixelRidge Softworks
EOF

# Log function
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

# Function to check if the script is run as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log "Please run as root"
        exit 1
    fi
}

# Function to check for updates
check_for_updates() {
    SCRIPT_DIR=$(dirname "$0")
    if [ -d "$SCRIPT_DIR/.git" ]; then
        log "Checking for updates..."
        cd "$SCRIPT_DIR" || exit
        git fetch
        LOCAL=$(git rev-parse @)
        REMOTE=$(git rev-parse "@{u}")
        if [ "$LOCAL" != "$REMOTE" ]; then
            log "Updates available. Pulling the latest changes..."
            git pull
            log "Script updated. Please rerun the script."
            exit 0
        else
            log "No updates available."
        fi
    else
        log "This script is not a Git repository. Skipping update check."
    fi
}

# Function to detect the OS and package manager
detect_os() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        OS=$ID
    else
        log "Unable to detect the operating system. Please enter it manually (e.g., ubuntu, debian, centos):"
        read -r OS
    fi

    case $OS in
        ubuntu|debian)
            PKG_MANAGER="apt"
            ;;
        centos|fedora)
            PKG_MANAGER="yum"
            ;;
        *)
            log "Unknown operating system. Please enter the package manager (e.g., apt, yum):"
            read -r PKG_MANAGER
            log "Please enter the command to update the package list (e.g., 'apt update && apt upgrade' or 'yum update'):"
            read -r UPDATE_CMD
            log "Please enter the command to install a package (e.g., 'apt install -y {package_name}' or 'yum install -y {package_name}'):"
            log "Do not include the {package_name} part, just the 'apt install -y' part"
            read -r INSTALL_CMD
            ;;
    esac
}

# Function to prompt for yes/no input
prompt_yes_no() {
    while true; do
        read -r -p "$1 (y/n): " REPLY
        case "$REPLY" in
            [Yy]* ) return 0 ;;
            [Nn]* ) return 1 ;;
            * ) log "Please answer yes or no." ;;
        esac
    done
}

# Function to secure SSH
secure_ssh() {
    log "Securing SSH..."
    SSH_PORT=$((RANDOM % 64512 + 1024))
    log "New SSH port: $SSH_PORT"

    sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
    sed -i "s/PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
    sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
    sed -i "s/#PubkeyAuthentication yes/PubkeyAuthentication yes/" /etc/ssh/sshd_config

    log "Please enter your public key:"
    read -r PUBLIC_KEY

    mkdir -p ~/.ssh
    echo "$PUBLIC_KEY" > ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    chmod 700 ~/.ssh

    systemctl restart sshd
}

# Function to setup firewall
setup_firewall() {
    if command -v ufw &>/dev/null; then
        log "UFW is already installed. Opening SSH port $SSH_PORT."
        ufw allow "$SSH_PORT"/tcp
    elif command -v firewall-cmd &>/dev/null; then
        log "Firewalld is already installed. Opening SSH port $SSH_PORT."
        firewall-cmd --permanent --add-port="$SSH_PORT"/tcp
        firewall-cmd --reload
    else
        if prompt_yes_no "No firewall detected. Do you want to install UFW?"; then
            if [[ $PKG_MANAGER == "apt" ]]; then
                apt update && apt install -y ufw
            elif [[ $PKG_MANAGER == "yum" ]]; then
                yum install -y ufw
            else
                $UPDATE_CMD && $INSTALL_CMD ufw
            fi
            ufw allow "$SSH_PORT"/tcp
            ufw enable
        fi
    fi

    if prompt_yes_no "Do you want to open additional ports?"; then
        log "Please enter the ports and protocols to open (comma-separated, e.g., 80/tcp,443/tcp,8080/udp):"
        read -r ADDITIONAL_PORTS
        IFS=',' read -r -a PORT_ARRAY <<< "$ADDITIONAL_PORTS"
        for PORT_PROTOCOL in "${PORT_ARRAY[@]}"; do
            IFS='/' read -r PORT PROTOCOL <<< "$PORT_PROTOCOL"
            if command -v ufw &>/dev/null; then
                ufw allow "$PORT/$PROTOCOL"
            elif command -v firewall-cmd &>/dev/null; then
                firewall-cmd --permanent --add-port="$PORT/$PROTOCOL"
            fi
        done
        if command -v firewall-cmd &>/dev/null; then
            firewall-cmd --reload
        fi
    fi
}

# Function to perform system update
system_update() {
    if [[ $PKG_MANAGER == "apt" ]]; then
        apt update && apt upgrade -y
    elif [[ $PKG_MANAGER == "yum" ]]; then
        yum update -y
    else
        $UPDATE_CMD && $INSTALL_CMD upgrade -y
    fi
}

# Function to run additional setup
run_additional_setup() {
    if prompt_yes_no "Do you want to run additional setup scripts?"; then
        SCRIPT_DIR=$(dirname "$0")
        if [[ -f "$SCRIPT_DIR/extender.sh" ]]; then
            if [[ ! -x "$SCRIPT_DIR/extender.sh" ]]; then
                log "Making extender.sh executable"
                chmod +x "$SCRIPT_DIR/extender.sh"
            fi
            bash "$SCRIPT_DIR/extender.sh" | tee -a "$LOG_FILE"
        else
            log "No extender.sh script found in the script directory."
        fi
    fi
}

# Function to add additional users
add_users() {
    if prompt_yes_no "Do you want to add additional users?"; then
        while true; do
            log "Enter the username:"
            read -r USERNAME
            log "Enter the password:"
            read -r -s PASSWORD
            useradd -m "$USERNAME"
            echo "$USERNAME:$PASSWORD" | chpasswd

            if prompt_yes_no "Do you want to grant sudo access to $USERNAME?"; then
                usermod -aG sudo "$USERNAME"
                log "$USERNAME has been granted sudo access."
            fi

            if prompt_yes_no "Do you want to add a public key for $USERNAME?"; then
                log "Please enter the public key:"
                read -r PUBLIC_KEY
                su - "$USERNAME" -c "mkdir -p ~/.ssh && echo '$PUBLIC_KEY' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && chmod 700 ~/.ssh"
                log "Public key added for $USERNAME."
            fi

            if ! prompt_yes_no "Do you want to add another user?"; then
                break
            fi
        done
    fi
}

# Function to set up the MOTD
setup_motd() {
    if prompt_yes_no "Do you want to set up the Message of the Day (MOTD)?"; then
        log "Please enter the MOTD content:"
        read -r MOTD_CONTENT
        echo "$MOTD_CONTENT" > /etc/motd
        log "MOTD has been set."
    fi
}

# Function to prompt for a reboot
prompt_reboot() {
    if prompt_yes_no "Do you want to reboot the system now?"; then
        log "Rebooting the system..."
        reboot
    else
        log "Reboot skipped. Please remember to reboot the system later."
    fi
}

# Main script execution
check_root
check_for_updates
detect_os
log "Detected OS: $OS, Package Manager: $PKG_MANAGER"
if ! prompt_yes_no "Is this correct?"; then
    log "Please enter the correct OS and package manager:"
    read -r OS PKG_MANAGER
    if [[ $PKG_MANAGER != "apt" && $PKG_MANAGER != "yum" ]]; then
        log "Please enter the command to update the package list (e.g., 'apt update' or 'yum update'):"
        read -r UPDATE_CMD
        log "Please enter the command to install a package (e.g., 'apt install -y' or 'yum install -y'):"
        read -r INSTALL_CMD
    fi
fi

if prompt_yes_no "Do you want to secure SSH?"; then
    secure_ssh
fi

if prompt_yes_no "Do you want to set up a firewall?"; then
    setup_firewall
fi

if prompt_yes_no "Do you want to perform a system update?"; then
    system_update
fi

log "Setup complete. Summary of actions performed:"
[[ $SECURE_SSH == "yes" ]] && log "- SSH secured on port $SSH_PORT"
[[ $SETUP_FIREWALL == "yes" ]] && log "- Firewall configured with SSH port $SSH_PORT"
[[ $UPDATE_SYSTEM == "yes" ]] && log "- System updated"

# Run additional setup if requested
run_additional_setup

# Add additional users if requested
add_users

# Set up MOTD if requested
setup_motd

# Prompt for reboot
prompt_reboot
