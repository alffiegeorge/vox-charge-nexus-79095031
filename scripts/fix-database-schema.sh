
#!/bin/bash

# Fix database schema - create all missing tables
source "$(dirname "$0")/utils.sh"

fix_database_schema() {
    print_status "Fixing database schema - creating all missing tables..."
    
    # Get database credentials
    echo "Enter MySQL root password:"
    read -s mysql_root_password
    
    if [ -z "$mysql_root_password" ]; then
        print_error "MySQL root password required"
        exit 1
    fi
    
    print_status "Testing database connection..."
    if ! mysql -u root -p"${mysql_root_password}" -e "USE asterisk; SELECT 1;" >/dev/null 2>&1; then
        print_error "Cannot connect to asterisk database"
        exit 1
    fi
    
    print_status "✓ Database connection successful"
    
    print_status "Creating all missing tables..."
    
    # Execute the complete schema
    mysql -u root -p"${mysql_root_password}" asterisk <<'EOF'
-- Create all missing tables for iBilling

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

-- Insert sample data
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

    print_status "✓ Database schema completed successfully"
    
    # Show final table count
    print_status "Checking created tables..."
    mysql -u root -p"${mysql_root_password}" asterisk -e "SHOW TABLES;" | tail -n +2 | wc -l | xargs echo "Total tables created:"
    
    print_status "Tables in database:"
    mysql -u root -p"${mysql_root_password}" asterisk -e "SHOW TABLES;"
    
    print_status "Sample customer data:"
    mysql -u root -p"${mysql_root_password}" asterisk -e "SELECT id, name, email, balance, status FROM customers LIMIT 5;"
    
    print_status "✅ Database setup completed successfully!"
    print_status "You can now restart your backend service and test the application"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    fix_database_schema
fi
