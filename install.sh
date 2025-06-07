#!/bin/bash

# iBilling - Professional Voice Billing System Installation Script for Debian 12
# Exit on error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Utility functions
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check and setup sudo access
check_and_setup_sudo() {
    print_status "Checking sudo access..."
    
    # Check if user has sudo access
    if sudo -n true 2>/dev/null; then
        print_status "✓ User has sudo access"
        return 0
    fi
    
    print_warning "Current user ($USER) does not have sudo access"
    
    # Even if user is in sudo group, if sudo doesn't work, we need to fix it
    if groups "$USER" | grep -q '\bsudo\b'; then
        print_warning "User is in sudo group but sudo access is not working properly"
        print_status "This can happen after adding user to sudo group. We'll refresh the group membership."
    else
        print_status "User is not in sudo group. Adding user to sudo group..."
    fi
    
    # Ask for root password
    echo -n "Please enter root password to fix sudo access for $USER: "
    read -s ROOT_PASSWORD
    echo ""
    
    # Use su - to get proper root environment and run usermod (even if user might already be in group)
    echo "$ROOT_PASSWORD" | su - root -c "usermod -aG sudo $USER"
    
    if [ $? -eq 0 ]; then
        print_status "✓ User $USER sudo access configured successfully"
        print_warning "Please run 'newgrp sudo' to activate sudo access in current session"
        print_status "Or log out and log back in, then run this script again"
        print_status "Alternatively, you can continue in a new terminal session"
        exit 0
    else
        print_error "Failed to configure sudo access for user"
        exit 1
    fi
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root for security reasons"
   print_status "Please run as a regular user. The script will ask for sudo when needed."
   exit 1
fi

# Check and setup sudo access
check_and_setup_sudo

print_status "Starting iBilling - Professional Voice Billing System installation on Debian 12..."

generate_password() {
    openssl rand -base64 32
}

check_service() {
    local service_name=$1
    if sudo systemctl is-active --quiet "$service_name"; then
        print_status "✓ $service_name is running"
        return 0
    else
        print_error "✗ $service_name is not running"
        return 1
    fi
}

create_directory() {
    local dir_path=$1
    local owner=${2:-$USER:$USER}
    
    sudo mkdir -p "$dir_path"
    if [ "$owner" != "root:root" ]; then
        sudo chown -R "$owner" "$dir_path"
    fi
    print_status "Created directory: $dir_path"
}

backup_file() {
    local file_path=$1
    local backup_dir=${2:-/etc/asterisk/backup}
    
    if [ -f "$file_path" ]; then
        sudo mkdir -p "$backup_dir"
        sudo cp "$file_path" "$backup_dir/$(basename $file_path).orig" 2>/dev/null || true
        print_status "Backed up: $file_path"
    fi
}

# Create configuration files
create_config_files() {
    print_status "Creating configuration files..."
    
    # Create config directory
    sudo mkdir -p /tmp/ibilling-config
    
    # Database schema
    sudo tee /tmp/ibilling-config/database-schema.sql > /dev/null <<'EOF'
-- iBilling Database Schema
CREATE TABLE IF NOT EXISTS cdr (
    id INT(11) NOT NULL AUTO_INCREMENT,
    calldate DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
    clid VARCHAR(80) NOT NULL DEFAULT '',
    src VARCHAR(80) NOT NULL DEFAULT '',
    dst VARCHAR(80) NOT NULL DEFAULT '',
    dcontext VARCHAR(80) NOT NULL DEFAULT '',
    channel VARCHAR(80) NOT NULL DEFAULT '',
    dstchannel VARCHAR(80) NOT NULL DEFAULT '',
    lastapp VARCHAR(80) NOT NULL DEFAULT '',
    lastdata VARCHAR(80) NOT NULL DEFAULT '',
    duration INT(11) NOT NULL DEFAULT '0',
    billsec INT(11) NOT NULL DEFAULT '0',
    disposition VARCHAR(45) NOT NULL DEFAULT '',
    amaflags INT(11) NOT NULL DEFAULT '0',
    accountcode VARCHAR(20) NOT NULL DEFAULT '',
    uniqueid VARCHAR(32) NOT NULL DEFAULT '',
    userfield VARCHAR(255) NOT NULL DEFAULT '',
    peeraccount VARCHAR(20) NOT NULL DEFAULT '',
    linkedid VARCHAR(32) NOT NULL DEFAULT '',
    sequence INT(11) NOT NULL DEFAULT '0',
    PRIMARY KEY (id),
    INDEX calldate_idx (calldate),
    INDEX src_idx (src),
    INDEX dst_idx (dst),
    INDEX accountcode_idx (accountcode)
);

CREATE TABLE IF NOT EXISTS customers (
    id VARCHAR(20) NOT NULL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(20) DEFAULT NULL,
    company VARCHAR(100) DEFAULT NULL,
    type ENUM('Prepaid', 'Postpaid') NOT NULL DEFAULT 'Prepaid',
    balance DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    credit_limit DECIMAL(10,2) DEFAULT NULL,
    status ENUM('Active', 'Suspended', 'Closed') NOT NULL DEFAULT 'Active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

INSERT IGNORE INTO customers (id, name, email, phone, type, balance, status) VALUES
('C001', 'John Doe', 'john@example.com', '+1-555-0123', 'Prepaid', 125.50, 'Active'),
('C002', 'Jane Smith', 'jane@example.com', '+1-555-0456', 'Postpaid', -45.20, 'Active'),
('C003', 'Bob Johnson', 'bob@example.com', '+1-555-0789', 'Prepaid', 0.00, 'Suspended');
EOF

    # Asterisk ODBC configuration
    sudo tee /tmp/ibilling-config/res_odbc.conf > /dev/null <<'EOF'
[asterisk]
enabled => yes
dsn => asterisk-connector
username => asterisk
password => ASTERISK_DB_PASSWORD_PLACEHOLDER
pooling => no
limit => 1
pre-connect => yes
sanitysql => select 1
EOF

    # CDR ODBC configuration
    sudo tee /tmp/ibilling-config/cdr_adaptive_odbc.conf > /dev/null <<'EOF'
[asterisk]
connection=asterisk
table=cdr
EOF

    # ODBC driver configuration
    sudo tee /tmp/ibilling-config/odbcinst.ini > /dev/null <<'EOF'
[MariaDB]
Description = MariaDB ODBC driver
Driver      = /usr/lib/x86_64-linux-gnu/odbc/libmaodbc.so
Threading   = 1
EOF

    # ODBC DSN template
    sudo tee /tmp/ibilling-config/odbc.ini.template > /dev/null <<'EOF'
[asterisk-connector]
Description = MariaDB connection to 'asterisk' database
Driver      = MariaDB
Server      = 127.0.0.1
Database    = asterisk
User        = asterisk
Password    = ASTERISK_DB_PASSWORD_PLACEHOLDER
Port        = 3306
Socket      = /var/run/mysqld/mysqld.sock
Option      = 3
EOF

    # Nginx configuration
    sudo tee /tmp/ibilling-config/nginx-ibilling.conf > /dev/null <<'EOF'
server {
    listen 80;
    server_name localhost;
    root /opt/billing/web/dist;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://localhost:3001/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF
}

# Setup database
setup_database() {
    local mysql_root_password=$1
    local asterisk_db_password=$2
    
    print_status "Configuring MariaDB..."
    sudo systemctl start mariadb
    sudo systemctl enable mariadb

    # Secure MariaDB installation
    print_status "Securing MariaDB installation..."
    sudo mysql -u root <<EOF
UPDATE mysql.user SET Password=PASSWORD('${mysql_root_password}') WHERE User='root';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

    # Create Asterisk database and user
    print_status "Creating Asterisk database and user..."
    sudo mysql -u root -p"${mysql_root_password}" <<EOF
CREATE DATABASE IF NOT EXISTS asterisk CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'asterisk'@'localhost' IDENTIFIED BY '${asterisk_db_password}';
GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk'@'localhost';
FLUSH PRIVILEGES;
EOF

    # Create database tables
    print_status "Creating database tables..."
    sudo mysql -u root -p"${mysql_root_password}" asterisk < /tmp/ibilling-config/database-schema.sql
    
    print_status "Database setup completed successfully"
}

# Setup ODBC
setup_odbc() {
    local asterisk_db_password=$1
    
    print_status "Configuring ODBC..."
    
    # Write ODBC driver config
    sudo cp /tmp/ibilling-config/odbcinst.ini /etc/odbcinst.ini

    # Write ODBC DSN config from template
    sudo cp /tmp/ibilling-config/odbc.ini.template /etc/odbc.ini
    sudo sed -i "s/ASTERISK_DB_PASSWORD_PLACEHOLDER/${asterisk_db_password}/g" /etc/odbc.ini

    # Test ODBC connection
    print_status "Testing ODBC connection..."
    if isql -v asterisk-connector asterisk "${asterisk_db_password}" <<< "SELECT 1;" >/dev/null 2>&1; then
        print_status "✓ ODBC connection test successful"
    else
        print_warning "✗ ODBC connection test failed"
    fi

    print_status "ODBC configuration completed"
}

# Install Asterisk
install_asterisk() {
    local asterisk_db_password=$1
    
    print_status "Installing Asterisk with ODBC support..."
    cd /usr/src
    sudo wget -O asterisk-20-current.tar.gz "http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-20-current.tar.gz"
    sudo tar xzf asterisk-20-current.tar.gz
    cd asterisk-20*/

    # Configure Asterisk build
    sudo contrib/scripts/get_mp3_source.sh
    sudo ./configure --with-odbc --with-crypto --with-ssl --with-srtp

    # Build and install
    sudo make -j$(nproc)
    sudo make install
    sudo make samples
    sudo make config
    sudo ldconfig

    # Configure Asterisk for ODBC
    print_status "Configuring Asterisk..."

    # Backup original configs
    backup_file /etc/asterisk/res_odbc.conf

    # Copy configuration templates
    sudo cp /tmp/ibilling-config/res_odbc.conf /etc/asterisk/
    sudo cp /tmp/ibilling-config/cdr_adaptive_odbc.conf /etc/asterisk/

    # Replace password placeholder in configuration files
    sudo sed -i "s/ASTERISK_DB_PASSWORD_PLACEHOLDER/${asterisk_db_password}/g" /etc/asterisk/res_odbc.conf

    # Start and enable Asterisk
    sudo systemctl enable asterisk
    sudo systemctl start asterisk

    print_status "Asterisk installation and configuration completed"
}

# Setup web stack
setup_web() {
    print_status "Installing Node.js and npm..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt install -y nodejs

    print_status "Setting up iBilling frontend..."
    cd /opt/billing/web

    # Remove existing files if any
    sudo rm -rf ./*

    # Clone the repository
    sudo git clone https://github.com/alffiegeorge/vox-charge-nexus-79095031 .

    # Set permissions for the current user
    sudo chown -R $USER:$USER /opt/billing/web

    # Install npm dependencies
    npm install

    # Build the project
    npm run build

    print_status "Configuring Nginx..."
    
    # Copy Nginx configuration
    sudo cp /tmp/ibilling-config/nginx-ibilling.conf /etc/nginx/sites-available/ibilling

    # Enable the site
    sudo ln -sf /etc/nginx/sites-available/ibilling /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default

    # Test and restart Nginx
    sudo nginx -t
    sudo systemctl enable nginx
    sudo systemctl restart nginx

    print_status "Web stack setup completed successfully"
}

# System checks
perform_system_checks() {
    print_status "Performing final system checks..."

    local all_good=true

    # Check MariaDB
    if ! check_service mariadb; then
        all_good=false
    fi

    # Check Asterisk
    if ! check_service asterisk; then
        all_good=false
    fi

    # Check Nginx
    if ! check_service nginx; then
        all_good=false
    fi

    return $all_good
}

# Display installation summary
display_installation_summary() {
    local mysql_root_password=$1
    local asterisk_db_password=$2
    
    print_status "============================================="
    print_status "iBilling - Professional Voice Billing System Installation Complete!"
    print_status "============================================="
    echo ""
    print_status "System Information:"
    echo "• Frontend URL: http://localhost (or your server IP)"
    echo "• Database: MariaDB on localhost:3306"
    echo "• Database Name: asterisk"
    echo "• Database User: asterisk"
    echo "• Environment File: /opt/billing/.env"
    echo ""
    print_status "Credentials (SAVE THESE SECURELY):"
    echo "• MySQL Root Password: ${mysql_root_password}"
    echo "• Asterisk DB Password: ${asterisk_db_password}"
    echo ""
    print_status "Next Steps:"
    echo "1. Configure your domain name in Nginx if needed"
    echo "2. Set up SSL certificates with: sudo certbot --nginx"
    echo "3. Configure firewall rules for ports 80, 443, 5060-5061 (SIP)"
    echo "4. Review Asterisk configuration in /etc/asterisk/"
    echo "5. Test the web interface at http://your-server-ip"
    echo ""
    print_warning "Remember to:"
    echo "• Change default passwords"
    echo "• Configure backup procedures"
    echo "• Set up monitoring"
    echo "• Review security settings"

    print_status "Installation completed successfully!"
}

# MAIN INSTALLATION PROCESS
main() {
    # 1. Create directory structure
    print_status "Creating directory structure..."
    create_directory "/opt/billing/backend"
    create_directory "/opt/billing/web"
    create_directory "/opt/billing/logs"
    create_directory "/var/lib/asterisk/agi-bin" "asterisk:asterisk"
    create_directory "/etc/asterisk/backup"

    # 2. Create configuration files
    create_config_files

    # 3. Update system and install dependencies
    print_status "Updating system and installing dependencies..."
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y mariadb-server git curl unixodbc unixodbc-dev libmariadb-dev odbc-mariadb \
        wget build-essential subversion libjansson-dev libxml2-dev uuid-dev libsqlite3-dev \
        libssl-dev libncurses5-dev libedit-dev libsrtp2-dev libspandsp-dev libtiff-dev \
        libfftw3-dev libvorbis-dev libspeex-dev libopus-dev libgsm1-dev libnewt-dev \
        libpopt-dev libical-dev libjack-dev liblua5.2-dev libsnmp-dev libcorosync-common-dev \
        libradcli-dev libneon27-dev libgmime-3.0-dev liburiparser-dev libxslt1-dev \
        python3-dev python3-pip nginx certbot python3-certbot-nginx

    # 4. Generate passwords
    MYSQL_ROOT_PASSWORD=$(generate_password)
    ASTERISK_DB_PASSWORD=$(generate_password)

    # 5. Setup database
    print_status "Setting up database..."
    setup_database "${MYSQL_ROOT_PASSWORD}" "${ASTERISK_DB_PASSWORD}"

    # 6. Setup ODBC
    print_status "Setting up ODBC..."
    setup_odbc "${ASTERISK_DB_PASSWORD}"

    # 7. Install and configure Asterisk
    print_status "Installing Asterisk..."
    install_asterisk "${ASTERISK_DB_PASSWORD}"

    # 8. Setup web stack
    print_status "Setting up web stack..."
    setup_web

    # 9. Create environment file with credentials
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

    # 10. Perform final system checks and display summary
    perform_system_checks
    display_installation_summary "${MYSQL_ROOT_PASSWORD}" "${ASTERISK_DB_PASSWORD}"

    # 11. Cleanup temporary files
    sudo rm -rf /tmp/ibilling-config

    print_status "Installation completed successfully!"
}

# Execute main function
main "$@"
