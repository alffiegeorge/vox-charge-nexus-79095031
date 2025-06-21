
#!/bin/bash

# Complete database schema fix for iBilling
source "$(dirname "$0")/utils.sh"

fix_complete_database_schema() {
    local mysql_root_password=${1:-"admin123"}
    local asterisk_db_password=${2:-"asterisk123"}
    
    print_status "=== Complete Database Schema Fix ==="
    
    # Test database connection first
    print_status "1. Testing database connection..."
    if ! mysql -u root -p"${mysql_root_password}" -e "SELECT 1;" >/dev/null 2>&1; then
        print_error "✗ Cannot connect to MySQL with provided root password"
        print_status "Attempting to reset MySQL root password..."
        
        # Stop MariaDB
        sudo systemctl stop mariadb
        sleep 3
        
        # Start in safe mode
        sudo mysqld_safe --skip-grant-tables --skip-networking &
        sleep 5
        
        # Reset root password
        mysql -u root <<EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysql_root_password}';
FLUSH PRIVILEGES;
EOF
        
        # Stop safe mode and restart normally
        sudo pkill mysqld_safe 2>/dev/null || true
        sudo pkill mysqld 2>/dev/null || true
        sleep 3
        sudo systemctl start mariadb
        sleep 5
        
        # Test again
        if ! mysql -u root -p"${mysql_root_password}" -e "SELECT 1;" >/dev/null 2>&1; then
            print_error "✗ Still cannot connect to MySQL"
            return 1
        fi
    fi
    print_status "✓ Database connection successful"
    
    # Create asterisk database and user
    print_status "2. Creating asterisk database and user..."
    mysql -u root -p"${mysql_root_password}" <<EOF
DROP DATABASE IF EXISTS asterisk;
CREATE DATABASE asterisk CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
DROP USER IF EXISTS 'asterisk'@'localhost';
CREATE USER 'asterisk'@'localhost' IDENTIFIED BY '${asterisk_db_password}';
GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk'@'localhost';
FLUSH PRIVILEGES;
EOF
    
    if [ $? -eq 0 ]; then
        print_status "✓ Asterisk database and user created successfully"
    else
        print_error "✗ Failed to create asterisk database and user"
        return 1
    fi
    
    # Create complete schema with correct DID table structure
    print_status "3. Creating complete database schema..."
    mysql -u root -p"${mysql_root_password}" asterisk <<'EOF'
-- Drop existing tables to start fresh
DROP TABLE IF EXISTS invoice_items;
DROP TABLE IF EXISTS invoices;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS did_numbers;
DROP TABLE IF EXISTS rates;
DROP TABLE IF EXISTS sms_messages;
DROP TABLE IF EXISTS call_recordings;
DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS support_tickets;
DROP TABLE IF EXISTS admin_users;
DROP TABLE IF EXISTS system_settings;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS sip_credentials;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS ps_contacts;
DROP TABLE IF EXISTS ps_endpoint_id_ips;
DROP TABLE IF EXISTS ps_aors;
DROP TABLE IF EXISTS ps_auths;
DROP TABLE IF EXISTS ps_endpoints;
DROP TABLE IF EXISTS cdr;

-- Create CDR table first (no dependencies)
CREATE TABLE cdr (
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

-- Create customers table
CREATE TABLE customers (
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
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create rates table with correct columns
CREATE TABLE rates (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    destination_prefix VARCHAR(20) NOT NULL,
    destination_name VARCHAR(100) NOT NULL,
    rate_per_minute DECIMAL(8,4) NOT NULL,
    min_duration INT DEFAULT 0,
    billing_increment INT DEFAULT 60,
    effective_date DATE NOT NULL DEFAULT (CURDATE()),
    status ENUM('Active', 'Inactive') DEFAULT 'Active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX prefix_idx (destination_prefix),
    INDEX date_idx (effective_date)
);

-- Create DID numbers table with CORRECT schema matching backend expectations
CREATE TABLE did_numbers (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    number VARCHAR(20) NOT NULL UNIQUE,
    customer_id VARCHAR(20) DEFAULT NULL,
    customer_name VARCHAR(100) DEFAULT NULL,
    country VARCHAR(50) NOT NULL DEFAULT 'Unknown',
    rate DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    type VARCHAR(20) DEFAULT 'Local',
    status ENUM('Available', 'Active', 'Suspended') DEFAULT 'Available',
    notes TEXT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL,
    INDEX customer_idx (customer_id),
    INDEX status_idx (status),
    INDEX number_idx (number)
);

-- Create users table for authentication
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    role ENUM('admin', 'customer', 'operator') NOT NULL DEFAULT 'customer',
    status ENUM('active', 'inactive', 'suspended') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create PJSIP tables
CREATE TABLE ps_endpoints (
    id VARCHAR(40) NOT NULL PRIMARY KEY,
    transport VARCHAR(40) DEFAULT NULL,
    aors VARCHAR(200) DEFAULT NULL,
    auth VARCHAR(40) DEFAULT NULL,
    context VARCHAR(40) DEFAULT NULL,
    disallow VARCHAR(200) DEFAULT NULL,
    allow VARCHAR(200) DEFAULT NULL,
    direct_media ENUM('yes','no') DEFAULT 'yes',
    dtmf_mode ENUM('rfc4733','inband','info','auto','auto_info') DEFAULT 'rfc4733',
    force_rport ENUM('yes','no') DEFAULT 'yes',
    ice_support ENUM('yes','no') DEFAULT 'no',
    identify_by ENUM('username','auth_username','endpoint') DEFAULT 'username',
    callerid VARCHAR(40) DEFAULT NULL,
    accountcode VARCHAR(40) DEFAULT NULL
);

CREATE TABLE ps_auths (
    id VARCHAR(40) NOT NULL PRIMARY KEY,
    auth_type ENUM('md5','userpass') DEFAULT 'userpass',
    password VARCHAR(80) DEFAULT NULL,
    username VARCHAR(40) DEFAULT NULL
);

CREATE TABLE ps_aors (
    id VARCHAR(40) NOT NULL PRIMARY KEY,
    max_contacts INT DEFAULT 1,
    remove_existing INT DEFAULT 0,
    qualify_frequency INT DEFAULT 0
);

CREATE TABLE ps_contacts (
    id VARCHAR(255) NOT NULL PRIMARY KEY,
    uri VARCHAR(511) DEFAULT NULL,
    expiration_time VARCHAR(40) DEFAULT NULL,
    qualify_2xx_only ENUM('yes','no') NOT NULL DEFAULT 'no',
    endpoint VARCHAR(40) DEFAULT NULL
);

-- Insert sample data
INSERT INTO customers (id, name, email, phone, type, balance, status) VALUES
('C001', 'John Doe', 'john@example.com', '+1-555-0123', 'Prepaid', 125.50, 'Active'),
('C002', 'Jane Smith', 'jane@example.com', '+1-555-0456', 'Postpaid', -45.20, 'Active'),
('C003', 'Bob Johnson', 'bob@example.com', '+1-555-0789', 'Prepaid', 75.00, 'Active'),
('C004', 'Alice Cooper', 'alice@example.com', '+1-555-0321', 'Prepaid', 200.00, 'Active'),
('C005', 'David Wilson', 'david@example.com', '+1-555-0654', 'Postpaid', 0.00, 'Suspended');

-- Insert rates data
INSERT INTO rates (destination_prefix, destination_name, rate_per_minute, billing_increment, effective_date) VALUES
('1', 'USA/Canada', 0.0120, 60, CURDATE()),
('44', 'United Kingdom', 0.0250, 60, CURDATE()),
('49', 'Germany', 0.0280, 60, CURDATE()),
('33', 'France', 0.0240, 60, CURDATE()),
('91', 'India', 0.0180, 60, CURDATE()),
('86', 'China', 0.0150, 60, CURDATE()),
('81', 'Japan', 0.0200, 60, CURDATE()),
('678', 'Vanuatu', 0.0350, 60, CURDATE());

-- Insert sample DID numbers with CORRECT schema
INSERT INTO did_numbers (number, customer_id, customer_name, country, rate, type, status, notes) VALUES
('+1-555-1001', 'C001', 'John Doe', 'USA', 5.00, 'Local', 'Active', 'Primary DID for John Doe'),
('+1-555-1002', 'C002', 'Jane Smith', 'USA', 5.00, 'Active', 'Local', 'Primary DID for Jane Smith'),
('+1-555-1003', NULL, NULL, 'USA', 5.00, 'Local', 'Available', 'Available for assignment'),
('+1-555-1004', 'C003', 'Bob Johnson', 'USA', 5.00, 'Local', 'Active', 'Primary DID for Bob Johnson'),
('+1-555-1005', NULL, NULL, 'USA', 5.00, 'Local', 'Available', 'Available for assignment'),
('+678-12345', NULL, NULL, 'Vanuatu', 8.00, 'Local', 'Available', 'Vanuatu local number');

-- Insert default admin user (password: admin123)
INSERT INTO users (username, password, email, role, status) VALUES 
('admin', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin@ibilling.local', 'admin', 'active');

-- Insert sample CDR records
INSERT INTO cdr (calldate, src, dst, duration, billsec, disposition, accountcode) VALUES
(NOW() - INTERVAL 1 HOUR, '+1-555-0123', '+1-555-9999', 300, 295, 'ANSWERED', 'C001'),
(NOW() - INTERVAL 2 HOUR, '+1-555-0456', '+44-20-7946-0958', 180, 175, 'ANSWERED', 'C002'),
(NOW() - INTERVAL 3 HOUR, '+1-555-0789', '+49-30-12345678', 120, 0, 'NO ANSWER', 'C003'),
(NOW() - INTERVAL 4 HOUR, '+1-555-0321', '+33-1-42-86-83-26', 450, 445, 'ANSWERED', 'C004'),
(NOW() - INTERVAL 5 HOUR, '+1-555-0654', '+91-11-23456789', 90, 85, 'ANSWERED', 'C005');
EOF
    
    if [ $? -eq 0 ]; then
        print_status "✓ Complete database schema created successfully with CORRECT DID table structure"
    else
        print_error "✗ Failed to create complete database schema"
        return 1
    fi
    
    # Test asterisk user connection
    print_status "4. Testing asterisk user connection..."
    if mysql -u asterisk -p"${asterisk_db_password}" asterisk -e "SELECT COUNT(*) FROM customers;" >/dev/null 2>&1; then
        print_status "✓ Asterisk user can access database successfully"
    else
        print_error "✗ Asterisk user cannot access database"
        return 1
    fi
    
    # Update backend environment
    print_status "5. Updating backend environment..."
    if [ -f "/opt/billing/.env" ]; then
        sudo sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=${asterisk_db_password}/" /opt/billing/.env
        print_status "✓ Backend environment updated"
    else
        print_warning "⚠ Backend environment file not found"
    fi
    
    # Restart backend service
    print_status "6. Restarting backend service..."
    sudo systemctl restart ibilling-backend
    sleep 5
    
    # Show final status
    print_status "7. Final verification..."
    customer_count=$(mysql -u asterisk -p"${asterisk_db_password}" asterisk -sN -e "SELECT COUNT(*) FROM customers;" 2>/dev/null)
    rates_count=$(mysql -u asterisk -p"${asterisk_db_password}" asterisk -sN -e "SELECT COUNT(*) FROM rates;" 2>/dev/null)
    did_count=$(mysql -u asterisk -p"${asterisk_db_password}" asterisk -sN -e "SELECT COUNT(*) FROM did_numbers;" 2>/dev/null)
    
    # Verify DID table structure
    did_columns=$(mysql -u asterisk -p"${asterisk_db_password}" asterisk -sN -e "SHOW COLUMNS FROM did_numbers;" 2>/dev/null | wc -l)
    
    print_status "Database verification:"
    print_status "- Customers: ${customer_count:-0}"
    print_status "- Rates: ${rates_count:-0}"
    print_status "- DID Numbers: ${did_count:-0}"
    print_status "- DID Table Columns: ${did_columns:-0} (should be 10+)"
    
    # Test if required columns exist
    customer_name_exists=$(mysql -u asterisk -p"${asterisk_db_password}" asterisk -sN -e "SHOW COLUMNS FROM did_numbers LIKE 'customer_name';" 2>/dev/null | wc -l)
    country_exists=$(mysql -u asterisk -p"${asterisk_db_password}" asterisk -sN -e "SHOW COLUMNS FROM did_numbers LIKE 'country';" 2>/dev/null | wc -l)
    rate_exists=$(mysql -u asterisk -p"${asterisk_db_password}" asterisk -sN -e "SHOW COLUMNS FROM did_numbers LIKE 'rate';" 2>/dev/null | wc -l)
    
    print_status "Required DID columns verification:"
    print_status "- customer_name column: ${customer_name_exists:-0} (should be 1)"
    print_status "- country column: ${country_exists:-0} (should be 1)"
    print_status "- rate column: ${rate_exists:-0} (should be 1)"
    
    if [ "${customer_name_exists:-0}" -eq 1 ] && [ "${country_exists:-0}" -eq 1 ] && [ "${rate_exists:-0}" -eq 1 ]; then
        print_status "✅ All required DID columns are present - DID creation should work!"
    else
        print_error "❌ Some required DID columns are missing"
        print_status "Current DID table structure:"
        mysql -u asterisk -p"${asterisk_db_password}" asterisk -e "DESCRIBE did_numbers;" 2>/dev/null
        return 1
    fi
    
    print_status "✅ Complete database schema fix completed successfully!"
    print_status ""
    print_status "Database credentials:"
    print_status "- MySQL root password: ${mysql_root_password}"
    print_status "- Asterisk DB password: ${asterisk_db_password}"
    print_status ""
    print_status "✅ DID creation should now work without 'Unknown column' errors!"
    
    return 0
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -eq 0 ]; then
        echo "Usage: $0 <mysql_root_password> [asterisk_db_password]"
        echo "   or: $0 (will prompt for passwords)"
        exit 1
    fi
    
    fix_complete_database_schema "$1" "$2"
fi
