
#!/bin/bash

# iBilling - Professional Voice Billing System Installation Script for Debian 12
# Refactored to use modular scripts
# Exit on error
set -e

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo -e "\033[0;31m[ERROR]\033[0m This script should not be run as root for security reasons"
   echo -e "\033[0;32m[INFO]\033[0m Please run as a regular user. The script will ask for sudo when needed."
   exit 1
fi

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if scripts directory exists, if not, clone the repository
if [ ! -d "${SCRIPT_DIR}/scripts" ]; then
    echo -e "\033[0;32m[INFO]\033[0m Scripts directory not found. Cloning iBilling repository..."
    
    # Install git if not present
    if ! command -v git >/dev/null 2>&1; then
        echo -e "\033[0;32m[INFO]\033[0m Installing git..."
        sudo apt update && sudo apt install -y git
    fi
    
    # Clone the repository to a temporary location
    TEMP_DIR="/tmp/ibilling-$(date +%s)"
    git clone https://github.com/alffiegeorge/vox-charge-nexus-79095031.git "$TEMP_DIR" || {
        echo -e "\033[0;31m[ERROR]\033[0m Failed to clone repository"
        echo -e "\033[0;32m[INFO]\033[0m Please ensure you have internet connection and access to GitHub"
        echo -e "\033[0;32m[INFO]\033[0m Or manually download the scripts directory to: ${SCRIPT_DIR}/scripts"
        exit 1
    }
    
    # Copy scripts to current directory
    if [ -d "$TEMP_DIR/scripts" ]; then
        cp -r "$TEMP_DIR/scripts" "$SCRIPT_DIR/"
        echo -e "\033[0;32m[INFO]\033[0m Scripts copied successfully"
    else
        echo -e "\033[0;31m[ERROR]\033[0m Scripts directory not found in repository"
        exit 1
    fi
    
    # Copy other necessary files
    for file in config etc opt; do
        if [ -d "$TEMP_DIR/$file" ]; then
            cp -r "$TEMP_DIR/$file" "$SCRIPT_DIR/"
        fi
    done
    
    # Cleanup
    rm -rf "$TEMP_DIR"
fi

# Now source utility functions
if [ ! -f "${SCRIPT_DIR}/scripts/utils.sh" ]; then
    echo -e "\033[0;31m[ERROR]\033[0m utils.sh not found in scripts directory"
    echo -e "\033[0;32m[INFO]\033[0m Please ensure the scripts directory contains all necessary files"
    exit 1
fi

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
    print_status "Running sudo fix script..."
    
    # Use the dedicated sudo fix script
    if "${SCRIPT_DIR}/scripts/fix-sudo-access.sh"; then
        print_status "Sudo access has been configured"
        print_warning "IMPORTANT: You must start a NEW terminal session for sudo to work"
        print_status "Please:"
        echo "  1. Close this terminal"
        echo "  2. Open a new terminal/SSH session"
        echo "  3. Run this install script again"
        exit 0
    else
        print_error "Failed to configure sudo access"
        print_status "Please fix sudo access manually and run this script again"
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
    print_status "Starting iBilling - Professional Voice Billing System installation on Debian 12..."

    # Check and setup sudo access
    check_and_setup_sudo

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
