
#!/bin/bash

# Run the emergency MariaDB reset and then the full standalone installation
source "$(dirname "$0")/utils.sh"

print_status "Running emergency MariaDB reset..."

# Make sure the emergency reset script is executable
chmod +x scripts/emergency-mariadb-reset.sh

# Run the emergency reset
if ./scripts/emergency-mariadb-reset.sh; then
    print_status "✓ Emergency MariaDB reset completed successfully"
    
    # Wait a moment for services to stabilize
    sleep 5
    
    print_status "Now running the comprehensive standalone installation script..."
    
    # Create the standalone installation script from the provided code
    cat > /tmp/standalone-install.sh << 'EOF'
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
    
    # Complete database schema with ALL tables and proper column definitions including qr_code_enabled
    sudo tee /tmp/ibilling-config/database-schema.sql > /dev/null <<'SCHEMA_EOF'
-- iBilling Complete Database Schema with ALL required tables and columns
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
    address TEXT DEFAULT NULL,
    notes TEXT DEFAULT NULL,
    qr_code_enabled BOOLEAN DEFAULT FALSE,
    qr_code_data TEXT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS rates (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    destination_prefix VARCHAR(20) NOT NULL,
    destination_name VARCHAR(100) NOT NULL,
    rate_per_minute DECIMAL(8,4) NOT NULL,
    min_duration INT DEFAULT 0,
    billing_increment INT DEFAULT 60,
    effective_date DATE NOT NULL,
    status ENUM('Active', 'Inactive') DEFAULT 'Active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX prefix_idx (destination_prefix),
    INDEX date_idx (effective_date)
);

CREATE TABLE IF NOT EXISTS did_numbers (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    number VARCHAR(20) NOT NULL UNIQUE,
    customer_id VARCHAR(20) DEFAULT NULL,
    monthly_cost DECIMAL(8,2) NOT NULL DEFAULT 0.00,
    setup_cost DECIMAL(8,2) NOT NULL DEFAULT 0.00,
    status ENUM('Available', 'Assigned', 'Ported', 'Suspended') DEFAULT 'Available',
    country VARCHAR(50) DEFAULT NULL,
    region VARCHAR(50) DEFAULT NULL,
    features JSON DEFAULT NULL,
    assigned_date DATE DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL,
    INDEX customer_idx (customer_id),
    INDEX status_idx (status)
);

CREATE TABLE IF NOT EXISTS system_settings (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    setting_key VARCHAR(100) NOT NULL UNIQUE,
    setting_value TEXT DEFAULT NULL,
    setting_type ENUM('string', 'number', 'boolean', 'json') DEFAULT 'string',
    category VARCHAR(50) DEFAULT 'general',
    description TEXT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX category_idx (category)
);

CREATE TABLE IF NOT EXISTS admin_users (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    salt VARCHAR(32) NOT NULL,
    full_name VARCHAR(100) DEFAULT NULL,
    role ENUM('Super Admin', 'Admin', 'Operator', 'Support') DEFAULT 'Operator',
    status ENUM('Active', 'Suspended', 'Locked') DEFAULT 'Active',
    last_login TIMESTAMP NULL,
    login_attempts INT DEFAULT 0,
    locked_until TIMESTAMP NULL,
    two_factor_enabled BOOLEAN DEFAULT FALSE,
    two_factor_secret VARCHAR(32) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS invoices (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    invoice_number VARCHAR(20) NOT NULL UNIQUE,
    customer_id VARCHAR(20) NOT NULL,
    invoice_date DATE NOT NULL,
    due_date DATE NOT NULL,
    subtotal DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    tax_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    paid_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    status ENUM('Draft', 'Sent', 'Paid', 'Overdue', 'Cancelled') DEFAULT 'Draft',
    payment_date DATE DEFAULT NULL,
    notes TEXT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
    INDEX customer_idx (customer_id),
    INDEX status_idx (status),
    INDEX date_idx (invoice_date)
);

CREATE TABLE IF NOT EXISTS invoice_items (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    invoice_id INT(11) NOT NULL,
    description VARCHAR(255) NOT NULL,
    quantity DECIMAL(10,3) NOT NULL DEFAULT 1.000,
    unit_price DECIMAL(10,4) NOT NULL DEFAULT 0.0000,
    total_price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    item_type ENUM('Call', 'SMS', 'DID', 'Service', 'Other') DEFAULT 'Other',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE,
    INDEX invoice_idx (invoice_id)
);

CREATE TABLE IF NOT EXISTS payments (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    customer_id VARCHAR(20) NOT NULL,
    invoice_id INT(11) DEFAULT NULL,
    payment_method ENUM('Cash', 'Bank Transfer', 'Credit Card', 'Mobile Money', 'Crypto') NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'VUV',
    reference_number VARCHAR(100) DEFAULT NULL,
    transaction_id VARCHAR(100) DEFAULT NULL,
    status ENUM('Pending', 'Completed', 'Failed', 'Refunded') DEFAULT 'Pending',
    payment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
    FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE SET NULL,
    INDEX customer_idx (customer_id),
    INDEX status_idx (status),
    INDEX payment_date_idx (payment_date)
);

CREATE TABLE IF NOT EXISTS trunks (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    type ENUM('SIP', 'IAX2', 'DAHDI', 'PRI') DEFAULT 'SIP',
    host VARCHAR(100) NOT NULL,
    port INT DEFAULT 5060,
    username VARCHAR(50) DEFAULT NULL,
    password VARCHAR(100) DEFAULT NULL,
    context VARCHAR(50) DEFAULT 'from-trunk',
    codec_priority VARCHAR(100) DEFAULT 'ulaw,alaw,gsm',
    max_channels INT DEFAULT 30,
    status ENUM('Active', 'Inactive', 'Maintenance') DEFAULT 'Active',
    cost_per_minute DECIMAL(8,4) DEFAULT 0.0000,
    provider VARCHAR(100) DEFAULT NULL,
    notes TEXT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS routes (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    pattern VARCHAR(50) NOT NULL,
    trunk_id INT(11) NOT NULL,
    priority INT DEFAULT 1,
    status ENUM('Active', 'Inactive') DEFAULT 'Active',
    time_restrictions JSON DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (trunk_id) REFERENCES trunks(id) ON DELETE CASCADE,
    INDEX pattern_idx (pattern),
    INDEX priority_idx (priority)
);

CREATE TABLE IF NOT EXISTS sipusers (
    id INT(11) NOT NULL AUTO_INCREMENT,
    name VARCHAR(40) NOT NULL,
    username VARCHAR(40) DEFAULT NULL,
    secret VARCHAR(40) DEFAULT NULL,
    md5secret VARCHAR(32) DEFAULT NULL,
    context VARCHAR(40) DEFAULT NULL,
    host VARCHAR(40) DEFAULT 'dynamic',
    type ENUM('friend','user','peer') DEFAULT 'friend',
    nat VARCHAR(40) DEFAULT 'yes',
    port VARCHAR(40) DEFAULT NULL,
    qualify VARCHAR(40) DEFAULT 'yes',
    canreinvite VARCHAR(40) DEFAULT 'no',
    rtptimeout VARCHAR(40) DEFAULT NULL,
    rtpholdtimeout VARCHAR(40) DEFAULT NULL,
    musiconhold VARCHAR(40) DEFAULT NULL,
    cancallforward VARCHAR(40) DEFAULT 'yes',
    dtmfmode VARCHAR(40) DEFAULT 'rfc2833',
    insecure VARCHAR(40) DEFAULT NULL,
    pickupgroup VARCHAR(40) DEFAULT NULL,
    language VARCHAR(40) DEFAULT NULL,
    disallow VARCHAR(40) DEFAULT 'all',
    allow VARCHAR(40) DEFAULT 'ulaw,alaw,gsm',
    accountcode VARCHAR(40) DEFAULT NULL,
    amaflags VARCHAR(40) DEFAULT NULL,
    callgroup VARCHAR(40) DEFAULT NULL,
    callerid VARCHAR(40) DEFAULT NULL,
    defaultuser VARCHAR(40) DEFAULT NULL,
    fromuser VARCHAR(40) DEFAULT NULL,
    fromdomain VARCHAR(40) DEFAULT NULL,
    fullcontact VARCHAR(40) DEFAULT NULL,
    regserver VARCHAR(40) DEFAULT NULL,
    ipaddr VARCHAR(40) DEFAULT NULL,
    regseconds INT(11) DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE KEY name (name)
);

CREATE TABLE IF NOT EXISTS voicemail (
    id INT(11) NOT NULL AUTO_INCREMENT,
    customer_id VARCHAR(40) NOT NULL,
    context VARCHAR(40) NOT NULL DEFAULT 'default',
    mailbox VARCHAR(40) NOT NULL DEFAULT '0',
    password VARCHAR(40) NOT NULL DEFAULT '0',
    fullname VARCHAR(40) NOT NULL DEFAULT '',
    email VARCHAR(40) DEFAULT NULL,
    pager VARCHAR(40) DEFAULT NULL,
    tz VARCHAR(40) DEFAULT 'central',
    attach VARCHAR(40) DEFAULT 'yes',
    saycid VARCHAR(40) DEFAULT 'yes',
    dialout VARCHAR(40) DEFAULT '',
    callback VARCHAR(40) DEFAULT '',
    review VARCHAR(40) DEFAULT 'no',
    operator VARCHAR(40) DEFAULT 'yes',
    envelope VARCHAR(40) DEFAULT 'no',
    sayduration VARCHAR(40) DEFAULT 'no',
    saydurationm VARCHAR(40) DEFAULT '1',
    sendvoicemail VARCHAR(40) DEFAULT 'no',
    delete_vm VARCHAR(40) DEFAULT 'no',
    nextaftercmd VARCHAR(40) DEFAULT 'yes',
    forcename VARCHAR(40) DEFAULT 'no',
    forcegreetings VARCHAR(40) DEFAULT 'no',
    hidefromdir VARCHAR(40) DEFAULT 'yes',
    stamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS sms_messages (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    customer_id VARCHAR(20) DEFAULT NULL,
    from_number VARCHAR(20) NOT NULL,
    to_number VARCHAR(20) NOT NULL,
    message TEXT NOT NULL,
    direction ENUM('Inbound', 'Outbound') NOT NULL,
    status ENUM('Pending', 'Sent', 'Delivered', 'Failed') DEFAULT 'Pending',
    cost DECIMAL(8,4) DEFAULT 0.0000,
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    delivered_at TIMESTAMP NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL,
    INDEX customer_idx (customer_id),
    INDEX direction_idx (direction),
    INDEX sent_at_idx (sent_at)
);

CREATE TABLE IF NOT EXISTS sms_templates (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    message TEXT NOT NULL,
    category VARCHAR(50) DEFAULT 'general',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS support_tickets (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    ticket_number VARCHAR(20) NOT NULL UNIQUE,
    customer_id VARCHAR(20) DEFAULT NULL,
    subject VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    priority ENUM('Low', 'Medium', 'High', 'Critical') DEFAULT 'Medium',
    status ENUM('Open', 'In Progress', 'Resolved', 'Closed') DEFAULT 'Open',
    assigned_to INT(11) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL,
    FOREIGN KEY (assigned_to) REFERENCES admin_users(id) ON DELETE SET NULL,
    INDEX customer_idx (customer_id),
    INDEX status_idx (status),
    INDEX priority_idx (priority)
);

CREATE TABLE IF NOT EXISTS audit_logs (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id INT(11) DEFAULT NULL,
    user_type ENUM('admin', 'customer') DEFAULT 'admin',
    action VARCHAR(100) NOT NULL,
    table_name VARCHAR(50) DEFAULT NULL,
    record_id VARCHAR(50) DEFAULT NULL,
    old_values JSON DEFAULT NULL,
    new_values JSON DEFAULT NULL,
    ip_address VARCHAR(45) DEFAULT NULL,
    user_agent TEXT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX user_idx (user_id, user_type),
    INDEX action_idx (action),
    INDEX created_at_idx (created_at)
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

-- Add Asterisk realtime tables
CREATE TABLE IF NOT EXISTS extensions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    context VARCHAR(40) NOT NULL DEFAULT '',
    exten VARCHAR(40) NOT NULL DEFAULT '',
    priority INT NOT NULL DEFAULT 0,
    app VARCHAR(40) NOT NULL DEFAULT '',
    appdata VARCHAR(256) NOT NULL DEFAULT '',
    UNIQUE KEY context_exten_priority (context, exten, priority)
);

CREATE TABLE IF NOT EXISTS voicemail_users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL,
    context VARCHAR(50) NOT NULL DEFAULT 'default',
    mailbox VARCHAR(50) NOT NULL,
    password VARCHAR(20) NOT NULL,
    fullname VARCHAR(50) NOT NULL,
    email VARCHAR(100),
    pager VARCHAR(100),
    options VARCHAR(100),
    stamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY mailbox_context (mailbox, context),
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS dids (
    id INT AUTO_INCREMENT PRIMARY KEY,
    number VARCHAR(20) NOT NULL UNIQUE,
    customer_id VARCHAR(50) NOT NULL,
    description VARCHAR(100),
    monthly_cost DECIMAL(10,2) DEFAULT 0.00,
    status ENUM('active', 'inactive') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS sip_credentials (
    id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL,
    sip_username VARCHAR(50) NOT NULL UNIQUE,
    sip_password VARCHAR(100) NOT NULL,
    name VARCHAR(50) NOT NULL DEFAULT '',
    type ENUM('friend', 'user', 'peer') DEFAULT 'friend',
    host VARCHAR(50) DEFAULT 'dynamic',
    context VARCHAR(50) DEFAULT 'from-internal',
    disallow VARCHAR(100) DEFAULT 'all',
    allow VARCHAR(100) DEFAULT 'ulaw,alaw,g722',
    secret VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
    INDEX idx_name (name),
    INDEX idx_sip_username (sip_username)
);

CREATE TABLE IF NOT EXISTS active_calls (
    id INT AUTO_INCREMENT PRIMARY KEY,
    call_id VARCHAR(100) NOT NULL UNIQUE,
    customer_id VARCHAR(50) NOT NULL,
    caller_id VARCHAR(50),
    called_number VARCHAR(50) NOT NULL,
    rate_id INT,
    start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    estimated_cost DECIMAL(10,4) DEFAULT 0.0000,
    status ENUM('active', 'completed', 'failed') DEFAULT 'active',
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS billing_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL,
    transaction_type ENUM('charge', 'credit', 'refund') NOT NULL,
    amount DECIMAL(10,4) NOT NULL,
    description TEXT,
    call_id VARCHAR(100),
    processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
);

-- Insert basic sample data with proper column names (now that qr_code_enabled column exists)
INSERT IGNORE INTO customers (id, name, email, phone, type, balance, status, qr_code_enabled) VALUES
('C001', 'John Doe', 'john@example.com', '+1-555-0123', 'Prepaid', 125.50, 'Active', TRUE),
('C002', 'Jane Smith', 'jane@example.com', '+1-555-0456', 'Postpaid', -45.20, 'Active', TRUE),
('C003', 'Bob Johnson', 'bob@example.com', '+1-555-0789', 'Prepaid', 0.00, 'Suspended', FALSE);

INSERT IGNORE INTO system_settings (setting_key, setting_value, setting_type, category, description) VALUES
('company_name', 'iBilling Communications', 'string', 'general', 'Company name displayed in the system'),
('system_email', 'admin@ibilling.com', 'string', 'general', 'System email address for notifications'),
('currency', 'VUV', 'string', 'general', 'Default currency for billing'),
('timezone', 'Pacific/Efate', 'string', 'general', 'System timezone');
SCHEMA_EOF

    # Asterisk ODBC configuration
    sudo tee /tmp/ibilling-config/res_odbc.conf > /dev/null <<'ODBC_EOF'
[asterisk]
enabled => yes
dsn => asterisk-connector
username => asterisk
password => ASTERISK_DB_PASSWORD_PLACEHOLDER
pooling => no
limit => 1
pre-connect => yes
sanitysql => select 1
ODBC_EOF

    # CDR ODBC configuration
    sudo tee /tmp/ibilling-config/cdr_adaptive_odbc.conf > /dev/null <<'CDR_EOF'
[asterisk]
connection=asterisk
table=cdr
CDR_EOF

    # ODBC driver configuration
    sudo tee /tmp/ibilling-config/odbcinst.ini > /dev/null <<'ODBCINST_EOF'
[MariaDB]
Description = MariaDB ODBC driver
Driver      = /usr/lib/x86_64-linux-gnu/odbc/libmaodbc.so
Threading   = 1
ODBCINST_EOF

    # ODBC DSN template
    sudo tee /tmp/ibilling-config/odbc.ini.template > /dev/null <<'ODBCINI_EOF'
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
ODBCINI_EOF

    # Nginx configuration
    sudo tee /tmp/ibilling-config/nginx-ibilling.conf > /dev/null <<'NGINX_EOF'
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
NGINX_EOF
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
        
        sudo mysql <<MYSQL_EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysql_root_password}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
MYSQL_EOF
        
    elif mysql -u root -p"${mysql_root_password}" -e "SELECT 1;" >/dev/null 2>&1; then
        print_status "MariaDB root password is already set and matches - continuing..."
        
    else
        print_warning "MariaDB root password is set but doesn't match our generated password"
        print_status "This might be from a previous installation attempt"
        
        sudo systemctl stop mariadb
        sudo mysqld_safe --skip-grant-tables --skip-networking &
        SAFE_PID=$!
        sleep 5
        
        mysql -u root <<MYSQL_RESET_EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysql_root_password}';
FLUSH PRIVILEGES;
MYSQL_RESET_EOF
        
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

    print_status "Dropping and recreating Asterisk database completely..."
    
    # Drop and recreate the database completely
    mysql -u root -p"${mysql_root_password}" <<DB_CREATE_EOF
DROP DATABASE IF EXISTS asterisk;
DROP USER IF EXISTS 'asterisk'@'localhost';
CREATE DATABASE asterisk CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'asterisk'@'localhost' IDENTIFIED BY '${asterisk_db_password}';
GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk'@'localhost';
FLUSH PRIVILEGES;
DB_CREATE_EOF

    # Test the asterisk user connection
    print_status "Testing asterisk user database connection..."
    if mysql -u asterisk -p"${asterisk_db_password}" -e "USE asterisk; SELECT 1;" >/dev/null 2>&1; then
        print_status "✓ Asterisk user database connection successful"
    else
        print_error "✗ Asterisk user database connection failed"
        exit 1
    fi

    print_status "Creating ALL database tables from complete schema..."
    mysql -u root -p"${mysql_root_password}" asterisk < /tmp/ibilling-config/database-schema.sql
    
    # Create default admin user with proper password hash
    print_status "Creating default admin user..."
    # Generate bcrypt hash for admin123
    ADMIN_HASH='$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi'
    mysql -u root -p"${mysql_root_password}" asterisk <<ADMIN_EOF
INSERT IGNORE INTO users (username, password, email, role, status) VALUES 
('admin', '${ADMIN_HASH}', 'admin@ibilling.local', 'admin', 'active');
ADMIN_EOF
    
    # Verify all required tables exist with proper structure
    print_status "Verifying database schema..."
    mysql -u root -p"${mysql_root_password}" asterisk -e "SHOW TABLES;" > /tmp/table_list.txt
    
    REQUIRED_TABLES=(
        "customers" "rates" "did_numbers" "admin_users" "trunks" "routes" 
        "sipusers" "voicemail" "cdr" "invoices" "invoice_items" "payments" 
        "sms_messages" "sms_templates" "support_tickets" "audit_logs" "system_settings"
        "extensions" "voicemail_users" "dids" "sip_credentials" "active_calls" "billing_history"
    )
    
    MISSING_TABLES=()
    for table in "${REQUIRED_TABLES[@]}"; do
        if ! grep -q "^${table}$" /tmp/table_list.txt; then
            MISSING_TABLES+=("$table")
        fi
    done
    
    if [ ${#MISSING_TABLES[@]} -gt 0 ]; then
        print_error "Missing tables: ${MISSING_TABLES[*]}"
        print_status "Created tables:"
        cat /tmp/table_list.txt
        exit 1
    else
        print_status "✓ All required tables created successfully"
    fi
    
    # Verify customers table has qr_code_enabled column
    print_status "Verifying customers table structure..."
    mysql -u root -p"${mysql_root_password}" asterisk -e "DESCRIBE customers;" > /tmp/customers_check.txt
    
    if grep -q "qr_code_enabled" /tmp/customers_check.txt; then
        print_status "✓ Customers table has qr_code_enabled column"
    else
        print_error "✗ Customers table missing qr_code_enabled column"
        print_status "Table structure:"
        cat /tmp/customers_check.txt
        exit 1
    fi
    
    rm -f /tmp/table_list.txt /tmp/customers_check.txt
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

    sudo git clone https://github.com/alffiegeorge/vox-charge-nexus-79095031.git .

    sudo chown -R $USER:$USER /opt/billing/web

    # Make all scripts executable
    print_status "Making installation scripts executable..."
    chmod +x scripts/*.sh 2>/dev/null || true

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
    
    if [ ! -d "/opt/billing/web/backend" ]; then
        print_warning "Backend directory not found, skipping backend setup"
        return 0
    fi
    
    cd /opt/billing/web/backend
    
    sudo chown -R $USER:$USER /opt/billing/web/backend
    
    print_status "Installing backend dependencies..."
    npm install || print_warning "Backend dependencies installation failed"
    
    print_status "Creating backend environment file..."
    tee .env > /dev/null <<BACKEND_ENV_EOF
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

# Asterisk Configuration
ASTERISK_HOST=localhost
ASTERISK_PORT=5038
ASTERISK_USERNAME=admin
ASTERISK_SECRET=
BACKEND_ENV_EOF
    
    print_status "Creating backend service..."
    sudo tee /etc/systemd/system/ibilling-backend.service > /dev/null <<BACKEND_SERVICE_EOF
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
BACKEND_SERVICE_EOF

    sudo systemctl daemon-reload
    sudo systemctl enable ibilling-backend
    sudo systemctl start ibilling-backend
    
    # Wait for service to start and test connection
    sleep 5
    
    print_status "Testing backend service..."
    if curl -s http://localhost:3001/health > /dev/null; then
        print_status "✓ Backend API is responding"
    else
        print_warning "⚠ Backend service may need more time to start"
    fi
    
    print_status "Backend API setup completed"
}

populate_database() {
    local mysql_root_password=$1
    
    print_status "Populating database with sample data..."
    
    cd /opt/billing/web
    
    # Run sample data population script if it exists
    if [ -f "scripts/populate-sample-data.sh" ]; then
        print_status "Running sample data population script..."
        chmod +x scripts/populate-sample-data.sh
        echo "${mysql_root_password}" | ./scripts/populate-sample-data.sh
    else
        print_status "Sample data script not found, adding basic sample data..."
        mysql -u root -p"${mysql_root_password}" asterisk <<SAMPLE_DATA_EOF
-- Add more sample customers
INSERT IGNORE INTO customers (id, name, email, phone, type, balance, status, qr_code_enabled) VALUES
('C004', 'Alice Cooper', 'alice.cooper@example.com', '+1-555-0321', 'Prepaid', 200.00, 'Active', TRUE),
('C005', 'David Wilson', 'david.wilson@example.com', '+1-555-0654', 'Postpaid', 0.00, 'Suspended', FALSE);

-- Add sample rates
INSERT IGNORE INTO rates (destination_prefix, destination_name, rate_per_minute, effective_date, status) VALUES
('1', 'USA/Canada', 0.0120, CURDATE(), 'Active'),
('44', 'United Kingdom', 0.0250, CURDATE(), 'Active'),
('49', 'Germany', 0.0280, CURDATE(), 'Active');

-- Add sample admin user
INSERT IGNORE INTO admin_users (username, email, password_hash, salt, full_name, role, status) VALUES
('admin', 'admin@ibilling.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'salt123', 'System Administrator', 'Super Admin', 'Active');
SAMPLE_DATA_EOF
    fi
    
    print_status "Database population completed successfully"
}

perform_system_checks() {
    print_status "Performing final system checks..."

    local all_good=true

    if ! check_service mariadb; then
        all_good=false
    fi

    if ! check_service nginx; then
        all_good=false
    fi

    if sudo systemctl is-active --quiet ibilling-backend; then
        print_status "✓ ibilling-backend is running"
    else
        print_warning "⚠ ibilling-backend is not running"
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

    print_status "Starting iBilling - Professional Voice Billing System installation..."

    # 1. Create directory structure
    print_status "Creating directory structure..."
    create_directory "/opt/billing/web"
    create_directory "/opt/billing/logs"

    # 2. Create configuration files
    create_config_files

    # 3. Update system and install dependencies
    print_status "Updating system and installing dependencies..."
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y mariadb-server git curl unixodbc unixodbc-dev libmariadb-dev odbc-mariadb \
        wget build-essential nginx certbot python3-certbot-nginx

    # 4. Generate passwords
    MYSQL_ROOT_PASSWORD=$(generate_password)
    ASTERISK_DB_PASSWORD=$(generate_password)

    # 5. Setup database with complete schema
    print_status "Setting up database with complete schema..."
    setup_database "${MYSQL_ROOT_PASSWORD}" "${ASTERISK_DB_PASSWORD}"

    # 6. Setup ODBC
    print_status "Setting up ODBC..."
    setup_odbc "${ASTERISK_DB_PASSWORD}"

    # 7. Setup web stack
    print_status "Setting up web stack..."
    setup_web

    # 8. Setup backend API if available
    print_status "Setting up backend API..."
    setup_backend "${MYSQL_ROOT_PASSWORD}" "${ASTERISK_DB_PASSWORD}"

    # 9. Populate database with sample data
    print_status "Populating database..."
    populate_database "${MYSQL_ROOT_PASSWORD}"

    # 10. Perform final system checks and display summary
    perform_system_checks
    display_installation_summary "${MYSQL_ROOT_PASSWORD}" "${ASTERISK_DB_PASSWORD}"

    # 11. Cleanup temporary files
    sudo rm -rf /tmp/ibilling-config

    print_status "Installation completed successfully!"
}

# Execute main function
main "$@"
EOF
    
    # Make the standalone script executable and run it
    chmod +x /tmp/standalone-install.sh
    /tmp/standalone-install.sh
    
    # Clean up
    rm -f /tmp/standalone-install.sh
    
else
    print_error "Emergency MariaDB reset failed"
    print_status "Manual intervention required"
    exit 1
fi
