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

# Function to install MariaDB
install_mariadb() {
    if command -v apt &>/dev/null; then
        apt update && apt install -y mariadb-server
    elif command -v yum &>/dev/null; then
        yum install -y mariadb-server
    else
        log "Unsupported package manager. Please install MariaDB manually."
        exit 1
    fi
    log "MariaDB installed successfully."
}

# Function to secure MariaDB installation
secure_mariadb() {
    log "Securing MariaDB installation..."
    mariadb-secure-installation
}

# Function to create a database and user
create_database_user() {
    log "Please enter the MariaDB root password:"
    read -r -s ROOT_PASSWORD
    log "Please enter the name of the new database:"
    read -r DB_NAME
    log "Please enter the username for the new database user:"
    read -r DB_USER
    log "Please enter the password for the new database user:"
    read -r -s DB_PASSWORD
    log "Please enter the host for the new database user (e.g., localhost, %, specific IP):"
    read -r DB_HOST

    mysql -u root -p"$ROOT_PASSWORD" <<EOF
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'$DB_HOST' IDENTIFIED BY '$DB_PASSWORD';
EOF

    if prompt_yes_no "Do you want the user to have all permissions on the database?"; then
        if prompt_yes_no "Do you want to grant the user the GRANT OPTION?"; then
            mysql -u root -p"$ROOT_PASSWORD" <<EOF
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'$DB_HOST' WITH GRANT OPTION;
EOF
        else
            mysql -u root -p"$ROOT_PASSWORD" <<EOF
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'$DB_HOST';
EOF
        fi
    else
        log "Skipping permission assignment for $DB_USER on $DB_NAME."
    fi

    mysql -u root -p"$ROOT_PASSWORD" <<EOF
FLUSH PRIVILEGES;
EOF

    log "Database and user created successfully."
}

# Function to enable MariaDB to start at boot
enable_mariadb_startup() {
    if prompt_yes_no "Do you want MariaDB to start at boot?"; then
        systemctl enable mariadb
        log "MariaDB enabled to start at boot."
    else
        log "MariaDB will not start at boot."
    fi
}

# Main script execution
log "Starting MariaDB setup..."

if prompt_yes_no "Do you want to install MariaDB?"; then
    install_mariadb
fi

if prompt_yes_no "Do you want to secure the MariaDB installation?"; then
    secure_mariadb
fi

while prompt_yes_no "Do you want to create a new database and user?"; do
    create_database_user
done

# Enable MariaDB to start at boot
enable_mariadb_startup

log "MariaDB setup complete."
