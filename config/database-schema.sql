-- iBilling Database Schema - Updated for Asterisk 22 Compatibility
-- PJSIP Realtime Tables for Asterisk 22
-- These tables support Asterisk's realtime configuration for PJSIP

-- PJSIP Endpoints table
CREATE TABLE IF NOT EXISTS ps_endpoints (
    id VARCHAR(40) NOT NULL,
    transport VARCHAR(40) DEFAULT NULL,
    aors VARCHAR(200) DEFAULT NULL,
    auth VARCHAR(40) DEFAULT NULL,
    context VARCHAR(40) DEFAULT NULL,
    disallow VARCHAR(200) DEFAULT NULL,
    allow VARCHAR(200) DEFAULT NULL,
    direct_media ENUM('yes','no') DEFAULT 'yes',
    connected_line_method ENUM('invite','reinvite','update') DEFAULT 'invite',
    direct_media_method ENUM('invite','reinvite','update') DEFAULT 'invite',
    direct_media_glare_mitigation ENUM('none','outgoing','incoming') DEFAULT 'none',
    disable_direct_media_on_nat ENUM('yes','no') DEFAULT 'no',
    dtmf_mode ENUM('rfc4733','inband','info','auto','auto_info') DEFAULT 'rfc4733',
    external_media_address VARCHAR(40) DEFAULT NULL,
    force_rport ENUM('yes','no') DEFAULT 'yes',
    ice_support ENUM('yes','no') DEFAULT 'no',
    identify_by ENUM('username','auth_username','endpoint') DEFAULT 'username',
    mailboxes VARCHAR(40) DEFAULT NULL,
    moh_suggest VARCHAR(40) DEFAULT NULL,
    outbound_auth VARCHAR(40) DEFAULT NULL,
    outbound_proxy VARCHAR(40) DEFAULT NULL,
    rewrite_contact ENUM('yes','no') DEFAULT 'no',
    rtp_ipv6 ENUM('yes','no') DEFAULT 'no',
    rtp_symmetric ENUM('yes','no') DEFAULT 'no',
    send_diversion ENUM('yes','no') DEFAULT 'yes',
    send_pai ENUM('yes','no') DEFAULT 'no',
    send_rpid ENUM('yes','no') DEFAULT 'no',
    timers_min_se INT DEFAULT 90,
    timers ENUM('forced','no','required','yes') DEFAULT 'yes',
    timers_sess_expires INT DEFAULT 1800,
    callerid VARCHAR(40) DEFAULT NULL,
    callerid_privacy ENUM('allowed_not_screened','allowed_passed_screened','allowed_failed_screened','allowed','prohib_not_screened','prohib_passed_screened','prohib_failed_screened','prohib','unavailable') DEFAULT 'allowed_not_screened',
    callerid_tag VARCHAR(40) DEFAULT NULL,
    100rel ENUM('no','required','yes') DEFAULT 'yes',
    aggregate_mwi ENUM('yes','no') DEFAULT 'yes',
    trust_id_inbound ENUM('yes','no') DEFAULT 'no',
    trust_id_outbound ENUM('yes','no') DEFAULT 'no',
    use_ptime ENUM('yes','no') DEFAULT 'no',
    use_avpf ENUM('yes','no') DEFAULT 'no',
    media_encryption ENUM('no','sdes','dtls') DEFAULT 'no',
    inband_progress ENUM('yes','no') DEFAULT 'no',
    call_group VARCHAR(40) DEFAULT NULL,
    pickup_group VARCHAR(40) DEFAULT NULL,
    named_call_group VARCHAR(40) DEFAULT NULL,
    named_pickup_group VARCHAR(40) DEFAULT NULL,
    device_state_busy_at INT DEFAULT 0,
    fax_detect ENUM('yes','no') DEFAULT 'no',
    t38_udptl ENUM('yes','no') DEFAULT 'no',
    t38_udptl_ec ENUM('none','fec','redundancy') DEFAULT 'none',
    t38_udptl_maxdatagram INT DEFAULT 0,
    t38_udptl_nat ENUM('yes','no') DEFAULT 'no',
    t38_udptl_ipv6 ENUM('yes','no') DEFAULT 'no',
    tone_zone VARCHAR(40) DEFAULT NULL,
    language VARCHAR(40) DEFAULT NULL,
    one_touch_recording ENUM('yes','no') DEFAULT 'no',
    record_on_feature VARCHAR(40) DEFAULT 'automixmon',
    record_off_feature VARCHAR(40) DEFAULT 'automixmon',
    rtp_engine VARCHAR(40) DEFAULT 'asterisk',
    allow_transfer ENUM('yes','no') DEFAULT 'yes',
    user_eq_phone ENUM('yes','no') DEFAULT 'no',
    moh_passthrough ENUM('yes','no') DEFAULT 'no',
    sdp_owner VARCHAR(40) DEFAULT '-',
    sdp_session VARCHAR(40) DEFAULT 'Asterisk',
    tos_audio VARCHAR(10) DEFAULT '0',
    tos_video VARCHAR(10) DEFAULT '0',
    sub_min_expiry INT DEFAULT 0,
    from_domain VARCHAR(40) DEFAULT NULL,
    from_user VARCHAR(40) DEFAULT NULL,
    mwi_from_user VARCHAR(40) DEFAULT NULL,
    dtls_verify VARCHAR(40) DEFAULT 'no',
    dtls_rekey VARCHAR(40) DEFAULT '0',
    dtls_cert_file VARCHAR(200) DEFAULT NULL,
    dtls_private_key VARCHAR(200) DEFAULT NULL,
    dtls_cipher VARCHAR(200) DEFAULT NULL,
    dtls_ca_file VARCHAR(200) DEFAULT NULL,
    dtls_ca_path VARCHAR(200) DEFAULT NULL,
    dtls_setup ENUM('active','passive','actpass') DEFAULT 'active',
    srtp_tag_32 ENUM('yes','no') DEFAULT 'no',
    media_address VARCHAR(40) DEFAULT NULL,
    redirect_method ENUM('user','uri_core','uri_pjsip') DEFAULT 'user',
    set_var TEXT DEFAULT NULL,
    cos_audio VARCHAR(10) DEFAULT '0',
    cos_video VARCHAR(10) DEFAULT '0',
    message_context VARCHAR(40) DEFAULT NULL,
    force_avp ENUM('yes','no') DEFAULT 'no',
    media_use_received_transport ENUM('yes','no') DEFAULT 'no',
    accountcode VARCHAR(40) DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY id (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- PJSIP Authentication table
CREATE TABLE IF NOT EXISTS ps_auths (
    id VARCHAR(40) NOT NULL,
    auth_type ENUM('md5','userpass') DEFAULT 'userpass',
    nonce_lifetime INT DEFAULT 32,
    md5_cred VARCHAR(40) DEFAULT NULL,
    password VARCHAR(80) DEFAULT NULL,
    realm VARCHAR(40) DEFAULT NULL,
    username VARCHAR(40) DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY id (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- PJSIP Address of Record (AOR) table - Fixed numeric data types
CREATE TABLE IF NOT EXISTS ps_aors (
    id VARCHAR(40) NOT NULL,
    contact VARCHAR(40) DEFAULT NULL,
    default_expiration INT DEFAULT 3600,
    mailboxes VARCHAR(80) DEFAULT NULL,
    max_contacts INT DEFAULT 1,                    -- Fixed: Changed from VARCHAR to INT
    minimum_expiration INT DEFAULT 60,
    remove_existing INT DEFAULT 0,                -- Fixed: Changed from VARCHAR to INT
    qualify_frequency INT DEFAULT 0,              -- Fixed: Changed from VARCHAR to INT
    authenticate_qualify ENUM('yes','no') DEFAULT 'no',
    maximum_expiration INT DEFAULT 7200,
    outbound_proxy VARCHAR(40) DEFAULT NULL,
    support_path ENUM('yes','no') DEFAULT 'no',
    qualify_timeout DECIMAL(4,3) DEFAULT 3.000,
    voicemail_extension VARCHAR(40) DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY id (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- PJSIP Contacts table - Updated for Asterisk 22 compatibility
CREATE TABLE IF NOT EXISTS ps_contacts (
    id VARCHAR(255) NOT NULL,                     -- Fixed: Increased from VARCHAR(40) to VARCHAR(255)
    uri VARCHAR(511) DEFAULT NULL,
    expiration_time VARCHAR(40) DEFAULT NULL,
    qualify_frequency VARCHAR(10) DEFAULT NULL,
    outbound_proxy VARCHAR(40) DEFAULT NULL,
    path TEXT,
    user_agent VARCHAR(255) DEFAULT NULL,
    qualify_timeout VARCHAR(10) DEFAULT NULL,
    qualify_2xx_only ENUM('yes','no') NOT NULL DEFAULT 'no',  -- Fixed: Added missing column for Asterisk 22
    reg_server VARCHAR(255) DEFAULT NULL,
    authenticate_qualify ENUM('yes','no') DEFAULT NULL,
    via_addr VARCHAR(40) DEFAULT NULL,
    via_port VARCHAR(10) DEFAULT NULL,
    call_id VARCHAR(255) DEFAULT NULL,
    endpoint VARCHAR(40) DEFAULT NULL,
    prune_on_boot ENUM('yes','no') DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY id (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- PJSIP Endpoint ID to IP mapping for endpoint discovery
CREATE TABLE IF NOT EXISTS ps_endpoint_id_ips (
    id VARCHAR(40) NOT NULL,
    endpoint VARCHAR(40) NOT NULL,
    `match` VARCHAR(80) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (endpoint) REFERENCES ps_endpoints(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

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

-- Legacy SIP Credentials table (for compatibility)
CREATE TABLE IF NOT EXISTS sip_credentials (
    id INT(11) NOT NULL AUTO_INCREMENT,
    customer_id VARCHAR(20) NOT NULL,
    sip_username VARCHAR(40) NOT NULL UNIQUE,
    sip_password VARCHAR(40) NOT NULL,
    sip_domain VARCHAR(100) NOT NULL DEFAULT '172.31.10.10',
    status ENUM('active', 'inactive', 'suspended') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
    INDEX customer_idx (customer_id),
    INDEX username_idx (sip_username)
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

-- FIXED DID numbers table - Updated to match backend expectations
CREATE TABLE IF NOT EXISTS did_numbers (
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
('asterisk_server_ip', '172.31.10.10', 'string', 'asterisk', 'Asterisk server IP address'),
('ami_port', '5038', 'string', 'asterisk', 'Asterisk AMI port'),
('ami_username', 'admin', 'string', 'asterisk', 'Asterisk AMI username'),
('session_timeout', '30', 'number', 'security', 'Session timeout in minutes'),
('force_password_change', 'false', 'boolean', 'security', 'Force password change on first login'),
('two_factor_auth', 'false', 'boolean', 'security', 'Enable two-factor authentication'),
('login_attempt_limit', 'true', 'boolean', 'security', 'Enable login attempt limiting'),
('max_login_attempts', '5', 'number', 'security', 'Maximum login attempts before lockout');

-- Insert sample data
INSERT IGNORE INTO customers (id, name, email, phone, type, balance, status) VALUES
('C001', 'John Doe', 'john@example.com', '+1-555-0123', 'Prepaid', 125.50, 'Active'),
('C002', 'Jane Smith', 'jane@example.com', '+1-555-0456', 'Postpaid', -45.20, 'Active'),
('C003', 'Bob Johnson', 'bob@example.com', '+1-555-0789', 'Prepaid', 0.00, 'Suspended');

INSERT IGNORE INTO rates (destination_prefix, destination_name, rate_per_minute, billing_increment) VALUES
('1', 'USA/Canada', 0.0120, 60),
('44', 'United Kingdom', 0.0250, 60),
('49', 'Germany', 0.0280, 60),
('33', 'France', 0.0240, 60),
('91', 'India', 0.0180, 60);

-- Create default admin user (password: admin123)
INSERT IGNORE INTO admin_users (username, email, password_hash, salt, full_name, role, status) VALUES
('admin', 'admin@ibilling.com', 'hash_placeholder', 'salt_placeholder', 'System Administrator', 'Super Admin', 'Active');
