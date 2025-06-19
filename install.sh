
#!/bin/bash

# Asterisk installation script for iBilling
source "scripts/utils.sh"

install_asterisk() {
    local asterisk_db_password=$1
    
    print_status "Installing Asterisk 22 with ODBC support..."
    cd /usr/src
    
    # Download Asterisk 22
    sudo wget -O asterisk-22-current.tar.gz "https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-22-current.tar.gz"
    sudo tar xzf asterisk-22-current.tar.gz
    cd asterisk-22*/

    # Install additional dependencies for Asterisk 22
    print_status "Installing Asterisk 22 dependencies..."
    sudo apt update
    sudo apt install -y libcurl4-openssl-dev libxml2-dev libxslt1-dev \
        libedit-dev libjansson-dev uuid-dev libsqlite3-dev libssl-dev \
        libncurses5-dev libsrtp2-dev libspandsp-dev libtiff-dev \
        libfftw3-dev libvorbis-dev libspeex-dev libopus-dev libgsm1-dev \
        libneon27-dev libgmime-3.0-dev liburiparser-dev libical-dev \
        libjack-dev liblua5.2-dev libsnmp-dev libcorosync-common-dev \
        libradcli-dev python3-dev libpopt-dev libnewt-dev \
        unixodbc unixodbc-dev libmariadb-dev odbc-mariadb

    # Configure Asterisk build with ODBC support
    sudo contrib/scripts/get_mp3_source.sh
    sudo ./configure --with-odbc --with-crypto --with-ssl --with-srtp --with-unixodbc

    # Verify ODBC is properly detected
    print_status "Verifying ODBC configuration..."
    if ! grep -q "ODBC" config.log; then
        print_error "ODBC support not detected. Installing additional ODBC packages..."
        sudo apt install -y libodbc1 odbcinst1debian2 unixodbc-dev
        sudo ./configure --with-odbc --with-crypto --with-ssl --with-srtp --with-unixodbc
    fi

    # Enable required modules in menuselect
    sudo make menuselect.makeopts

    # Enable ODBC and realtime modules
    print_status "Enabling ODBC and realtime modules..."
    sudo menuselect/menuselect --enable res_odbc --enable cdr_adaptive_odbc --enable res_config_odbc menuselect.makeopts
    sudo menuselect/menuselect --enable res_realtime menuselect.makeopts
    sudo menuselect/menuselect --enable func_odbc menuselect.makeopts

    # Verify modules are enabled
    if ! grep -q "res_odbc" menuselect.makeopts; then
        print_warning "ODBC modules may not be available in this build"
    fi

    # Build and install
    print_status "Building Asterisk 22 (this may take 15-30 minutes)..."
    sudo make -j$(nproc)
    if [ $? -ne 0 ]; then
        print_error "Asterisk build failed"
        exit 1
    fi

    sudo make install
    sudo make samples
    sudo make config
    sudo ldconfig

    # Configure Asterisk for ODBC and realtime
    configure_asterisk "$asterisk_db_password"
}

create_config_files() {
    print_status "Creating configuration files..."
    sudo mkdir -p /tmp/ibilling-config
    
    # ODBC resource configuration
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
connect_timeout => 10
negative_connection_cache => 300
EOF

    # CDR ODBC configuration
    sudo tee /tmp/ibilling-config/cdr_adaptive_odbc.conf > /dev/null <<'EOF'
[asterisk]
connection=asterisk
table=cdr
EOF

    # Asterisk realtime configuration
    sudo tee /tmp/ibilling-config/extconfig.conf > /dev/null <<'EOF'
[settings]
; Map Asterisk objects to database tables for realtime

; PJSIP Realtime Configuration (Asterisk 22)
ps_endpoints => odbc,asterisk,ps_endpoints
ps_auths => odbc,asterisk,ps_auths
ps_aors => odbc,asterisk,ps_aors
ps_contacts => odbc,asterisk,ps_contacts

; Legacy SIP realtime (for compatibility)
sipusers => odbc,asterisk,sip_credentials
sippeers => odbc,asterisk,sip_credentials

; Voicemail realtime
voicemail => odbc,asterisk,voicemail_users

; Extension realtime (optional - use with caution)
extensions => odbc,asterisk,extensions

; CDR realtime (handled by cdr_adaptive_odbc.conf)
; cdr => odbc,asterisk,cdr

; Queue realtime
; queues => odbc,asterisk,queues
; queue_members => odbc,asterisk,queue_members

; Parking realtime
; parkinglots => odbc,asterisk,parkinglots
EOF

    # ODBC driver configuration
    sudo tee /tmp/ibilling-config/odbcinst.ini > /dev/null <<'EOF'
[MariaDB]
Description = MariaDB ODBC driver
Driver      = /usr/lib/x86_64-linux-gnu/odbc/libmaodbc.so
Threading   = 1
EOF

    # ODBC DSN configuration template
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

    # Basic extensions.conf for testing
    sudo tee /tmp/ibilling-config/extensions.conf > /dev/null <<'EOF'
; Extensions Configuration for iBilling
; This file is managed by the iBilling system

[general]
static=yes
writeprotect=no
clearglobalvars=no

[globals]
; Global variables go here

[from-internal]
; Internal extension context
; Test extension for PJSIP endpoints
exten => 100,1,Dial(PJSIP/100)
exten => 101,1,Dial(PJSIP/101)

; Echo test
exten => 600,1,Answer()
exten => 600,n,Echo()
exten => 600,n,Hangup()

; Voicemail test
exten => *97,1,VoiceMailMain()

[from-external]
; External/trunk context
; DID routing will be added here by the system

include => from-internal
EOF

    # Enhanced PJSIP configuration with debugging
    sudo tee /tmp/ibilling-config/pjsip.conf > /dev/null <<'EOF'
; PJSIP Configuration for iBilling
; This file is managed by the iBilling system

[global]
type=global
endpoint_identifier_order=username,ip
debug=yes

[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060

[transport-tcp]
type=transport
protocol=tcp
bind=0.0.0.0:5060

; Template for customer endpoints
[customer-template](!)
type=endpoint
context=from-internal
disallow=all
allow=ulaw,alaw,g722,g729
direct_media=no
ice_support=yes
force_rport=yes
rewrite_contact=yes
rtp_symmetric=yes
send_rpid=yes
send_pai=yes
trust_id_inbound=yes

; Template for auth objects
[auth-template](!)
type=auth
auth_type=userpass

; Template for AOR objects  
[aor-template](!)
type=aor
max_contacts=1
remove_existing=yes
qualify_frequency=60

; Sample endpoint for testing (will be replaced by realtime)
[100]
type=endpoint
context=from-internal
disallow=all
allow=ulaw,alaw
aors=100
auth=100

[100]
type=auth
auth_type=userpass
username=100
password=test123

[100]
type=aor
max_contacts=1

; Trunk configurations will be added here by the system
; Customer configurations will be added here by the system
EOF

    print_status "Configuration files created in /tmp/ibilling-config/"
}

setup_system() {
    print_status "Setting up system..."
    
    # Update package lists
    sudo apt update

    # Install necessary packages
    sudo apt install -y wget mariadb-client net-tools vim git

    # Fix locale issues
    print_status "Fixing locale settings..."
    sudo apt install -y locales
    sudo locale-gen en_US.UTF-8
    sudo update-locale LANG=en_US.UTF-8

    # Set timezone
    sudo timedatectl set-timezone UTC
    
    print_status "System setup completed"
}

check_mysql_access() {
    local mysql_root_password=$1
    
    # Test if MySQL is accessible without password
    if mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
        print_status "MySQL root access available without password"
        return 0
    fi
    
    # Test if MySQL is accessible with provided password
    if [ -n "$mysql_root_password" ] && mysql -u root -p"${mysql_root_password}" -e "SELECT 1;" >/dev/null 2>&1; then
        print_status "MySQL root access available with provided password"
        return 0
    fi
    
    return 1
}

secure_mysql() {
    local mysql_root_password=$1
    
    print_status "Securing MariaDB installation..."
    
    # Check if we can access MySQL without password first
    if mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
        print_status "Setting up MySQL root password and security..."
        mysql -u root <<EOF
UPDATE mysql.user SET Password=PASSWORD('${mysql_root_password}') WHERE User='root';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
        if [ $? -eq 0 ]; then
            print_status "✓ MySQL secured successfully"
            return 0
        else
            print_error "✗ Failed to secure MySQL"
            return 1
        fi
    else
        print_status "MySQL appears to already be secured"
        return 0
    fi
}

reset_database() {
    local mysql_root_password=$1
    local asterisk_db_password=$2
    
    print_status "Resetting database - dropping and recreating..."
    
    # Stop any existing connections
    sudo systemctl stop asterisk 2>/dev/null || true
    
    # Try to determine the correct way to connect to MySQL
    local mysql_connect=""
    if mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
        mysql_connect="mysql -u root"
    elif [ -n "$mysql_root_password" ] && mysql -u root -p"${mysql_root_password}" -e "SELECT 1;" >/dev/null 2>&1; then
        mysql_connect="mysql -u root -p${mysql_root_password}"
    else
        print_error "Cannot connect to MySQL. Please check your MySQL installation and root password."
        print_status "Trying to reset MySQL root password..."
        
        # Stop MySQL
        sudo systemctl stop mariadb
        
        # Start MySQL in safe mode
        sudo mysqld_safe --skip-grant-tables --skip-networking &
        sleep 5
        
        # Reset root password
        mysql -u root <<EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysql_root_password}';
FLUSH PRIVILEGES;
EOF
        
        # Stop safe mode MySQL
        sudo pkill mysqld_safe
        sudo pkill mysqld
        sleep 3
        
        # Start MySQL normally
        sudo systemctl start mariadb
        sleep 5
        
        mysql_connect="mysql -u root -p${mysql_root_password}"
        
        # Test connection
        if ! $mysql_connect -e "SELECT 1;" >/dev/null 2>&1; then
            print_error "Still cannot connect to MySQL after reset attempt"
            exit 1
        fi
        
        print_status "✓ MySQL root password reset successfully"
    fi

    # Drop and recreate database
    $mysql_connect <<EOF
DROP DATABASE IF EXISTS asterisk;
CREATE DATABASE asterisk CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
DROP USER IF EXISTS 'asterisk'@'localhost';
CREATE USER 'asterisk'@'localhost' IDENTIFIED BY '${asterisk_db_password}';
GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk'@'localhost';
FLUSH PRIVILEGES;
EOF

    if [ $? -eq 0 ]; then
        print_status "✓ Database reset completed successfully"
    else
        print_error "✗ Database reset failed"
        exit 1
    fi
}

setup_database() {
    local mysql_root_password=$1
    local asterisk_db_password=$2
    
    print_status "Configuring MariaDB..."
    sudo systemctl start mariadb
    sudo systemctl enable mariadb

    # Check MySQL access and secure if needed
    if ! check_mysql_access "$mysql_root_password"; then
        secure_mysql "$mysql_root_password"
    fi

    # Reset database completely
    reset_database "$mysql_root_password" "$asterisk_db_password"

    # Create database tables using the schema file
    print_status "Creating database tables..."
    if [ -f "config/database-schema.sql" ]; then
        if mysql -u root -p"${mysql_root_password}" asterisk < "config/database-schema.sql"; then
            print_status "✓ Database schema applied successfully"
        else
            print_error "✗ Failed to apply database schema"
            exit 1
        fi
    else
        print_warning "Database schema file not found at config/database-schema.sql"
        
        # Create basic tables manually
        print_status "Creating basic tables manually..."
        mysql -u root -p"${mysql_root_password}" asterisk <<EOF
-- Basic CDR table
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
    PRIMARY KEY (id),
    INDEX calldate_idx (calldate),
    INDEX accountcode_idx (accountcode)
);

-- PJSIP realtime tables
CREATE TABLE IF NOT EXISTS ps_endpoints (
    id VARCHAR(40) NOT NULL PRIMARY KEY,
    transport VARCHAR(40),
    aors VARCHAR(200),
    auth VARCHAR(40),
    context VARCHAR(40) DEFAULT 'from-internal',
    disallow VARCHAR(200) DEFAULT 'all',
    allow VARCHAR(200) DEFAULT 'ulaw,alaw',
    direct_media ENUM('yes','no') DEFAULT 'no'
);

CREATE TABLE IF NOT EXISTS ps_auths (
    id VARCHAR(40) NOT NULL PRIMARY KEY,
    auth_type ENUM('userpass','md5') DEFAULT 'userpass',
    password VARCHAR(80),
    username VARCHAR(40)
);

CREATE TABLE IF NOT EXISTS ps_aors (
    id VARCHAR(40) NOT NULL PRIMARY KEY,
    max_contacts INT DEFAULT 1,
    remove_existing ENUM('yes','no') DEFAULT 'yes'
);

-- Basic customers table
CREATE TABLE IF NOT EXISTS customers (
    id VARCHAR(20) NOT NULL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    balance DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    status ENUM('Active', 'Suspended', 'Closed') NOT NULL DEFAULT 'Active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF
    fi
    
    print_status "Database setup completed successfully"
}

manage_backend_service() {
    local asterisk_db_password=$1
    
    print_status "Managing iBilling backend service..."
    
    # Check if service exists
    if sudo systemctl list-units --full -all | grep -Fq "ibilling-backend.service"; then
        print_status "Service exists - stopping and disabling..."
        sudo systemctl stop ibilling-backend 2>/dev/null || true
        sudo systemctl disable ibilling-backend 2>/dev/null || true
        
        # Wait for service to fully stop
        sleep 3
        print_status "✓ Existing service stopped"
    else
        print_status "Service does not exist - will create new service"
    fi
    
    # Create environment file
    print_status "Creating environment configuration..."
    sudo mkdir -p /opt/billing
    
    # Generate JWT secret
    local jwt_secret=$(openssl rand -base64 32)
    
    # Create new environment file
    sudo tee /opt/billing/.env > /dev/null <<EOF
# Database Configuration
DB_HOST=localhost
DB_PORT=3306
DB_NAME=asterisk
DB_USER=asterisk
DB_PASSWORD=${asterisk_db_password}

# JWT Configuration
JWT_SECRET=${jwt_secret}

# Server Configuration
PORT=3001
NODE_ENV=production

# Asterisk Configuration
ASTERISK_HOST=localhost
ASTERISK_PORT=5038
ASTERISK_USERNAME=admin
ASTERISK_SECRET=
EOF

    # Set proper permissions
    sudo chmod 600 /opt/billing/.env
    sudo chown root:root /opt/billing/.env
    
    # Create new systemd service file
    print_status "Creating systemd service..."
    sudo tee /etc/systemd/system/ibilling-backend.service > /dev/null <<EOF
[Unit]
Description=iBilling Backend API Server
After=network.target mysql.service

[Service]
Type=simple
User=ihs
WorkingDirectory=/opt/billing/web/backend
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
EnvironmentFile=/opt/billing/.env

[Install]
WantedBy=multi-user.target
EOF

    # Only enable service if backend directory will exist
    if [ -d "/opt/billing/web/backend" ] && [ -f "/opt/billing/web/backend/server.js" ]; then
        # Reload systemd and enable service
        sudo systemctl daemon-reload
        sudo systemctl enable ibilling-backend
        print_status "✓ Backend service configured and enabled"
    else
        # Just reload systemd, don't enable yet
        sudo systemctl daemon-reload
        print_status "✓ Backend service configured (will be enabled when backend files are available)"
    fi
}

configure_asterisk() {
    local asterisk_db_password=$1
    
    print_status "Configuring Asterisk 22 for ODBC and realtime..."

    # Create asterisk user if it doesn't exist
    if ! id asterisk >/dev/null 2>&1; then
        print_status "Creating asterisk user and group..."
        sudo groupadd -r asterisk
        sudo useradd -r -d /var/lib/asterisk -g asterisk asterisk
        sudo usermod -aG audio,dialout asterisk
    fi

    # Set proper ownership
    sudo chown -R asterisk:asterisk /var/lib/asterisk
    sudo chown -R asterisk:asterisk /var/log/asterisk
    sudo chown -R asterisk:asterisk /var/spool/asterisk
    sudo chown -R asterisk:asterisk /etc/asterisk

    # Backup original configs
    backup_file /etc/asterisk/res_odbc.conf
    backup_file /etc/asterisk/extconfig.conf
    backup_file /etc/asterisk/modules.conf
    backup_file /etc/asterisk/pjsip.conf
    backup_file /etc/asterisk/extensions.conf

    # Copy configuration templates from /tmp/ibilling-config/
    sudo cp /tmp/ibilling-config/res_odbc.conf /etc/asterisk/
    sudo cp /tmp/ibilling-config/cdr_adaptive_odbc.conf /etc/asterisk/
    sudo cp /tmp/ibilling-config/extconfig.conf /etc/asterisk/
    sudo cp /tmp/ibilling-config/extensions.conf /etc/asterisk/
    sudo cp /tmp/ibilling-config/pjsip.conf /etc/asterisk/

    # Replace password placeholder in configuration files
    sudo sed -i "s/ASTERISK_DB_PASSWORD_PLACEHOLDER/${asterisk_db_password}/g" /etc/asterisk/res_odbc.conf

    # Setup ODBC system configuration
    print_status "Setting up ODBC system configuration..."
    sudo cp /tmp/ibilling-config/odbcinst.ini /etc/odbcinst.ini
    sudo cp /tmp/ibilling-config/odbc.ini.template /etc/odbc.ini
    sudo sed -i "s/ASTERISK_DB_PASSWORD_PLACEHOLDER/${asterisk_db_password}/g" /etc/odbc.ini

    # Configure modules.conf to load ODBC and realtime modules
    print_status "Configuring modules.conf for ODBC and realtime..."
    
    # Create a clean modules.conf with required modules
    sudo tee /etc/asterisk/modules.conf > /dev/null <<EOF
[modules]
autoload=yes

; Explicitly load ODBC and realtime modules
load => res_odbc.so
load => cdr_adaptive_odbc.so
load => res_config_odbc.so
load => res_realtime.so
load => func_odbc.so

; Load PJSIP modules
load => res_pjsip.so
load => res_pjsip_session.so
load => res_pjsip_registrar.so
load => res_pjsip_authenticator_digest.so
load => res_pjsip_endpoint_identifier_user.so
load => res_pjsip_endpoint_identifier_ip.so
load => res_pjsip_transport_udp.so
load => res_pjsip_transport_tcp.so

; Core modules
load => chan_pjsip.so
load => app_dial.so
load => app_echo.so
load => app_voicemail.so
load => pbx_config.so

; Disable chan_sip to avoid conflicts
noload => chan_sip.so
EOF

    # Set proper permissions
    sudo chown asterisk:asterisk /etc/asterisk/*

    # Test ODBC connectivity before starting Asterisk
    print_status "Testing ODBC connectivity..."
    if command -v isql >/dev/null 2>&1; then
        if echo "SELECT 1;" | isql -v asterisk-connector asterisk "${asterisk_db_password}" >/dev/null 2>&1; then
            print_status "✓ ODBC connection test successful"
        else
            print_warning "⚠ ODBC connection test failed - will retry after Asterisk restart"
        fi
    else
        print_warning "⚠ isql command not available for ODBC testing"
    fi

    # Stop any existing Asterisk
    sudo systemctl stop asterisk 2>/dev/null || true
    sudo pkill -f asterisk 2>/dev/null || true
    sleep 3

    # Start and enable Asterisk
    print_status "Starting Asterisk service..."
    sudo systemctl enable asterisk
    sudo systemctl start asterisk

    # Manage backend service after Asterisk configuration
    manage_backend_service "$asterisk_db_password"

    # Wait for Asterisk to start and verify modules are loaded
    sleep 15
    print_status "Verifying Asterisk modules and configuration..."
    
    # Check if Asterisk is running
    if sudo systemctl is-active --quiet asterisk; then
        print_status "✓ Asterisk service is running"
        
        # Check ODBC modules
        if sudo asterisk -rx "module show like odbc" 2>/dev/null | grep -q "res_odbc.so"; then
            print_status "✓ ODBC modules loaded successfully"
        else
            print_warning "⚠ ODBC modules may not be loaded - check Asterisk logs"
        fi
        
        # Check PJSIP modules
        if sudo asterisk -rx "module show like pjsip" 2>/dev/null | grep -q "res_pjsip.so"; then
            print_status "✓ PJSIP modules loaded successfully"
        else
            print_warning "⚠ PJSIP modules may not be loaded"
        fi
        
        # Test ODBC connection from Asterisk
        print_status "Testing ODBC connection from Asterisk..."
        if sudo asterisk -rx "odbc show all" 2>/dev/null | grep -q "asterisk.*Connected"; then
            print_status "✓ ODBC connection active in Asterisk"
        else
            print_warning "⚠ ODBC connection not active in Asterisk - restarting Asterisk"
            sudo systemctl restart asterisk
            sleep 10
            if sudo asterisk -rx "odbc show all" 2>/dev/null | grep -q "asterisk.*Connected"; then
                print_status "✓ ODBC connection active after restart"
            else
                print_error "✗ ODBC connection still not working"
            fi
        fi
        
        # Check realtime configuration
        if sudo asterisk -rx "realtime load ps_endpoints id" 2>/dev/null >/dev/null; then
            print_status "✓ Realtime configuration is working"
        else
            print_warning "⚠ Realtime configuration may need adjustment"
        fi
        
    else
        print_error "✗ Asterisk service failed to start"
        print_status "Check logs with: sudo journalctl -u asterisk -f"
    fi

    # Clean up temporary files
    sudo rm -rf /tmp/ibilling-config

    print_status "Asterisk 22 installation and ODBC/realtime configuration completed"
    print_status ""
    print_status "Verification commands:"
    print_status "- Check Asterisk status: sudo systemctl status asterisk"
    print_status "- Check ODBC: sudo asterisk -rx 'odbc show all'"
    print_status "- Check PJSIP endpoints: sudo asterisk -rx 'pjsip show endpoints'"
    print_status "- Check realtime: sudo asterisk -rx 'realtime load ps_endpoints id'"
    print_status "- View logs: sudo journalctl -u asterisk -f"
    print_status ""
    print_status "Note: No endpoints will show until they are created in the database"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -eq 0 ]; then
        echo "Usage: $0 <mysql_root_password> <asterisk_db_password>"
        echo "   or: $0 <asterisk_db_password> (if MySQL is already configured)"
        exit 1
    fi

    if [ $# -eq 2 ]; then
        MYSQL_ROOT_PASSWORD=$1
        ASTERISK_DB_PASSWORD=$2
    elif [ $# -eq 1 ]; then
        ASTERISK_DB_PASSWORD=$1
    else
        echo "Usage: $0 <mysql_root_password> <asterisk_db_password>"
        echo "   or: $0 <asterisk_db_password> (if MySQL is already configured)"
        exit 1
    fi
    
    setup_system
    
    if [ -n "$MYSQL_ROOT_PASSWORD" ] && [ -n "$ASTERISK_DB_PASSWORD" ]; then
        setup_database "$MYSQL_ROOT_PASSWORD" "$ASTERISK_DB_PASSWORD"
    fi
    
    create_config_files
    install_asterisk "$ASTERISK_DB_PASSWORD"
fi
