
#!/bin/bash

# iBilling - Professional Voice Billing System Installation Script for Debian 12
# Exit on error
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Import utility functions
source "${SCRIPT_DIR}/scripts/utils.sh"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root for security reasons"
   exit 1
fi

print_status "Starting iBilling - Professional Voice Billing System installation on Debian 12..."

# 1. Create directory structure
print_status "Creating directory structure..."
create_directory "/opt/billing/backend"
create_directory "/opt/billing/web"
create_directory "/opt/billing/logs"
create_directory "/var/lib/asterisk/agi-bin" "asterisk:asterisk"
create_directory "/etc/asterisk/backup"

# 2. Update system and install dependencies
print_status "Updating system and installing dependencies..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y mariadb-server git curl unixodbc unixodbc-dev libmariadb-dev odbc-mariadb \
    wget build-essential subversion libjansson-dev libxml2-dev uuid-dev libsqlite3-dev \
    libssl-dev libncurses5-dev libedit-dev libsrtp2-dev libspandsp-dev libtiff-dev \
    libfftw3-dev libvorbis-dev libspeex-dev libopus-dev libgsm1-dev libnewt-dev \
    libpopt-dev libical-dev libjack-dev liblua5.2-dev libsnmp-dev libcorosync-common-dev \
    libradcli-dev libneon27-dev libgmime-3.0-dev liburiparser-dev libxslt1-dev \
    python3-dev python3-pip nginx certbot python3-certbot-nginx

# 3. Generate passwords
MYSQL_ROOT_PASSWORD=$(generate_password)
ASTERISK_DB_PASSWORD=$(generate_password)

# 4. Setup database
print_status "Setting up database..."
"${SCRIPT_DIR}/scripts/setup-database.sh" "${MYSQL_ROOT_PASSWORD}" "${ASTERISK_DB_PASSWORD}"

# 5. Setup ODBC
print_status "Setting up ODBC..."
"${SCRIPT_DIR}/scripts/setup-odbc.sh" "${ASTERISK_DB_PASSWORD}"

# 6. Install and configure Asterisk
print_status "Installing Asterisk..."
"${SCRIPT_DIR}/scripts/install-asterisk.sh" "${ASTERISK_DB_PASSWORD}"

# 7. Setup web stack
print_status "Setting up web stack..."
"${SCRIPT_DIR}/scripts/setup-web.sh"

# 8. Create environment file with credentials
print_status "Creating environment configuration..."
sudo tee /opt/billing/.env > /dev/null <<EOF
# Database Configuration
DB_HOST=localhost
DB_PORT=3306
DB_NAME=asterisk
DB_USER=asterisk
DB_PASSWORD=${ASTERISK_DB_PASSWORD}

# MySQL Root Password (for administrative tasks)
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}

# Application Configuration
NODE_ENV=production
PORT=3001

# Asterisk Configuration
ASTERISK_HOST=localhost
ASTERISK_PORT=5038
EOF

sudo chmod 600 /opt/billing/.env
sudo chown $USER:$USER /opt/billing/.env

# 9. Perform final system checks and display summary
"${SCRIPT_DIR}/scripts/system-checks.sh" "${MYSQL_ROOT_PASSWORD}" "${ASTERISK_DB_PASSWORD}"

# 10. Test ODBC connection
"${SCRIPT_DIR}/scripts/setup-odbc.sh" "${ASTERISK_DB_PASSWORD}" && \
"${SCRIPT_DIR}/scripts/setup-odbc.sh" "${ASTERISK_DB_PASSWORD}" # This will run the test function
