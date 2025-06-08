#!/bin/bash

# Populate sample data for all iBilling database tables
source "$(dirname "$0")/utils.sh"

populate_all_tables() {
    local mysql_root_password=$1
    
    if [ -z "$mysql_root_password" ]; then
        echo "Enter MySQL root password:"
        read -s mysql_root_password
    fi
    
    print_status "Populating all database tables with sample data..."
    
    mysql -u root -p"${mysql_root_password}" asterisk <<'EOF'
-- First ensure all tables exist
CREATE TABLE IF NOT EXISTS invoice_items (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    invoice_id INT(11) NOT NULL,
    description VARCHAR(255) NOT NULL,
    quantity DECIMAL(10,3) NOT NULL DEFAULT 1.000,
    unit_price DECIMAL(10,4) NOT NULL DEFAULT 0.0000,
    total_price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    item_type ENUM('Call', 'SMS', 'DID', 'Service', 'Other') DEFAULT 'Other',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
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
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
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
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
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
    delivered_at TIMESTAMP NULL
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
    resolved_at TIMESTAMP NULL
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
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
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

-- Now safely clear existing sample data only if tables exist
SET @sql = IF((SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='asterisk' AND table_name='invoice_items') > 0,
    'DELETE FROM invoice_items WHERE invoice_id IN (SELECT id FROM invoices WHERE customer_id LIKE "C%")',
    'SELECT "invoice_items table does not exist" as message');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='asterisk' AND table_name='invoices') > 0,
    'DELETE FROM invoices WHERE customer_id LIKE "C%"',
    'SELECT "invoices table does not exist" as message');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='asterisk' AND table_name='payments') > 0,
    'DELETE FROM payments WHERE customer_id LIKE "C%"',
    'SELECT "payments table does not exist" as message');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Insert comprehensive customer data
INSERT INTO customers (id, name, email, phone, company, type, balance, credit_limit, status, address, qr_code_enabled, qr_code_data) VALUES
('C001', 'John Doe', 'john.doe@example.com', '+1-555-0123', 'Doe Enterprises', 'Prepaid', 125.50, NULL, 'Active', '123 Main St, New York, NY 10001', TRUE, 'QR_CODE_DATA_C001'),
('C002', 'Jane Smith', 'jane.smith@example.com', '+1-555-0456', 'Smith Corp', 'Postpaid', -45.20, 500.00, 'Active', '456 Oak Ave, Los Angeles, CA 90210', TRUE, 'QR_CODE_DATA_C002'),
('C003', 'Bob Johnson', 'bob.johnson@example.com', '+1-555-0789', 'Johnson LLC', 'Prepaid', 75.00, NULL, 'Active', '789 Pine St, Chicago, IL 60601', FALSE, NULL),
('C004', 'Alice Cooper', 'alice.cooper@example.com', '+1-555-0321', 'Cooper Industries', 'Prepaid', 200.00, NULL, 'Active', '321 Elm Dr, Miami, FL 33101', TRUE, 'QR_CODE_DATA_C004'),
('C005', 'David Wilson', 'david.wilson@example.com', '+1-555-0654', 'Wilson Solutions', 'Postpaid', 0.00, 1000.00, 'Suspended', '654 Maple Ln, Seattle, WA 98101', FALSE, NULL),
('C006', 'Emma Davis', 'emma.davis@example.com', '+1-555-0987', 'Davis Tech', 'Prepaid', 89.75, NULL, 'Active', '987 Cedar Rd, Boston, MA 02101', TRUE, 'QR_CODE_DATA_C006'),
('C007', 'Michael Brown', 'michael.brown@example.com', '+1-555-0147', 'Brown Holdings', 'Postpaid', 150.30, 750.00, 'Active', '147 Birch St, Denver, CO 80201', FALSE, NULL),
('C008', 'Sarah Miller', 'sarah.miller@example.com', '+1-555-0258', 'Miller Group', 'Prepaid', 45.60, NULL, 'Active', '258 Spruce Ave, Phoenix, AZ 85001', TRUE, 'QR_CODE_DATA_C008')
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Insert comprehensive rates data
INSERT INTO rates (destination_prefix, destination_name, rate_per_minute, min_duration, billing_increment, effective_date, status) VALUES
('1', 'USA/Canada', 0.0120, 6, 60, CURDATE(), 'Active'),
('44', 'United Kingdom', 0.0250, 6, 60, CURDATE(), 'Active'),
('49', 'Germany', 0.0280, 6, 60, CURDATE(), 'Active'),
('33', 'France', 0.0240, 6, 60, CURDATE(), 'Active'),
('91', 'India', 0.0180, 6, 60, CURDATE(), 'Active'),
('86', 'China', 0.0150, 6, 60, CURDATE(), 'Active'),
('81', 'Japan', 0.0200, 6, 60, CURDATE(), 'Active'),
('39', 'Italy', 0.0220, 6, 60, CURDATE(), 'Active'),
('34', 'Spain', 0.0230, 6, 60, CURDATE(), 'Active'),
('31', 'Netherlands', 0.0260, 6, 60, CURDATE(), 'Active'),
('41', 'Switzerland', 0.0300, 6, 60, CURDATE(), 'Active'),
('43', 'Austria', 0.0290, 6, 60, CURDATE(), 'Active'),
('32', 'Belgium', 0.0270, 6, 60, CURDATE(), 'Active'),
('45', 'Denmark', 0.0250, 6, 60, CURDATE(), 'Active'),
('46', 'Sweden', 0.0240, 6, 60, CURDATE(), 'Active'),
('47', 'Norway', 0.0280, 6, 60, CURDATE(), 'Active'),
('358', 'Finland', 0.0260, 6, 60, CURDATE(), 'Active'),
('61', 'Australia', 0.0190, 6, 60, CURDATE(), 'Active'),
('64', 'New Zealand', 0.0210, 6, 60, CURDATE(), 'Active'),
('55', 'Brazil', 0.0350, 6, 60, CURDATE(), 'Active');

-- Insert DID numbers
INSERT INTO did_numbers (number, customer_id, monthly_cost, setup_cost, status, country, region, assigned_date) VALUES
('+1-555-1001', 'C001', 5.00, 10.00, 'Assigned', 'USA', 'New York', CURDATE() - INTERVAL 30 DAY),
('+1-555-1002', 'C002', 5.00, 10.00, 'Assigned', 'USA', 'California', CURDATE() - INTERVAL 25 DAY),
('+1-555-1003', NULL, 5.00, 10.00, 'Available', 'USA', 'Texas', NULL),
('+1-555-1004', 'C003', 5.00, 10.00, 'Assigned', 'USA', 'Florida', CURDATE() - INTERVAL 20 DAY),
('+1-555-1005', NULL, 5.00, 10.00, 'Available', 'USA', 'Illinois', NULL),
('+1-555-1006', 'C004', 5.00, 10.00, 'Assigned', 'USA', 'Washington', CURDATE() - INTERVAL 15 DAY),
('+1-555-1007', NULL, 5.00, 10.00, 'Available', 'USA', 'Colorado', NULL),
('+1-555-1008', 'C006', 5.00, 10.00, 'Assigned', 'USA', 'Massachusetts', CURDATE() - INTERVAL 10 DAY),
('+44-20-7946-0001', NULL, 8.00, 15.00, 'Available', 'UK', 'London', NULL),
('+44-20-7946-0002', 'C007', 8.00, 15.00, 'Assigned', 'UK', 'London', CURDATE() - INTERVAL 5 DAY);

-- Insert admin users
INSERT INTO admin_users (username, email, password_hash, salt, full_name, role, status, two_factor_enabled) VALUES
('admin', 'admin@ibilling.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'salt123', 'System Administrator', 'Super Admin', 'Active', FALSE),
('operator1', 'operator1@ibilling.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'salt124', 'John Operator', 'Operator', 'Active', FALSE),
('support1', 'support1@ibilling.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'salt125', 'Jane Support', 'Support', 'Active', TRUE);

-- Insert trunks
INSERT INTO trunks (name, type, host, port, username, context, status, cost_per_minute, provider, max_channels) VALUES
('Demo-Primary', 'SIP', 'sip.provider1.com', 5060, 'demo_user1', 'from-trunk', 'Active', 0.0080, 'Demo Provider One', 30),
('Demo-Secondary', 'SIP', 'sip.provider2.com', 5060, 'demo_user2', 'from-trunk', 'Active', 0.0085, 'Demo Provider Two', 20),
('Demo-Backup', 'SIP', 'sip.provider3.com', 5060, 'demo_user3', 'from-trunk', 'Inactive', 0.0090, 'Demo Provider Three', 10),
('Sample-International', 'SIP', 'sip.intl-provider.com', 5060, 'sample_intl', 'from-trunk', 'Active', 0.0120, 'International Provider', 50);

-- Insert routes
INSERT INTO routes (name, pattern, trunk_id, priority, status) VALUES
('US-Canada Route', '_1NXXNXXXXXX', 1, 1, 'Active'),
('UK Route', '_44XXXXXXXXXX', 2, 1, 'Active'),
('Emergency Route', '_911', 1, 0, 'Active'),
('International Route', '_00.', 4, 2, 'Active'),
('Local Route', '_NXXNXXXXXX', 1, 1, 'Active');

-- Insert SIP users
INSERT INTO sipusers (name, username, secret, context, host, type, nat, qualify, allow, accountcode) VALUES
('demo1001', 'demo1001', 'demopass123', 'internal', 'dynamic', 'friend', 'yes', 'yes', 'ulaw,alaw,gsm', 'C001'),
('demo1002', 'demo1002', 'demopass124', 'internal', 'dynamic', 'friend', 'yes', 'yes', 'ulaw,alaw,gsm', 'C002'),
('demo1003', 'demo1003', 'demopass125', 'internal', 'dynamic', 'friend', 'yes', 'yes', 'ulaw,alaw,gsm', 'C003'),
('demo1004', 'demo1004', 'demopass126', 'internal', 'dynamic', 'friend', 'yes', 'yes', 'ulaw,alaw,gsm', 'C004');

-- Insert voicemail
INSERT INTO voicemail (customer_id, context, mailbox, password, fullname, email, tz, attach) VALUES
('C001', 'default', '1001', '1234', 'John Doe', 'john.doe@example.com', 'eastern', 'yes'),
('C002', 'default', '1002', '1234', 'Jane Smith', 'jane.smith@example.com', 'pacific', 'yes'),
('C003', 'default', '1003', '1234', 'Bob Johnson', 'bob.johnson@example.com', 'central', 'no'),
('C004', 'default', '1004', '1234', 'Alice Cooper', 'alice.cooper@example.com', 'eastern', 'yes');

-- Insert CDR records
INSERT INTO cdr (calldate, src, dst, duration, billsec, disposition, accountcode) VALUES
(NOW() - INTERVAL 1 HOUR, '+1-555-0123', '+1-555-9999', 300, 295, 'ANSWERED', 'C001'),
(NOW() - INTERVAL 2 HOUR, '+1-555-0456', '+44-20-7946-0958', 180, 175, 'ANSWERED', 'C002'),
(NOW() - INTERVAL 3 HOUR, '+1-555-0789', '+49-30-12345678', 120, 0, 'NO ANSWER', 'C003'),
(NOW() - INTERVAL 4 HOUR, '+1-555-0321', '+33-1-42-86-83-26', 450, 445, 'ANSWERED', 'C004'),
(NOW() - INTERVAL 5 HOUR, '+1-555-0654', '+91-11-23456789', 90, 85, 'ANSWERED', 'C005'),
(NOW() - INTERVAL 6 HOUR, '+1-555-0987', '+1-555-8888', 240, 235, 'ANSWERED', 'C006'),
(NOW() - INTERVAL 7 HOUR, '+1-555-0147', '+44-20-7946-0999', 360, 355, 'ANSWERED', 'C007'),
(NOW() - INTERVAL 8 HOUR, '+1-555-0258', '+49-30-87654321', 150, 145, 'ANSWERED', 'C008'),
(NOW() - INTERVAL 1 DAY, '+1-555-0123', '+33-1-98765432', 420, 415, 'ANSWERED', 'C001'),
(NOW() - INTERVAL 2 DAY, '+1-555-0456', '+91-22-12345678', 180, 175, 'ANSWERED', 'C002');

-- Insert invoices
INSERT INTO invoices (invoice_number, customer_id, invoice_date, due_date, subtotal, tax_amount, total_amount, status) VALUES
('INV-2024-001', 'C001', CURDATE() - INTERVAL 30 DAY, CURDATE() - INTERVAL 15 DAY, 85.50, 8.55, 94.05, 'Paid'),
('INV-2024-002', 'C002', CURDATE() - INTERVAL 25 DAY, CURDATE() - INTERVAL 10 DAY, 125.75, 12.58, 138.33, 'Paid'),
('INV-2024-003', 'C003', CURDATE() - INTERVAL 20 DAY, CURDATE() - INTERVAL 5 DAY, 45.20, 4.52, 49.72, 'Overdue'),
('INV-2024-004', 'C004', CURDATE() - INTERVAL 15 DAY, CURDATE() + INTERVAL 15 DAY, 78.90, 7.89, 86.79, 'Sent'),
('INV-2024-005', 'C006', CURDATE() - INTERVAL 10 DAY, CURDATE() + INTERVAL 20 DAY, 56.40, 5.64, 62.04, 'Draft'),
('INV-2024-006', 'C007', CURDATE() - INTERVAL 5 DAY, CURDATE() + INTERVAL 25 DAY, 132.60, 13.26, 145.86, 'Sent');

-- Insert invoice items
INSERT INTO invoice_items (invoice_id, description, quantity, unit_price, total_price, item_type) VALUES
(1, 'Outbound calls to USA/Canada', 45.250, 0.0120, 54.30, 'Call'),
(1, 'DID Monthly Fee - +1-555-1001', 1.000, 5.0000, 5.00, 'DID'),
(1, 'International calls to UK', 18.500, 0.0250, 26.20, 'Call'),
(2, 'Outbound calls to USA/Canada', 78.400, 0.0120, 94.08, 'Call'),
(2, 'DID Monthly Fee - +1-555-1002', 1.000, 5.0000, 5.00, 'DID'),
(2, 'SMS Messages', 135.000, 0.0500, 26.67, 'SMS'),
(3, 'Outbound calls to Germany', 32.150, 0.0280, 40.20, 'Call'),
(3, 'DID Monthly Fee - +1-555-1004', 1.000, 5.0000, 5.00, 'DID'),
(4, 'Outbound calls to various destinations', 65.800, 0.0150, 73.90, 'Call'),
(4, 'DID Monthly Fee - +1-555-1006', 1.000, 5.0000, 5.00, 'DID'),
(5, 'Outbound calls to USA/Canada', 42.800, 0.0120, 51.40, 'Call'),
(5, 'DID Monthly Fee - +1-555-1008', 1.000, 5.0000, 5.00, 'DID'),
(6, 'Outbound calls to UK', 58.900, 0.0250, 127.60, 'Call'),
(6, 'DID Monthly Fee - +44-20-7946-0002', 1.000, 5.0000, 5.00, 'DID');

-- Insert payments
INSERT INTO payments (customer_id, invoice_id, payment_method, amount, reference_number, status, payment_date) VALUES
('C001', 1, 'Credit Card', 94.05, 'CC-2024-001', 'Completed', NOW() - INTERVAL 25 DAY),
('C002', 2, 'Bank Transfer', 138.33, 'BT-2024-002', 'Completed', NOW() - INTERVAL 20 DAY),
('C004', NULL, 'Credit Card', 100.00, 'CC-2024-003', 'Completed', NOW() - INTERVAL 10 DAY),
('C006', NULL, 'Mobile Money', 50.00, 'MM-2024-004', 'Completed', NOW() - INTERVAL 5 DAY),
('C007', NULL, 'Bank Transfer', 200.00, 'BT-2024-005', 'Pending', NOW() - INTERVAL 2 DAY);

-- Insert SMS messages
INSERT INTO sms_messages (customer_id, from_number, to_number, message, direction, status, cost, sent_at) VALUES
('C001', '+1-555-1001', '+1-555-7777', 'Hello, this is a test message from iBilling!', 'Outbound', 'Delivered', 0.0500, NOW() - INTERVAL 2 HOUR),
('C002', '+1-555-1002', '+1-555-8888', 'Your account balance is low. Please top up.', 'Outbound', 'Delivered', 0.0500, NOW() - INTERVAL 4 HOUR),
(NULL, '+1-555-9999', '+1-555-1001', 'Thank you for your service!', 'Inbound', 'Delivered', 0.0000, NOW() - INTERVAL 6 HOUR),
('C004', '+1-555-1006', '+1-555-6666', 'Meeting scheduled for tomorrow at 2 PM', 'Outbound', 'Delivered', 0.0500, NOW() - INTERVAL 8 HOUR),
('C006', '+1-555-1008', '+1-555-5555', 'Payment confirmation received', 'Outbound', 'Sent', 0.0500, NOW() - INTERVAL 1 DAY),
(NULL, '+1-555-4444', '+1-555-1002', 'Welcome to our service!', 'Inbound', 'Delivered', 0.0000, NOW() - INTERVAL 2 DAY);

-- Insert SMS templates
INSERT INTO sms_templates (title, message, category) VALUES
('Welcome Message', 'Welcome to iBilling! Your account is now active and ready to use.', 'welcome'),
('Low Balance Alert', 'Your account balance is low (${{balance}}). Please top up to continue using our services.', 'billing'),
('Payment Confirmation', 'Payment of ${{amount}} received successfully. Thank you! Ref: {{reference}}', 'billing'),
('Service Maintenance', 'Scheduled maintenance will occur tonight from 2-4 AM. Service may be briefly interrupted.', 'maintenance'),
('Invoice Generated', 'New invoice #{{invoice_number}} for ${{amount}} has been generated. Due date: {{due_date}}', 'billing'),
('Account Suspended', 'Your account has been suspended due to overdue payments. Please contact support.', 'billing'),
('Service Activated', 'Your new service {{service_name}} has been activated successfully.', 'activation');

-- Insert support tickets
INSERT INTO support_tickets (ticket_number, customer_id, subject, description, priority, status, created_at) VALUES
('TKT-2024-001', 'C001', 'Call Quality Issues', 'Experiencing poor call quality on international calls to UK numbers.', 'Medium', 'In Progress', NOW() - INTERVAL 2 DAY),
('TKT-2024-002', 'C003', 'Billing Inquiry', 'Question about charges on last months invoice for international calls.', 'Low', 'Open', NOW() - INTERVAL 1 DAY),
('TKT-2024-003', 'C002', 'Account Access', 'Cannot login to customer portal, password reset not working.', 'High', 'Resolved', NOW() - INTERVAL 5 DAY),
('TKT-2024-004', 'C004', 'DID Configuration', 'Need help configuring new DID number for call forwarding.', 'Medium', 'Open', NOW() - INTERVAL 3 HOUR),
('TKT-2024-005', NULL, 'General Inquiry', 'Interested in bulk pricing for enterprise solution.', 'Low', 'Open', NOW() - INTERVAL 1 HOUR);

-- Insert audit logs
INSERT INTO audit_logs (user_id, user_type, action, table_name, record_id, ip_address, user_agent) VALUES
(1, 'admin', 'LOGIN', NULL, NULL, '192.168.1.100', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'),
(1, 'admin', 'CREATE', 'customers', 'C008', '192.168.1.100', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'),
(2, 'admin', 'UPDATE', 'rates', '1', '192.168.1.101', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'),
(1, 'admin', 'DELETE', 'support_tickets', 'TKT-2024-999', '192.168.1.100', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'),
(3, 'admin', 'VIEW', 'customers', NULL, '192.168.1.102', 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36');

-- Update system settings with more comprehensive data
UPDATE system_settings SET setting_value = 'iBilling Professional Communications' WHERE setting_key = 'company_name';
UPDATE system_settings SET setting_value = 'admin@ibilling-demo.com' WHERE setting_key = 'system_email';

INSERT IGNORE INTO system_settings (setting_key, setting_value, setting_type, category, description) VALUES
('sms_rate', '0.05', 'number', 'billing', 'Rate per SMS message'),
('international_rate_markup', '1.2', 'number', 'billing', 'Markup multiplier for international rates'),
('call_recording_enabled', 'true', 'boolean', 'features', 'Enable call recording feature'),
('auto_invoice_generation', 'true', 'boolean', 'billing', 'Automatically generate monthly invoices'),
('payment_reminder_days', '7', 'number', 'billing', 'Days before due date to send payment reminders'),
('max_concurrent_calls', '100', 'number', 'asterisk', 'Maximum concurrent calls allowed'),
('backup_retention_days', '30', 'number', 'system', 'Number of days to retain backup files'),
('log_retention_days', '90', 'number', 'system', 'Number of days to retain log files');

EOF

    print_status "✅ All database tables populated with comprehensive sample data!"
    
    # Show summary of populated data
    print_status "Database population summary:"
    mysql -u root -p"${mysql_root_password}" asterisk -e "
        SELECT 'Customers' as Table_Name, COUNT(*) as Record_Count FROM customers
        UNION ALL
        SELECT 'Rates', COALESCE((SELECT COUNT(*) FROM rates), 0) FROM dual
        UNION ALL
        SELECT 'DID Numbers', COALESCE((SELECT COUNT(*) FROM did_numbers), 0) FROM dual
        UNION ALL
        SELECT 'Admin Users', COALESCE((SELECT COUNT(*) FROM admin_users), 0) FROM dual
        UNION ALL
        SELECT 'Trunks', COALESCE((SELECT COUNT(*) FROM trunks), 0) FROM dual
        UNION ALL
        SELECT 'Routes', COALESCE((SELECT COUNT(*) FROM routes), 0) FROM dual
        UNION ALL
        SELECT 'SIP Users', COALESCE((SELECT COUNT(*) FROM sipusers), 0) FROM dual
        UNION ALL
        SELECT 'Voicemail', COALESCE((SELECT COUNT(*) FROM voicemail), 0) FROM dual
        UNION ALL
        SELECT 'CDR Records', COUNT(*) FROM cdr
        UNION ALL
        SELECT 'Invoices', COALESCE((SELECT COUNT(*) FROM invoices), 0) FROM dual
        UNION ALL
        SELECT 'Invoice Items', COALESCE((SELECT COUNT(*) FROM invoice_items), 0) FROM dual
        UNION ALL
        SELECT 'Payments', COALESCE((SELECT COUNT(*) FROM payments), 0) FROM dual
        UNION ALL
        SELECT 'SMS Messages', COALESCE((SELECT COUNT(*) FROM sms_messages), 0) FROM dual
        UNION ALL
        SELECT 'SMS Templates', COALESCE((SELECT COUNT(*) FROM sms_templates), 0) FROM dual
        UNION ALL
        SELECT 'Support Tickets', COALESCE((SELECT COUNT(*) FROM support_tickets), 0) FROM dual
        UNION ALL
        SELECT 'Audit Logs', COALESCE((SELECT COUNT(*) FROM audit_logs), 0) FROM dual
        UNION ALL
        SELECT 'System Settings', COALESCE((SELECT COUNT(*) FROM system_settings), 0) FROM dual;
    "
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    populate_all_tables "$1"
fi
