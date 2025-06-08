
#!/bin/bash

# iBilling - Professional Voice Billing System Installation Script for Debian 12
# Refactored to use modular scripts
# Exit on error
set -e

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utility functions
source "${SCRIPT_DIR}/scripts/utils.sh"

# Make all scripts executable
chmod +x "${SCRIPT_DIR}/scripts/"*.sh

check_and_setup_sudo() {
    print_status "Checking sudo access..."
    
    if sudo -n true 2>/dev/null; then
        print_status "✓ User has sudo access"
        return 0
    fi
    
    print_warning "Current user ($USER) does not have sudo access"
    
    if ! command -v sudo >/dev/null 2>&1; then
        print_error "sudo is not installed on this system"
        print_status "Installing sudo package..."
        su - root -c "apt update && apt install -y sudo"
    fi
    
    if groups "$USER" | grep -q '\bsudo\b'; then
        print_warning "User is in sudo group but sudo access is not working"
        print_status "This might be a sudo configuration issue"
    else
        print_status "User is not in sudo group"
    fi
    
    echo -n "Please enter root password to configure sudo access for $USER: "
    read -s ROOT_PASSWORD
    echo ""
    
    print_status "Configuring sudo access..."
    
    cat > /tmp/fix_sudo.sh << 'SCRIPT_EOF'
#!/bin/bash
USER_TO_FIX="$1"

groupadd -f sudo
usermod -aG sudo "$USER_TO_FIX"

if ! grep -q "^%sudo" /etc/sudoers; then
    echo "%sudo   ALL=(ALL:ALL) ALL" >> /etc/sudoers
fi

visudo -c

if groups "$USER_TO_FIX" | grep -q '\bsudo\b'; then
    echo "✓ User $USER_TO_FIX successfully added to sudo group"
    exit 0
else
    echo "✗ Failed to add user $USER_TO_FIX to sudo group"
    exit 1
fi
SCRIPT_EOF

    chmod +x /tmp/fix_sudo.sh
    
    if echo "$ROOT_PASSWORD" | su - root -c "/tmp/fix_sudo.sh $USER"; then
        print_status "✓ Sudo access configured successfully"
        rm -f /tmp/fix_sudo.sh
        print_warning "IMPORTANT: You must start a NEW terminal session for sudo to work"
        print_status "Options to activate sudo access:"
        echo "  1. Run: exec su - $USER"
        echo "  2. Or close this terminal and open a new SSH session"
        echo "  3. Or run: newgrp sudo && exec bash"
        echo ""
        print_status "After starting a new session, run this script again"
        exit 0
    else
        print_error "Failed to configure sudo access"
        rm -f /tmp/fix_sudo.sh
        exit 1
    fi
}

install_system_dependencies() {
    print_status "Updating system and installing dependencies..."
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y mariadb-server git curl unixodbc unixodbc-dev libmariadb-dev odbc-mariadb \
        wget build-essential subversion libjansson-dev libxml2-dev uuid-dev libsqlite3-dev \
        libssl-dev libncurses5-dev libedit-dev libsrtp2-dev libspandsp-dev libtiff-dev \
        libfftw3-dev libvorbis-dev libspeex-dev libopus-dev libgsm1-dev libnewt-dev \
        libpopt-dev libical-dev libjack-dev liblua5.2-dev libsnmp-dev libcorosync-common-dev \
        libradcli-dev libneon27-dev libgmime-3.0-dev liburiparser-dev libxslt1-dev \
        python3-dev python3-pip nginx certbot python3-certbot-nginx libcurl4-openssl-dev
}

# Main installation function
main() {
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
       print_error "This script should not be run as root for security reasons"
       print_status "Please run as a regular user. The script will ask for sudo when needed."
       exit 1
    fi

    # Check and setup sudo access
    check_and_setup_sudo

    print_status "Starting iBilling - Professional Voice Billing System installation on Debian 12..."

    # 1. Create directory structure
    print_status "Creating directory structure..."
    create_directory "/opt/billing/web"
    create_directory "/opt/billing/logs"
    create_directory "/opt/billing/backend"
    create_directory "/var/lib/asterisk/agi-bin" "asterisk:asterisk"
    create_directory "/etc/asterisk/backup"

    # 2. Install system dependencies
    install_system_dependencies

    # 3. Generate passwords
    MYSQL_ROOT_PASSWORD=$(generate_password)
    ASTERISK_DB_PASSWORD=$(generate_password)

    # 4. Setup database using modular script
    print_status "Setting up database..."
    source "${SCRIPT_DIR}/scripts/setup-database.sh"
    setup_database "${MYSQL_ROOT_PASSWORD}" "${ASTERISK_DB_PASSWORD}"

    # 5. Setup ODBC using modular script
    print_status "Setting up ODBC..."
    source "${SCRIPT_DIR}/scripts/setup-odbc.sh"
    setup_odbc "${ASTERISK_DB_PASSWORD}"

    # 6. Install and configure Asterisk using modular script
    print_status "Installing Asterisk..."
    source "${SCRIPT_DIR}/scripts/install-asterisk.sh"
    install_asterisk "${ASTERISK_DB_PASSWORD}"

    # 7. Setup web stack using modular script
    print_status "Setting up web stack..."
    source "${SCRIPT_DIR}/scripts/setup-web.sh"
    setup_web_stack

    # 8. Setup backend API using modular script
    print_status "Setting up backend API..."
    source "${SCRIPT_DIR}/scripts/setup-backend.sh"
    setup_nodejs_backend
    setup_database_schema "${MYSQL_ROOT_PASSWORD}"
    setup_backend_environment "${ASTERISK_DB_PASSWORD}"
    create_backend_service
    start_backend_service

    # 9. Perform final system checks and display summary using modular script
    print_status "Performing final system checks..."
    source "${SCRIPT_DIR}/scripts/system-checks.sh"
    perform_system_checks
    display_installation_summary "${MYSQL_ROOT_PASSWORD}" "${ASTERISK_DB_PASSWORD}"

    print_status "Installation completed successfully!"
}

# Execute main function
main "$@"
