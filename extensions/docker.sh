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

# Function to install Docker
install_docker() {
    log "Installing Docker..."
    if command -v apt &>/dev/null; then
        apt update
        apt install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        apt update
        apt install -y docker-ce
    elif command -v yum &>/dev/null; then
        yum install -y yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io
    else
        log "Unsupported package manager. Please install Docker manually."
        exit 1
    fi
    log "Docker installed successfully."
}

# Function to start Docker service
start_docker() {
    log "Starting Docker service..."
    systemctl start docker
    log "Docker service started."
}

# Function to enable Docker service at boot
enable_docker_boot() {
    if prompt_yes_no "Do you want Docker to start at boot?"; then
        systemctl enable docker
        log "Docker service enabled to start at boot."
    else
        log "Docker service will not start at boot."
    fi
}

# Function to add user to Docker group
add_user_to_docker_group() {
    log "Please enter the username to add to the Docker group:"
    read -r USERNAME
    usermod -aG docker "$USERNAME"
    log "User $USERNAME added to the Docker group. You may need to log out and log back in for this change to take effect."
}

# Main script execution
log "Starting Docker setup..."

if prompt_yes_no "Do you want to install Docker?"; then
    install_docker
    start_docker
    enable_docker_boot
    if prompt_yes_no "Do you want to add a user to the Docker group?"; then
        add_user_to_docker_group
    fi
fi

log "Docker setup complete."
