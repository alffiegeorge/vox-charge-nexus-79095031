
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
    
    # Create complete schema
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
DROP TABLE IF EXISTS trunks;
DROP TABLE IF EXISTS routes;
DROP TABLE IF EXISTS sipusers;
DROP TABLE IF EXISTS voicemail;
DROP TABLE IF EXISTS sms_templates;

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

-- Create DID numbers table with correct schema that matches backend expectations
CREATE TABLE did_numbers (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    number VARCHAR(20) NOT NULL UNIQUE,
    customer_id VARCHAR(20) DEFAULT NULL,
    customer_name VARCHAR(100) DEFAULT 'Unassigned',
    monthly_cost DECIMAL(8,2) NOT NULL DEFAULT 0.00,
    setup_cost DECIMAL(8,2) NOT NULL DEFAULT 0.00,
    status ENUM('Available', 'Active', 'Suspended') DEFAULT 'Available',
    country VARCHAR(50) DEFAULT 'Unknown', 
    region VARCHAR(50) DEFAULT NULL,
    rate DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    type VARCHAR(20) DEFAULT 'Local',
    features JSON DEFAULT NULL,
    assigned_date DATE DEFAULT NULL,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL,
    INDEX customer_idx (customer_id),
    INDEX status_idx (status)
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

-- Create admin users table
CREATE TABLE admin_users (
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

-- Create PJSIP tables with correct columns for Asterisk 22
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
    accountcode VARCHAR(40) DEFAULT NULL,
    rtp_symmetric ENUM('yes','no') DEFAULT 'no',
    send_rpid ENUM('yes','no') DEFAULT 'no'
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

-- Create trunks table
CREATE TABLE trunks (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    provider VARCHAR(100) DEFAULT NULL,
    sip_server VARCHAR(100) NOT NULL,
    username VARCHAR(50) DEFAULT NULL,
    password VARCHAR(100) DEFAULT NULL,
    max_channels INT DEFAULT 30,
    status ENUM('Active', 'Inactive', 'Standby') DEFAULT 'Active',
    quality VARCHAR(20) DEFAULT 'Good',
    notes TEXT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create routes table
CREATE TABLE routes (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    pattern VARCHAR(50) NOT NULL,
    destination VARCHAR(50) NOT NULL,
    trunk_name VARCHAR(50) NOT NULL,
    priority INT DEFAULT 1,
    status ENUM('Active', 'Inactive') DEFAULT 'Active',
    notes TEXT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX pattern_idx (pattern),
    INDEX priority_idx (priority)
);

-- Create invoices table
CREATE TABLE invoices (
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

-- Create invoice items table
CREATE TABLE invoice_items (
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

-- Create payments table
CREATE TABLE payments (
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

-- Create SMS messages table
CREATE TABLE sms_messages (
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

-- Create SMS templates table
CREATE TABLE sms_templates (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    template TEXT NOT NULL,
    variables VARCHAR(500) DEFAULT NULL,
    category VARCHAR(50) DEFAULT 'General',
    status ENUM('Active', 'Inactive') DEFAULT 'Active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create support tickets table
CREATE TABLE support_tickets (
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

-- Create audit logs table
CREATE TABLE audit_logs (
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

-- Create system settings table
CREATE TABLE system_settings (
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

-- Create legacy sipusers table for compatibility
CREATE TABLE sipusers (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(40) NOT NULL UNIQUE,
    secret VARCHAR(40) NOT NULL,
    context VARCHAR(40) DEFAULT 'from-internal',
    host VARCHAR(40) DEFAULT 'dynamic',
    type VARCHAR(10) DEFAULT 'friend',
    accountcode VARCHAR(20) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create voicemail table
CREATE TABLE voicemail (
    uniqueid INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    customer_id VARCHAR(20) DEFAULT NULL,
    context VARCHAR(40) DEFAULT 'default',
    mailbox VARCHAR(40) NOT NULL,
    password VARCHAR(10) NOT NULL,
    fullname VARCHAR(100) DEFAULT NULL,
    email VARCHAR(100) DEFAULT NULL,
    pager VARCHAR(100) DEFAULT NULL,
    options VARCHAR(500) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL,
    UNIQUE KEY mailbox_context (mailbox, context)
);

-- Insert sample data
INSERT INTO customers (id, name, email, phone, type, balance, status) VALUES
('C001', 'John Doe', 'john@example.com', '+1-555-0123', 'Prepaid', 125.50, 'Active'),
('C002', 'Jane Smith', 'jane@example.com', '+1-555-0456', 'Postpaid', -45.20, 'Active'),
('C003', 'Bob Johnson', 'bob@example.com', '+1-555-0789', 'Prepaid', 75.00, 'Active'),
('C004', 'Alice Cooper', 'alice@example.com', '+1-555-0321', 'Prepaid', 200.00, 'Active'),
('C005', 'David Wilson', 'david@example.com', '+1-555-0654', 'Postpaid', 0.00, 'Suspended'),
('C006', 'Emma Brown', 'emma@example.com', '+1-555-0987', 'Prepaid', 150.75, 'Active'),
('C007', 'Michael Davis', 'michael@example.com', '+1-555-0147', 'Postpaid', 75.25, 'Active'),
('C008', 'Sarah Miller', 'sarah@example.com', '+1-555-0258', 'Prepaid', 300.00, 'Active');

-- Insert rates data  
INSERT INTO rates (destination_prefix, destination_name, rate_per_minute, billing_increment, effective_date) VALUES
('1', 'USA/Canada', 0.0120, 60, CURDATE()),
('44', 'United Kingdom', 0.0250, 60, CURDATE()),
('49', 'Germany', 0.0280, 60, CURDATE()),
('33', 'France', 0.0240, 60, CURDATE()),
('91', 'India', 0.0180, 60, CURDATE()),
('86', 'China', 0.0150, 60, CURDATE()),
('81', 'Japan', 0.0200, 60, CURDATE()),
('678', 'Vanuatu', 0.0350, 60, CURDATE()),
('39', 'Italy', 0.0260, 60, CURDATE()),
('34', 'Spain', 0.0230, 60, CURDATE()),
('61', 'Australia', 0.0220, 60, CURDATE()),
('82', 'South Korea', 0.0190, 60, CURDATE()),
('55', 'Brazil', 0.0280, 60, CURDATE()),
('7', 'Russia', 0.0320, 60, CURDATE()),
('52', 'Mexico', 0.0180, 60, CURDATE()),
('31', 'Netherlands', 0.0240, 60, CURDATE()),
('46', 'Sweden', 0.0260, 60, CURDATE()),
('47', 'Norway', 0.0280, 60, CURDATE()),
('45', 'Denmark', 0.0250, 60, CURDATE()),
('358', 'Finland', 0.0270, 60, CURDATE());

-- Insert sample DID numbers
INSERT INTO did_numbers (number, customer_id, customer_name, monthly_cost, status, country, region, rate, type) VALUES
('+1-555-1001', 'C001', 'John Doe', 5.00, 'Active', 'USA', 'New York', 5.00, 'Local'),
('+1-555-1002', 'C002', 'Jane Smith', 5.00, 'Active', 'USA', 'California', 5.00, 'Local'),
('+1-555-1003', NULL, 'Unassigned', 5.00, 'Available', 'USA', 'Texas', 5.00, 'Local'),
('+1-555-1004', 'C003', 'Bob Johnson', 5.00, 'Active', 'USA', 'Florida', 5.00, 'Local'),
('+1-555-1005', NULL, 'Unassigned', 5.00, 'Available', 'USA', 'Illinois', 5.00, 'Local'),
('+678-12345', NULL, 'Unassigned', 8.00, 'Available', 'Vanuatu', 'Port Vila', 8.00, 'Local'),
('+1-800-555-0103', NULL, 'Unassigned', 15.00, 'Available', 'USA', 'Nationwide', 15.00, 'Toll-Free'),
('+44-20-7946-0958', 'C004', 'Alice Cooper', 8.00, 'Active', 'UK', 'London', 8.00, 'Local'),
('+678-555-0104', NULL, 'Unassigned', 3.00, 'Available', 'Vanuatu', 'Efate', 3.00, 'Local'),
('+678-555-0105', 'C005', 'David Wilson', 3.00, 'Suspended', 'Vanuatu', 'Efate', 3.00, 'Local');

-- Insert default admin user (password: admin123)
INSERT INTO users (username, password, email, role, status) VALUES 
('admin', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin@ibilling.local', 'admin', 'active');

INSERT INTO admin_users (username, email, password_hash, salt, full_name, role, status) VALUES
('admin', 'admin@ibilling.com', 'hash_placeholder', 'salt_placeholder', 'System Administrator', 'Super Admin', 'Active'),
('operator1', 'operator1@ibilling.com', 'hash_placeholder', 'salt_placeholder', 'John Operator', 'Operator', 'Active'),
('support1', 'support1@ibilling.com', 'hash_placeholder', 'salt_placeholder', 'Jane Support', 'Support', 'Active');

-- Insert sample trunks
INSERT INTO trunks (name, provider, sip_server, username, max_channels, status, quality, notes) VALUES
('Primary-SIP-Trunk', 'VoIP Provider A', 'sip.provider-a.com', 'user123', 30, 'Active', 'Good', 'Primary trunk for outbound calls'),
('Backup-SIP-Trunk', 'VoIP Provider B', 'sip.provider-b.com', 'backup456', 20, 'Standby', 'Fair', 'Backup trunk for failover'),
('Local-Trunk', 'Local Telco', 'sip.local-telco.vu', 'local789', 15, 'Active', 'Excellent', 'Local carrier trunk'),
('Emergency-Trunk', 'Emergency Provider', 'sip.emergency.com', 'emergency999', 10, 'Active', 'Good', 'Emergency services trunk');

-- Insert sample routes
INSERT INTO routes (pattern, destination, trunk_name, priority, status, notes) VALUES
('_678XXXXXXX', 'Local', 'Local-Trunk', 1, 'Active', 'Route local Vanuatu calls to local trunk'),
('_1XXXXXXXXXX', 'USA', 'Primary-SIP-Trunk', 2, 'Active', 'Route USA calls to primary trunk'),
('_44XXXXXXXXX', 'UK', 'Primary-SIP-Trunk', 3, 'Active', 'Route UK calls to primary trunk'),
('_911', 'Emergency', 'Emergency-Trunk', 1, 'Active', 'Emergency calls routing'),
('_X.', 'International', 'Primary-SIP-Trunk', 10, 'Active', 'Default route for all other calls');

-- Insert sample CDR records
INSERT INTO cdr (calldate, src, dst, duration, billsec, disposition, accountcode) VALUES
(NOW() - INTERVAL 1 HOUR, '+1-555-0123', '+1-555-9999', 300, 295, 'ANSWERED', 'C001'),
(NOW() - INTERVAL 2 HOUR, '+1-555-0456', '+44-20-7946-0958', 180, 175, 'ANSWERED', 'C002'),
(NOW() - INTERVAL 3 HOUR, '+1-555-0789', '+49-30-12345678', 120, 0, 'NO ANSWER', 'C003'),
(NOW() - INTERVAL 4 HOUR, '+1-555-0321', '+33-1-42-86-83-26', 450, 445, 'ANSWERED', 'C004'),
(NOW() - INTERVAL 5 HOUR, '+1-555-0654', '+91-11-23456789', 90, 85, 'ANSWERED', 'C005'),
(NOW() - INTERVAL 6 HOUR, '+1-555-0987', '+86-10-12345678', 200, 195, 'ANSWERED', 'C006'),
(NOW() - INTERVAL 7 HOUR, '+1-555-0147', '+39-06-12345678', 150, 145, 'ANSWERED', 'C007'),
(NOW() - INTERVAL 8 HOUR, '+1-555-0258', '+34-91-1234567', 320, 315, 'ANSWERED', 'C008'),
(NOW() - INTERVAL 9 HOUR, '+678-12345', '+61-2-12345678', 240, 235, 'ANSWERED', 'C001'),
(NOW() - INTERVAL 10 HOUR, '+1-555-1001', '+82-2-12345678', 180, 175, 'ANSWERED', 'C002');

-- Insert sample invoices
INSERT INTO invoices (invoice_number, customer_id, invoice_date, due_date, subtotal, tax_amount, total_amount, status) VALUES
('INV-2024-001', 'C001', CURDATE() - INTERVAL 30 DAY, CURDATE() - INTERVAL 15 DAY, 25.50, 2.55, 28.05, 'Paid'),
('INV-2024-002', 'C002', CURDATE() - INTERVAL 25 DAY, CURDATE() - INTERVAL 10 DAY, 45.20, 4.52, 49.72, 'Overdue'),
('INV-2024-003', 'C003', CURDATE() - INTERVAL 20 DAY, CURDATE() - INTERVAL 5 DAY, 18.75, 1.88, 20.63, 'Paid'),
('INV-2024-004', 'C004', CURDATE() - INTERVAL 15 DAY, CURDATE(), 32.40, 3.24, 35.64, 'Sent'),
('INV-2024-005', 'C005', CURDATE() - INTERVAL 10 DAY, CURDATE() + INTERVAL 5 DAY, 15.60, 1.56, 17.16, 'Draft'),
('INV-2024-006', 'C006', CURDATE() - INTERVAL 5 DAY, CURDATE() + INTERVAL 10 DAY, 28.90, 2.89, 31.79, 'Sent');

-- Insert sample invoice items  
INSERT INTO invoice_items (invoice_id, description, quantity, unit_price, total_price, item_type) VALUES
(1, 'Outbound calls to USA', 125.5, 0.0120, 1.506, 'Call'),
(1, 'DID monthly fee', 1, 5.00, 5.00, 'DID'),
(2, 'Outbound calls to UK',  85.2, 0.0250, 2.130, 'Call'),
(2, 'SMS messages', 25, 0.05, 1.25, 'SMS'),
(3, 'Outbound calls to Germany', 67.8, 0.0280, 1.898, 'Call'),
(3, 'DID monthly fee', 1, 5.00, 5.00, 'DID'),
(4, 'Outbound calls to France', 95.4, 0.0240, 2.290, 'Call'),
(4, 'Premium support', 1, 10.00, 10.00, 'Service'),
(5, 'Outbound calls to India', 78.6, 0.0180, 1.415, 'Call'),
(5, 'DID setup fee', 1, 15.00, 15.00, 'DID'),
(6, 'Outbound calls to China', 112.3, 0.0150, 1.685, 'Call'),
(6, 'Monthly service fee', 1, 25.00, 25.00, 'Service');

-- Insert sample payments
INSERT INTO payments (customer_id, invoice_id, payment_method, amount, status, reference_number) VALUES
('C001', 1, 'Bank Transfer', 28.05, 'Completed', 'TXN-2024-001'),
('C003', 3, 'Credit Card', 20.63, 'Completed', 'TXN-2024-002'),
('C004', NULL, 'Mobile Money', 50.00, 'Completed', 'TXN-2024-003'),
('C006', NULL, 'Cash', 100.00, 'Completed', 'TXN-2024-004'),
('C002', 2, 'Bank Transfer', 25.00, 'Pending', 'TXN-2024-005');

-- Insert sample SMS messages
INSERT INTO sms_messages (customer_id, from_number, to_number, message, direction, status, cost) VALUES
('C001', '+1-555-1001', '+1-555-9999', 'Welcome to iBilling!', 'Outbound', 'Delivered', 0.05),
('C002', '+1-555-1002', '+44-20-7946-0958', 'Your payment is due', 'Outbound', 'Delivered', 0.08),
('C003', '+1-555-9876', '+1-555-1004', 'Thanks for your call', 'Inbound', 'Delivered', 0.00),
('C004', '+1-555-1001', '+33-1-42-86-83-26', 'Service maintenance notice', 'Outbound', 'Sent', 0.07),
('C005', '+1-555-5555', '+1-555-0654', 'Account suspended', 'Inbound', 'Failed', 0.00),
('C006', '+1-555-1005', '+86-10-12345678', 'New feature available', 'Outbound', 'Delivered', 0.06);

-- Insert sample SMS templates
INSERT INTO sms_templates (name, template, variables, category, status) VALUES
('Welcome Message', 'Welcome to iBilling, {customer_name}! Your account is now active.', 'customer_name', 'Welcome', 'Active'),
('Payment Reminder', 'Hi {customer_name}, your payment of {amount} is due on {due_date}.', 'customer_name,amount,due_date', 'Billing', 'Active'),
('Low Balance Alert', 'Your account balance is low: {balance}. Please top up.', 'balance', 'Alerts', 'Active'),
('Service Maintenance', 'Scheduled maintenance on {date} from {start_time} to {end_time}.', 'date,start_time,end_time', 'Maintenance', 'Active'),
('Payment Confirmation', 'Payment of {amount} received. Thank you!', 'amount', 'Billing', 'Active'),
('Account Suspension', 'Your account has been suspended. Please contact support.', '', 'Alerts', 'Active'),
('New Feature', 'New feature available: {feature_name}. Check it out!', 'feature_name', 'Marketing', 'Active');

-- Insert sample support tickets
INSERT INTO support_tickets (ticket_number, customer_id, subject, description, priority, status) VALUES
('TKT-2024-001', 'C001', 'Call quality issues', 'Experiencing poor call quality on outbound calls', 'High', 'In Progress'),
('TKT-2024-002', 'C002', 'Billing question', 'Need clarification on recent charges', 'Medium', 'Open'),
('TKT-2024-003', 'C003', 'Feature request', 'Would like to add call recording feature', 'Low', 'Open'),
('TKT-2024-004', 'C004', 'Account access', 'Cannot login to web portal', 'High', 'Resolved'),
('TKT-2024-005', 'C005', 'Service restoration', 'Request to restore suspended service', 'Critical', 'Open');

-- Insert sample audit logs
INSERT INTO audit_logs (user_id, user_type, action, table_name, record_id, ip_address) VALUES
(1, 'admin', 'CREATE', 'customers', 'C006', '192.168.1.100'),
(1, 'admin', 'UPDATE', 'did_numbers', '1', '192.168.1.100'),
(1, 'admin', 'DELETE', 'invoices', '999', '192.168.1.100'),
(2, 'admin', 'CREATE', 'rates', '15', '192.168.1.101'),
(1, 'admin', 'UPDATE', 'customers', 'C001', '192.168.1.100');

-- Insert sample system settings
INSERT INTO system_settings (setting_key, setting_value, setting_type, category, description) VALUES
('company_name', 'iBilling Communications', 'string', 'general', 'Company name displayed in the system'),
('system_email', 'admin@ibilling.com', 'string', 'general', 'System email address for notifications'),
('currency', 'VUV', 'string', 'general', 'Default currency for billing'),
('timezone', 'Pacific/Efate', 'string', 'general', 'System timezone'),
('minimum_credit', '5.00', 'number', 'billing', 'Minimum credit required'),
('low_balance_warning', '10.00', 'number', 'billing', 'Low balance warning threshold'),
('auto_suspend', 'false', 'boolean', 'billing', 'Auto-suspend accounts on zero balance'),
('email_notifications', 'true', 'boolean', 'billing', 'Enable email notifications'),
('asterisk_server_ip', '172.31.10.10', 'string', 'asterisk', 'Asterisk server IP address'),
('ami_port', '5038', 'string', 'asterisk', 'Asterisk AMI port'),
('ami_username', 'admin', 'string', 'asterisk', 'Asterisk AMI username'),
('session_timeout', '30', 'number', 'security', 'Session timeout in minutes');

-- Insert sample sipusers (legacy)
INSERT INTO sipusers (name, secret, context, accountcode) VALUES
('1001', 'secret123', 'from-internal', 'C001'),
('1002', 'secret456', 'from-internal', 'C002'),
('1003', 'secret789', 'from-internal', 'C003'),
('1004', 'secret000', 'from-internal', 'C004');

-- Insert sample voicemail
INSERT INTO voicemail (customer_id, mailbox, password, fullname, email) VALUES
('C001', '1001', '1234', 'John Doe', 'john@example.com'),
('C002', '1002', '1234', 'Jane Smith', 'jane@example.com'),
('C003', '1003', '1234', 'Bob Johnson', 'bob@example.com'),
('C004', '1004', '1234', 'Alice Cooper', 'alice@example.com');
EOF
    
    if [ $? -eq 0 ]; then
        print_status "✓ Complete database schema created successfully"
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
    
    print_status "Database verification:"
    print_status "- Customers: ${customer_count:-0}"
    print_status "- Rates: ${rates_count:-0}"
    print_status "- DID Numbers: ${did_count:-0}"
    
    print_status "✅ Complete database schema fix completed successfully!"
    print_status ""
    print_status "Database credentials:"
    print_status "- MySQL root password: ${mysql_root_password}"
    print_status "- Asterisk DB password: ${asterisk_db_password}"
    print_status ""
    print_status "You can now try creating DIDs through the web interface."
    
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
