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

# Function to install Certbot
install_certbot() {
    log "Installing Certbot..."
    if command -v apt &>/dev/null; then
        apt update
        apt install -y certbot
    elif command -v yum &>/dev/null; then
        yum install -y epel-release
        yum install -y certbot
    else
        log "Unsupported package manager. Please install Certbot manually."
        exit 1
    fi
    log "Certbot installed successfully."
}

# Function to install Certbot plugins
install_certbot_plugins() {
    log "Available Certbot plugins: nginx, apache, standalone, manual, dns-cloudflare, dns-google, etc."
    log "Please enter the plugins you want to install (comma-separated, e.g., nginx, dns-cloudflare):"
    read -r PLUGINS

    IFS=',' read -r -a PLUGIN_ARRAY <<< "$PLUGINS"
    for PLUGIN in "${PLUGIN_ARRAY[@]}"; do
        PLUGIN=$(echo "$PLUGIN" | xargs)  # Trim whitespace
        if command -v apt &>/dev/null; then
            apt install -y "python3-certbot-$PLUGIN"
        elif command -v yum &>/dev/null; then
            yum install -y "python3-certbot-$PLUGIN"
        fi
        log "Certbot plugin $PLUGIN installed successfully."
    done
}

# Main script execution
log "Starting Certbot setup..."

if prompt_yes_no "Do you want to install Certbot?"; then
    install_certbot
    if prompt_yes_no "Do you want to install any Certbot plugins?"; then
        install_certbot_plugins
    fi
fi

log "Certbot setup complete."
