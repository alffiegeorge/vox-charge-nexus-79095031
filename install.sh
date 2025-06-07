
#!/bin/bash

# iBilling - Professional Voice Billing System Installation Script for Debian 12
# Standalone version - no external dependencies required
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
        local user_name=$(echo "$owner" | cut -d: -f1)
        if id "$user_name" >/dev/null 2>&1; then
            sudo chown -R "$owner" "$dir_path"
            print_status "Created directory: $dir_path (owner: $owner)"
        else
            print_status "Created directory: $dir_path (will set ownership later when $user_name user exists)"
        fi
    else
        print_status "Created directory: $dir_path"
    fi
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

create_config_files() {
    print_status "Creating configuration files..."
    
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

CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    role ENUM('admin', 'customer', 'operator') NOT NULL DEFAULT 'customer',
    status ENUM('active', 'inactive', 'suspended') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

INSERT IGNORE INTO customers (id, name, email, phone, type, balance, status) VALUES
('C001', 'John Doe', 'john@example.com', '+1-555-0123', 'Prepaid', 125.50, 'Active'),
('C002', 'Jane Smith', 'jane@example.com', '+1-555-0456', 'Postpaid', -45.20, 'Active'),
('C003', 'Bob Johnson', 'bob@example.com', '+1-555-0789', 'Prepaid', 0.00, 'Suspended');

-- Insert default admin user (password: admin123)
INSERT IGNORE INTO users (username, password, email, role, status) VALUES 
('admin', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin@ibilling.local', 'admin', 'active');
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

setup_database() {
    local mysql_root_password=$1
    local asterisk_db_password=$2
    
    print_status "Configuring MariaDB..."
    sudo systemctl start mariadb
    sudo systemctl enable mariadb

    print_status "Checking MariaDB configuration status..."
    
    if sudo mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
        print_status "MariaDB is using socket authentication - setting up for first time..."
        
        sudo mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysql_root_password}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
        
    elif mysql -u root -p"${mysql_root_password}" -e "SELECT 1;" >/dev/null 2>&1; then
        print_status "MariaDB root password is already set and matches - continuing..."
        
    else
        print_warning "MariaDB root password is set but doesn't match our generated password"
        print_status "This might be from a previous installation attempt"
        
        sudo systemctl stop mariadb
        sudo mysqld_safe --skip-grant-tables --skip-networking &
        SAFE_PID=$!
        sleep 5
        
        mysql -u root <<EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysql_root_password}';
FLUSH PRIVILEGES;
EOF
        
        sudo kill $SAFE_PID 2>/dev/null || true
        sleep 2
        sudo systemctl start mariadb
        
        if ! mysql -u root -p"${mysql_root_password}" -e "SELECT 1;" >/dev/null 2>&1; then
            print_error "Failed to reset MariaDB root password"
            print_status "Please manually reset MariaDB and run the script again"
            exit 1
        fi
        
        print_status "✓ MariaDB root password reset successfully"
    fi

    print_status "Creating Asterisk database and user..."
    mysql -u root -p"${mysql_root_password}" <<EOF
CREATE DATABASE IF NOT EXISTS asterisk CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'asterisk'@'localhost' IDENTIFIED BY '${asterisk_db_password}';
GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk'@'localhost';
FLUSH PRIVILEGES;
EOF

    print_status "Creating database tables..."
    mysql -u root -p"${mysql_root_password}" asterisk < /tmp/ibilling-config/database-schema.sql
    
    print_status "Database setup completed successfully"
}

setup_odbc() {
    local asterisk_db_password=$1
    
    print_status "Configuring ODBC..."
    
    sudo cp /tmp/ibilling-config/odbcinst.ini /etc/odbcinst.ini
    sudo cp /tmp/ibilling-config/odbc.ini.template /etc/odbc.ini
    sudo sed -i "s|ASTERISK_DB_PASSWORD_PLACEHOLDER|${asterisk_db_password}|g" /etc/odbc.ini

    print_status "Testing ODBC connection..."
    if isql -v asterisk-connector asterisk "${asterisk_db_password}" <<< "SELECT 1;" >/dev/null 2>&1; then
        print_status "✓ ODBC connection test successful"
    else
        print_warning "✗ ODBC connection test failed"
    fi

    print_status "ODBC configuration completed"
}

install_asterisk() {
    local asterisk_db_password=$1
    
    print_status "Installing Asterisk with ODBC support..."
    
    print_status "Installing additional Asterisk build dependencies..."
    sudo apt update
    sudo apt install -y libcurl4-openssl-dev libxml2-dev libxslt1-dev \
        libedit-dev libjansson-dev uuid-dev libsqlite3-dev libssl-dev \
        libncurses5-dev libsrtp2-dev libspandsp-dev libtiff-dev \
        libfftw3-dev libvorbis-dev libspeex-dev libopus-dev libgsm1-dev
    
    ASTERISK_DIR=""
    if [ -d "/usr/src/asterisk-20"* ]; then
        ASTERISK_DIR=$(find /usr/src -maxdepth 1 -type d -name "asterisk-20*" | head -n 1)
        print_status "Found existing Asterisk source directory: $ASTERISK_DIR"
    fi
    
    if [ -z "$ASTERISK_DIR" ]; then
        cd /usr/src
        
        if [ ! -f "asterisk-20-current.tar.gz" ]; then
            print_status "Downloading Asterisk..."
            sudo wget -O asterisk-20-current.tar.gz "http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-20-current.tar.gz"
        else
            print_status "Asterisk source archive already exists"
        fi
        
        if [ ! -d "asterisk-20"* ]; then
            print_status "Extracting Asterisk..."
            sudo tar xzf asterisk-20-current.tar.gz
        else
            print_status "Asterisk source already extracted"
        fi
        
        ASTERISK_DIR=$(find /usr/src -maxdepth 1 -type d -name "asterisk-20*" | head -n 1)
    fi
    
    cd "$ASTERISK_DIR"
    print_status "Working in directory: $ASTERISK_DIR"

    print_status "Checking MP3 source..."
    if [ ! -f "addons/mp3/mpg123.h" ]; then
        print_status "Getting MP3 source..."
        sudo contrib/scripts/get_mp3_source.sh
    else
        print_status "MP3 source already present"
    fi

    if [ -f "config.log" ] && grep -q "error" config.log; then
        print_status "Cleaning previous build attempt due to errors..."
        sudo make clean || true
        sudo rm -f config.log menuselect.makeopts || true
    fi

    if [ ! -f "config.log" ]; then
        print_status "Configuring Asterisk build..."
        sudo ./configure --with-odbc --with-crypto --with-ssl --with-srtp
        if [ $? -ne 0 ]; then
            print_error "Asterisk configure failed"
            exit 1
        fi
    else
        print_status "Asterisk build already configured"
    fi

    if [ ! -f "menuselect.makeopts" ]; then
        print_status "Creating menuselect configuration..."
        sudo make menuselect.makeopts
        if [ $? -ne 0 ]; then
            print_error "Failed to create menuselect configuration"
            exit 1
        fi
    else
        print_status "Menuselect configuration already exists"
    fi
    
    print_status "Configuring required modules..."
    sudo sed -i 's/^MENUSELECT_RES=.*res_odbc/MENUSELECT_RES=/' menuselect.makeopts 2>/dev/null || true
    sudo sed -i 's/^MENUSELECT_CDR=.*cdr_adaptive_odbc/MENUSELECT_CDR=/' menuselect.makeopts 2>/dev/null || true
    sudo sed -i 's/^MENUSELECT_RES=.*res_config_odbc/MENUSELECT_RES=/' menuselect.makeopts 2>/dev/null || true
    
    if ! pkg-config --exists libcurl; then
        print_warning "libcurl development headers not found, disabling res_config_curl"
        sudo sed -i '/^MENUSELECT_RES=/s/$/ res_config_curl/' menuselect.makeopts 2>/dev/null || echo "MENUSELECT_RES=res_config_curl" | sudo tee -a menuselect.makeopts
    fi

    if [ ! -f "main/asterisk" ]; then
        print_status "Building Asterisk (this may take 10-20 minutes)..."
        sudo make -j$(nproc)
        if [ $? -ne 0 ]; then
            print_error "Asterisk build failed"
            print_status "Trying to disable problematic modules and rebuild..."
            
            sudo sed -i '/^MENUSELECT_RES=/s/$/ res_config_curl res_curl/' menuselect.makeopts 2>/dev/null || echo "MENUSELECT_RES=res_config_curl res_curl" | sudo tee -a menuselect.makeopts
            
            sudo make clean
            sudo make -j$(nproc)
            if [ $? -ne 0 ]; then
                print_error "Asterisk build failed even after disabling problematic modules"
                exit 1
            fi
        fi
    else
        print_status "Asterisk already built, skipping compilation"
    fi

    print_status "Installing Asterisk..."
    sudo make install
    if [ $? -ne 0 ]; then
        print_error "Asterisk installation failed"
        exit 1
    fi

    if [ ! -f "/etc/asterisk/asterisk.conf" ]; then
        print_status "Installing sample configurations..."
        sudo make samples
        sudo make config
    else
        print_status "Asterisk configuration files already exist"
    fi
    
    sudo ldconfig

    if ! id asterisk >/dev/null 2>&1; then
        print_status "Creating asterisk user and group..."
        sudo groupadd -r asterisk
        sudo useradd -r -d /var/lib/asterisk -g asterisk asterisk
        sudo usermod -aG audio,dialout asterisk
    else
        print_status "Asterisk user already exists"
    fi

    print_status "Setting proper ownership for Asterisk directories..."
    sudo chown -R asterisk:asterisk /var/lib/asterisk
    sudo chown -R asterisk:asterisk /var/log/asterisk
    sudo chown -R asterisk:asterisk /var/spool/asterisk
    sudo chown -R asterisk:asterisk /etc/asterisk

    print_status "Configuring Asterisk..."

    backup_file /etc/asterisk/res_odbc.conf

    sudo cp /tmp/ibilling-config/res_odbc.conf /etc/asterisk/
    sudo cp /tmp/ibilling-config/cdr_adaptive_odbc.conf /etc/asterisk/

    sudo sed -i "s|ASTERISK_DB_PASSWORD_PLACEHOLDER|${asterisk_db_password}|g" /etc/asterisk/res_odbc.conf

    sudo systemctl enable asterisk
    sudo systemctl start asterisk

    print_status "Asterisk installation and configuration completed"
}

setup_web() {
    print_status "Installing Node.js and npm..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt install -y nodejs

    print_status "Setting up iBilling frontend..."
    cd /opt/billing/web

    sudo rm -rf ./*

    sudo git clone https://github.com/alffiegeorge/vox-charge-nexus-79095031 .

    sudo chown -R $USER:$USER /opt/billing/web

    npm install
    npm run build

    print_status "Configuring Nginx..."
    
    sudo cp /tmp/ibilling-config/nginx-ibilling.conf /etc/nginx/sites-available/ibilling

    sudo ln -sf /etc/nginx/sites-available/ibilling /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default

    sudo nginx -t
    sudo systemctl enable nginx
    sudo systemctl restart nginx

    print_status "Web stack setup completed successfully"
}

setup_backend() {
    local mysql_root_password=$1
    local asterisk_db_password=$2
    
    print_status "Setting up backend API server..."
    
    cd /opt/billing/web/backend
    
    sudo chown -R $USER:$USER /opt/billing/web/backend
    
    print_status "Installing backend dependencies..."
    npm install
    
    print_status "Creating backend environment file..."
    tee /opt/billing/web/backend/.env > /dev/null <<EOF
# Database Configuration
DB_HOST=localhost
DB_PORT=3306
DB_NAME=asterisk
DB_USER=asterisk
DB_PASSWORD=${asterisk_db_password}

# JWT Configuration
JWT_SECRET=$(openssl rand -base64 32)

# Server Configuration
PORT=3001
NODE_ENV=production

# Asterisk Configuration (for future use)
ASTERISK_HOST=localhost
ASTERISK_PORT=5038
ASTERISK_USERNAME=admin
ASTERISK_SECRET=
EOF
    
    print_status "Creating backend service..."
    sudo tee /etc/systemd/system/ibilling-backend.service > /dev/null <<EOF
[Unit]
Description=iBilling Backend API Server
After=network.target mysql.service

[Service]
Type=simple
User=$USER
WorkingDirectory=/opt/billing/web/backend
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
EnvironmentFile=/opt/billing/web/backend/.env

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable ibilling-backend
    sudo systemctl start ibilling-backend
    
    print_status "Backend API setup completed"
}

perform_system_checks() {
    print_status "Performing final system checks..."

    local all_good=true

    if ! check_service mariadb; then
        all_good=false
    fi

    if ! check_service asterisk; then
        all_good=false
    fi

    if ! check_service nginx; then
        all_good=false
    fi

    if ! check_service ibilling-backend; then
        all_good=false
    fi

    if [ "$all_good" = true ]; then
        return 0
    else
        return 1
    fi
}

display_installation_summary() {
    local mysql_root_password=$1
    local asterisk_db_password=$2
    
    print_status "============================================="
    print_status "iBilling - Professional Voice Billing System Installation Complete!"
    print_status "============================================="
    echo ""
    print_status "System Information:"
    echo "• Frontend URL: http://localhost (or your server IP)"
    echo "• Backend API: http://localhost:3001"
    echo "• Database: MariaDB on localhost:3306"
    echo "• Database Name: asterisk"
    echo "• Database User: asterisk"
    echo "• Environment File: /opt/billing/web/backend/.env"
    echo ""
    print_status "Login Credentials:"
    echo "• Admin Username: admin"
    echo "• Admin Password: admin123"
    echo ""
    print_status "Database Credentials (SAVE THESE SECURELY):"
    echo "• MySQL Root Password: ${mysql_root_password}"
    echo "• Asterisk DB Password: ${asterisk_db_password}"
    echo ""
    print_status "Next Steps:"
    echo "1. Test the web interface at http://your-server-ip"
    echo "2. Login with admin/admin123 to access the admin panel"
    echo "3. Configure your domain name in Nginx if needed"
    echo "4. Set up SSL certificates with: sudo certbot --nginx"
    echo "5. Configure firewall rules for ports 80, 443, 5060-5061 (SIP)"
    echo "6. Review Asterisk configuration in /etc/asterisk/"
    echo ""
    print_warning "Remember to:"
    echo "• Change the default admin password after first login"
    echo "• Configure backup procedures"
    echo "• Set up monitoring"
    echo "• Review security settings"

    print_status "Installation completed successfully!"
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
        python3-dev python3-pip nginx certbot python3-certbot-nginx libcurl4-openssl-dev

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

    # 9. Setup backend API
    print_status "Setting up backend API..."
    setup_backend "${MYSQL_ROOT_PASSWORD}" "${ASTERISK_DB_PASSWORD}"

    # 10. Perform final system checks and display summary
    perform_system_checks
    display_installation_summary "${MYSQL_ROOT_PASSWORD}" "${ASTERISK_DB_PASSWORD}"

    # 11. Cleanup temporary files
    sudo rm -rf /tmp/ibilling-config

    print_status "Installation completed successfully!"
}

# Execute main function
main "$@"
