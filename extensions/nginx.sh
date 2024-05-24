#!/bin/bash

LOG_FILE="$(dirname "$(dirname "$0")")/setup.log"

# Log function
log() {
    echo "$1" | tee -a "$LOG_FILE"
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

# Function to install Nginx
install_nginx() {
    log "Installing Nginx..."
    if command -v apt &>/dev/null; then
        apt update
        apt install -y nginx
    elif command -v yum &>/dev/null; then
        yum install -y epel-release
        yum install -y nginx
    else
        log "Unsupported package manager. Please install Nginx manually."
        exit 1
    fi
    log "Nginx installed successfully."
}

# Function to start Nginx service
start_nginx() {
    log "Starting Nginx service..."
    systemctl start nginx
    log "Nginx service started."
}

# Function to enable Nginx service at boot
enable_nginx_boot() {
    if prompt_yes_no "Do you want Nginx to start at boot?"; then
        systemctl enable nginx
        log "Nginx service enabled to start at boot."
    else
        log "Nginx service will not start at boot."
    fi
}

# Main script execution
log "Starting Nginx setup..."

if prompt_yes_no "Do you want to install Nginx?"; then
    install_nginx
    start_nginx
    enable_nginx_boot
fi

log "Nginx setup complete."
