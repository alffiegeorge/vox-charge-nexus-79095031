
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
    
    # Complete Database schema with ALL required tables
    sudo tee /tmp/ibilling-config/database-schema.sql > /dev/null <<'EOF'
-- iBilling Complete Database Schema
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
    qr_code_enabled BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX status_idx (status),
    INDEX type_idx (type)
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

-- SIP Users table for Realtime
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

-- Rates table
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

-- DID Numbers table
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

-- System Settings table
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

-- Invoices table
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

-- Invoice Items table
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

-- Trunks table
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

-- Routes table
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

-- SMS Messages table
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

-- SMS Templates table
CREATE TABLE IF NOT EXISTS sms_templates (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    message TEXT NOT NULL,
    category VARCHAR(50) DEFAULT 'general',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- SMS History table (for backward compatibility)
CREATE TABLE IF NOT EXISTS sms_history (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    phone_number VARCHAR(20) NOT NULL,
    message TEXT NOT NULL,
    status ENUM('Pending', 'Sent', 'Delivered', 'Failed', 'Scheduled') DEFAULT 'Pending',
    cost DECIMAL(8,4) DEFAULT 0.0000,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    scheduled_at TIMESTAMP NULL
);

-- Insert sample customers
INSERT IGNORE INTO customers (id, name, email, phone, type, balance, status, qr_code_enabled) VALUES
('C001', 'John Doe', 'john@example.com', '+1-555-0123', 'Prepaid', 125.50, 'Active', TRUE),
('C002', 'Jane Smith', 'jane@example.com', '+1-555-0456', 'Postpaid', -45.20, 'Active', TRUE),
('C003', 'Bob Johnson', 'bob@example.com', '+1-555-0789', 'Prepaid', 75.00, 'Active', FALSE),
('C004', 'Alice Cooper', 'alice@example.com', '+1-555-0321', 'Prepaid', 200.00, 'Active', TRUE),
('C005', 'David Wilson', 'david@example.com', '+1-555-0654', 'Postpaid', 0.00, 'Suspended', FALSE);

-- Insert sample rates
INSERT IGNORE INTO rates (destination_prefix, destination_name, rate_per_minute, billing_increment, effective_date) VALUES
('1', 'USA/Canada', 0.0120, 60, CURDATE()),
('44', 'United Kingdom', 0.0250, 60, CURDATE()),
('49', 'Germany', 0.0280, 60, CURDATE()),
('33', 'France', 0.0240, 60, CURDATE()),
('91', 'India', 0.0180, 60, CURDATE()),
('86', 'China', 0.0150, 60, CURDATE()),
('81', 'Japan', 0.0200, 60, CURDATE());

-- Insert sample DID numbers
INSERT IGNORE INTO did_numbers (number, customer_id, monthly_cost, status, country, region) VALUES
('+1-555-1001', 'C001', 5.00, 'Assigned', 'USA', 'New York'),
('+1-555-1002', 'C002', 5.00, 'Assigned', 'USA', 'California'),
('+1-555-1003', NULL, 5.00, 'Available', 'USA', 'Texas'),
('+1-555-1004', 'C003', 5.00, 'Assigned', 'USA', 'Florida'),
('+1-555-1005', NULL, 5.00, 'Available', 'USA', 'Illinois');

-- Insert sample trunks
INSERT IGNORE INTO trunks (name, type, host, port, username, context, status, provider) VALUES
('Trunk-Primary', 'SIP', 'sip.provider1.com', 5060, 'ibilling_user1', 'from-trunk', 'Active', 'Provider One'),
('Trunk-Secondary', 'SIP', 'sip.provider2.com', 5060, 'ibilling_user2', 'from-trunk', 'Active', 'Provider Two'),
('Trunk-Backup', 'SIP', 'sip.provider3.com', 5060, 'ibilling_user3', 'from-trunk', 'Inactive', 'Provider Three');

-- Insert sample CDR records
INSERT IGNORE INTO cdr (calldate, src, dst, duration, billsec, disposition, accountcode) VALUES
(NOW() - INTERVAL 1 HOUR, '+1-555-0123', '+1-555-9999', 300, 295, 'ANSWERED', 'C001'),
(NOW() - INTERVAL 2 HOUR, '+1-555-0456', '+44-20-7946-0958', 180, 175, 'ANSWERED', 'C002'),
(NOW() - INTERVAL 3 HOUR, '+1-555-0789', '+49-30-12345678', 120, 0, 'NO ANSWER', 'C003'),
(NOW() - INTERVAL 4 HOUR, '+1-555-0321', '+33-1-42-86-83-26', 450, 445, 'ANSWERED', 'C004'),
(NOW() - INTERVAL 5 HOUR, '+1-555-0654', '+91-11-23456789', 90, 85, 'ANSWERED', 'C005');

-- Insert sample SMS templates
INSERT IGNORE INTO sms_templates (title, message, category) VALUES
('Welcome Message', 'Welcome to iBilling! Your account is now active.', 'welcome'),
('Low Balance Alert', 'Your account balance is low. Please top up to continue using our services.', 'billing'),
('Payment Confirmation', 'Payment received successfully. Thank you!', 'billing'),
('Service Maintenance', 'Scheduled maintenance will occur tonight from 2-4 AM.', 'maintenance');

-- Insert system settings
INSERT IGNORE INTO system_settings (setting_key, setting_value, setting_type, category, description) VALUES
('company_name', 'iBilling Communications', 'string', 'general', 'Company name displayed in the system'),
('system_email', 'admin@ibilling.com', 'string', 'general', 'System email address for notifications'),
('currency', 'USD', 'string', 'general', 'Default currency for billing'),
('timezone', 'America/New_York', 'string', 'general', 'System timezone'),
('minimum_credit', '5.00', 'number', 'billing', 'Minimum credit required'),
('low_balance_warning', '10.00', 'number', 'billing', 'Low balance warning threshold');
EOF

    # ... keep existing code (Asterisk ODBC configuration, CDR ODBC configuration, etc.)
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
    
    # Drop and recreate the asterisk user to ensure clean setup
    mysql -u root -p"${mysql_root_password}" <<EOF
DROP USER IF EXISTS 'asterisk'@'localhost';
CREATE DATABASE IF NOT EXISTS asterisk CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'asterisk'@'localhost' IDENTIFIED BY '${asterisk_db_password}';
GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk'@'localhost';
FLUSH PRIVILEGES;
EOF

    # Test the asterisk user connection
    print_status "Testing asterisk user database connection..."
    if mysql -u asterisk -p"${asterisk_db_password}" -e "USE asterisk; SELECT 1;" >/dev/null 2>&1; then
        print_status "✓ Asterisk user database connection successful"
    else
        print_error "✗ Asterisk user database connection failed"
        
        # Try to fix potential issues
        print_status "Attempting to fix database connection issues..."
        mysql -u root -p"${mysql_root_password}" <<EOF
DROP USER IF EXISTS 'asterisk'@'localhost';
CREATE USER 'asterisk'@'localhost' IDENTIFIED WITH mysql_native_password BY '${asterisk_db_password}';
GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk'@'localhost';
FLUSH PRIVILEGES;
EOF
        
        # Test again
        if mysql -u asterisk -p"${asterisk_db_password}" -e "USE asterisk; SELECT 1;" >/dev/null 2>&1; then
            print_status "✓ Asterisk user database connection fixed"
        else
            print_error "✗ Failed to establish asterisk user database connection"
            print_status "Database credentials that will be used:"
            print_status "User: asterisk"
            print_status "Password: ${asterisk_db_password}"
            print_status "Database: asterisk"
        fi
    fi

    print_status "Creating complete database schema with all tables..."
    mysql -u root -p"${mysql_root_password}" asterisk < /tmp/ibilling-config/database-schema.sql
    
    # Create default admin user with proper password hash
    print_status "Creating default admin user..."
    # Generate bcrypt hash for admin123
    ADMIN_HASH='$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi'
    mysql -u root -p"${mysql_root_password}" asterisk <<EOF
INSERT IGNORE INTO users (username, password, email, role, status) VALUES 
('admin', '${ADMIN_HASH}', 'admin@ibilling.local', 'admin', 'active');
EOF
    
    # Verify all tables were created
    print_status "Verifying database setup..."
    table_count=$(mysql -u root -p"${mysql_root_password}" asterisk -e "SHOW TABLES;" | tail -n +2 | wc -l)
    print_status "Total tables created: $table_count"
    
    # Show table list
    print_status "Tables in database:"
    mysql -u root -p"${mysql_root_password}" asterisk -e "SHOW TABLES;"
    
    # Show sample data counts
    print_status "Sample data verification:"
    mysql -u root -p"${mysql_root_password}" asterisk -e "SELECT 'Customers:' as Table_Type, COUNT(*) as Count FROM customers UNION SELECT 'Users:', COUNT(*) FROM users UNION SELECT 'Rates:', COUNT(*) FROM rates UNION SELECT 'DID Numbers:', COUNT(*) FROM did_numbers;"
    
    print_status "Database setup completed successfully"
}

# ... keep existing code (all other functions remain the same)

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

    # 5. Setup database with complete schema
    print_status "Setting up database with complete schema..."
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
