
-- iBilling Database Schema
-- CDR Table for Call Detail Records
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

-- SIP Peers table (alternative to sipusers)
CREATE TABLE IF NOT EXISTS sippeers (
    id INT(11) NOT NULL AUTO_INCREMENT,
    name VARCHAR(40) NOT NULL,
    host VARCHAR(40) DEFAULT 'dynamic',
    nat VARCHAR(40) DEFAULT 'yes',
    type ENUM('friend','user','peer') DEFAULT 'friend',
    accountcode VARCHAR(20) DEFAULT NULL,
    amaflags VARCHAR(13) DEFAULT NULL,
    callgroup VARCHAR(40) DEFAULT NULL,
    callerid VARCHAR(40) DEFAULT NULL,
    canreinvite VARCHAR(20) DEFAULT 'yes',
    context VARCHAR(40) DEFAULT NULL,
    defaultuser VARCHAR(40) DEFAULT NULL,
    dtmfmode VARCHAR(20) DEFAULT NULL,
    fromuser VARCHAR(40) DEFAULT NULL,
    fromdomain VARCHAR(40) DEFAULT NULL,
    insecure VARCHAR(40) DEFAULT NULL,
    language VARCHAR(40) DEFAULT NULL,
    mailbox VARCHAR(40) DEFAULT NULL,
    md5secret VARCHAR(40) DEFAULT NULL,
    deny VARCHAR(95) DEFAULT NULL,
    permit VARCHAR(95) DEFAULT NULL,
    mask VARCHAR(95) DEFAULT NULL,
    musiconhold VARCHAR(40) DEFAULT NULL,
    pickupgroup VARCHAR(40) DEFAULT NULL,
    qualify VARCHAR(20) DEFAULT NULL,
    regexten VARCHAR(40) DEFAULT NULL,
    restrictcid VARCHAR(20) DEFAULT NULL,
    rtptimeout VARCHAR(20) DEFAULT NULL,
    rtpholdtimeout VARCHAR(20) DEFAULT NULL,
    secret VARCHAR(40) DEFAULT NULL,
    setvar VARCHAR(40) DEFAULT NULL,
    disallow VARCHAR(200) DEFAULT 'all',
    allow VARCHAR(200) DEFAULT 'g729,ilbc,gsm,ulaw,alaw',
    fullcontact VARCHAR(80) NOT NULL DEFAULT '',
    ipaddr VARCHAR(45) NOT NULL DEFAULT '',
    port INT(5) NOT NULL DEFAULT 0,
    regserver VARCHAR(40) DEFAULT NULL,
    regseconds INT(11) NOT NULL DEFAULT 0,
    lastms INT(11) NOT NULL DEFAULT 0,
    username VARCHAR(40) NOT NULL DEFAULT '',
    PRIMARY KEY (id),
    UNIQUE KEY name (name),
    KEY host (host,port)
);

-- Voicemail table
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
    PRIMARY KEY (id),
    KEY mailbox_context (mailbox, context)
);

-- Billing related tables
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

-- Admin Users table
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

-- Audit Logs table
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

-- Payments table
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

-- Support Tickets table
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

-- Insert default system settings
INSERT IGNORE INTO system_settings (setting_key, setting_value, setting_type, category, description) VALUES
('company_name', 'iBilling Communications', 'string', 'general', 'Company name displayed in the system'),
('system_email', 'admin@ibilling.com', 'string', 'general', 'System email address for notifications'),
('currency', 'VUV', 'string', 'general', 'Default currency for billing'),
('timezone', 'Pacific/Efate', 'string', 'general', 'System timezone'),
('minimum_credit', '5.00', 'number', 'billing', 'Minimum credit required'),
('low_balance_warning', '10.00', 'number', 'billing', 'Low balance warning threshold'),
('auto_suspend', 'false', 'boolean', 'billing', 'Auto-suspend accounts on zero balance'),
('email_notifications', 'true', 'boolean', 'billing', 'Enable email notifications'),
('asterisk_server_ip', '192.168.1.100', 'string', 'asterisk', 'Asterisk server IP address'),
('ami_port', '5038', 'string', 'asterisk', 'Asterisk AMI port'),
('ami_username', 'admin', 'string', 'asterisk', 'Asterisk AMI username'),
('session_timeout', '30', 'number', 'security', 'Session timeout in minutes'),
('force_password_change', 'false', 'boolean', 'security', 'Force password change on first login'),
('two_factor_auth', 'false', 'boolean', 'security', 'Enable two-factor authentication'),
('login_attempt_limit', 'true', 'boolean', 'security', 'Enable login attempt limiting'),
('max_login_attempts', '5', 'number', 'security', 'Maximum login attempts before lockout');

-- Insert sample data
INSERT IGNORE INTO customers (id, name, email, phone, type, balance, status, qr_code_enabled) VALUES
('C001', 'John Doe', 'john@example.com', '+1-555-0123', 'Prepaid', 125.50, 'Active', TRUE),
('C002', 'Jane Smith', 'jane@example.com', '+1-555-0456', 'Postpaid', -45.20, 'Active', TRUE),
('C003', 'Bob Johnson', 'bob@example.com', '+1-555-0789', 'Prepaid', 0.00, 'Suspended', FALSE);

INSERT IGNORE INTO rates (destination_prefix, destination_name, rate_per_minute, billing_increment) VALUES
('1', 'USA/Canada', 0.0120, 60),
('44', 'United Kingdom', 0.0250, 60),
('49', 'Germany', 0.0280, 60),
('33', 'France', 0.0240, 60),
('91', 'India', 0.0180, 60);

-- Create default admin user (password: admin123)
INSERT IGNORE INTO admin_users (username, email, password_hash, salt, full_name, role, status) VALUES
('admin', 'admin@ibilling.com', 'hash_placeholder', 'salt_placeholder', 'System Administrator', 'Super Admin', 'Active');
