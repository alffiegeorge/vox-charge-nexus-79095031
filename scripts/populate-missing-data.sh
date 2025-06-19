
#!/bin/bash

# Populate missing database tables with sample data
source "$(dirname "$0")/utils.sh"

populate_missing_data() {
    local mysql_root_password=$1
    local asterisk_db_password=$2
    
    if [ -z "$mysql_root_password" ] || [ -z "$asterisk_db_password" ]; then
        print_error "Usage: $0 <mysql_root_password> <asterisk_db_password>"
        return 1
    fi
    
    print_status "Populating missing database tables..."
    
    # Test database connection with correct user
    if ! mysql -u asterisk -p"${asterisk_db_password}" -e "USE asterisk; SELECT 1;" >/dev/null 2>&1; then
        print_error "Cannot connect to asterisk database with asterisk user"
        return 1
    fi
    
    print_status "✓ Database connection successful"
    
    # Populate all missing tables
    mysql -u asterisk -p"${asterisk_db_password}" asterisk <<'EOF'
-- Insert additional customers to meet minimum requirement (8)
INSERT IGNORE INTO customers (id, name, email, phone, status, balance, type) VALUES
('C006', 'Mike Davis', 'mike@example.com', '+1-555-0987', 'active', 50.00, 'Prepaid'),
('C007', 'Sarah Wilson', 'sarah@example.com', '+1-555-0654', 'active', 150.75, 'Postpaid'),
('C008', 'Tom Brown', 'tom@example.com', '+1-555-0321', 'active', 80.25, 'Prepaid');

-- Insert additional rates (20 total)
INSERT IGNORE INTO rates (destination_prefix, destination_name, rate_per_minute, billing_increment, effective_date) VALUES
('1', 'USA/Canada', 0.0120, 60, CURDATE()),
('44', 'United Kingdom', 0.0250, 60, CURDATE()),
('49', 'Germany', 0.0280, 60, CURDATE()),
('33', 'France', 0.0240, 60, CURDATE()),
('91', 'India', 0.0180, 60, CURDATE()),
('86', 'China', 0.0150, 60, CURDATE()),
('81', 'Japan', 0.0200, 60, CURDATE()),
('61', 'Australia', 0.0220, 60, CURDATE()),
('39', 'Italy', 0.0260, 60, CURDATE()),
('34', 'Spain', 0.0240, 60, CURDATE()),
('31', 'Netherlands', 0.0270, 60, CURDATE()),
('46', 'Sweden', 0.0290, 60, CURDATE()),
('47', 'Norway', 0.0310, 60, CURDATE()),
('45', 'Denmark', 0.0300, 60, CURDATE()),
('41', 'Switzerland', 0.0350, 60, CURDATE()),
('43', 'Austria', 0.0320, 60, CURDATE()),
('32', 'Belgium', 0.0280, 60, CURDATE()),
('7', 'Russia', 0.0190, 60, CURDATE()),
('55', 'Brazil', 0.0160, 60, CURDATE()),
('52', 'Mexico', 0.0140, 60, CURDATE());

-- Insert DID numbers (minimum 10)
INSERT IGNORE INTO did_numbers (number, customer_id, monthly_cost, status, country, region) VALUES
('+1-555-1001', 'C001', 5.00, 'Assigned', 'USA', 'New York'),
('+1-555-1002', 'C002', 5.00, 'Assigned', 'USA', 'California'),
('+1-555-1003', 'C003', 5.00, 'Assigned', 'USA', 'Texas'),
('+1-555-1004', 'C004', 5.00, 'Assigned', 'USA', 'Florida'),
('+1-555-1005', 'C005', 5.00, 'Assigned', 'USA', 'Illinois'),
('+1-555-1006', NULL, 5.00, 'Available', 'USA', 'Nevada'),
('+1-555-1007', NULL, 5.00, 'Available', 'USA', 'Oregon'),
('+1-555-1008', 'C006', 5.00, 'Assigned', 'USA', 'Washington'),
('+1-555-1009', 'C007', 5.00, 'Assigned', 'USA', 'Colorado'),
('+1-555-1010', 'C008', 5.00, 'Assigned', 'USA', 'Arizona');

-- Create and populate admin_users table
CREATE TABLE IF NOT EXISTS admin_users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) NOT NULL,
    role VARCHAR(20) DEFAULT 'admin',
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT IGNORE INTO admin_users (username, password, email, role, status) VALUES
('admin', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin@ibilling.local', 'admin', 'active'),
('operator', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'operator@ibilling.local', 'operator', 'active'),
('support', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'support@ibilling.local', 'support', 'active');

-- Insert trunks (minimum 4)
INSERT IGNORE INTO trunks (name, type, host, port, username, context, status, provider) VALUES
('Trunk-Primary', 'SIP', 'sip.provider1.com', 5060, 'ibilling_user1', 'from-trunk', 'Active', 'Provider One'),
('Trunk-Secondary', 'SIP', 'sip.provider2.com', 5060, 'ibilling_user2', 'from-trunk', 'Active', 'Provider Two'),
('Trunk-Backup', 'SIP', 'sip.provider3.com', 5060, 'ibilling_user3', 'from-trunk', 'Inactive', 'Provider Three'),
('Trunk-Emergency', 'SIP', 'sip.emergency.com', 5060, 'emergency_user', 'from-trunk', 'Active', 'Emergency Provider');

-- Insert routes (minimum 5)
INSERT IGNORE INTO routes (name, pattern, trunk_id, priority, status) VALUES
('US Local', '_1NXXNXXXXXX', 1, 1, 'Active'),
('International', '_011.', 2, 2, 'Active'),
('Toll Free', '_1800NXXXXXX', 1, 1, 'Active'),
('Emergency', '_911', 4, 0, 'Active'),
('Default', '_X.', 3, 10, 'Active');

-- Insert SIP users (minimum 4)
INSERT IGNORE INTO sipusers (name, username, secret, context, host, type, nat, qualify, disallow, allow, accountcode) VALUES
('1001', '1001', 'secret123', 'from-internal', 'dynamic', 'friend', 'yes', 'yes', 'all', 'ulaw,alaw,g722', 'C001'),
('1002', '1002', 'secret456', 'from-internal', 'dynamic', 'friend', 'yes', 'yes', 'all', 'ulaw,alaw,g722', 'C002'),
('1003', '1003', 'secret789', 'from-internal', 'dynamic', 'friend', 'yes', 'yes', 'all', 'ulaw,alaw,g722', 'C003'),
('1004', '1004', 'secret012', 'from-internal', 'dynamic', 'friend', 'yes', 'yes', 'all', 'ulaw,alaw,g722', 'C004');

-- Create and populate voicemail table
CREATE TABLE IF NOT EXISTS voicemail (
    customer_id VARCHAR(20) NOT NULL,
    context VARCHAR(50) DEFAULT 'default',
    mailbox VARCHAR(50) NOT NULL,
    password VARCHAR(10) NOT NULL,
    fullname VARCHAR(100),
    email VARCHAR(100),
    pager VARCHAR(100),
    options VARCHAR(100),
    PRIMARY KEY (context, mailbox),
    FOREIGN KEY (customer_id) REFERENCES customers(id)
);

INSERT IGNORE INTO voicemail (customer_id, context, mailbox, password, fullname, email) VALUES
('C001', 'default', '1001', '1234', 'John Doe', 'john@example.com'),
('C002', 'default', '1002', '1234', 'Jane Smith', 'jane@example.com'),
('C003', 'default', '1003', '1234', 'Bob Johnson', 'bob@example.com'),
('C004', 'default', '1004', '1234', 'Alice Cooper', 'alice@example.com');

-- Insert sample CDR records (minimum 10)
INSERT IGNORE INTO cdr (calldate, src, dst, duration, billsec, disposition, accountcode) VALUES
(NOW() - INTERVAL 1 HOUR, '1001', '+1-555-9999', 300, 295, 'ANSWERED', 'C001'),
(NOW() - INTERVAL 2 HOUR, '1002', '+44-20-7946-0958', 180, 175, 'ANSWERED', 'C002'),
(NOW() - INTERVAL 3 HOUR, '1003', '+49-30-12345678', 120, 0, 'NO ANSWER', 'C003'),
(NOW() - INTERVAL 4 HOUR, '1004', '+33-1-42-86-83-26', 450, 445, 'ANSWERED', 'C004'),
(NOW() - INTERVAL 5 HOUR, '1001', '+91-11-23456789', 90, 85, 'ANSWERED', 'C001'),
(NOW() - INTERVAL 6 HOUR, '1002', '+86-10-12345678', 240, 235, 'ANSWERED', 'C002'),
(NOW() - INTERVAL 7 HOUR, '1003', '+81-3-12345678', 180, 175, 'ANSWERED', 'C003'),
(NOW() - INTERVAL 8 HOUR, '1004', '+61-2-12345678', 360, 355, 'ANSWERED', 'C004'),
(NOW() - INTERVAL 9 HOUR, '1001', '+39-06-12345678', 150, 145, 'ANSWERED', 'C001'),
(NOW() - INTERVAL 10 HOUR, '1002', '+34-91-12345678', 420, 415, 'ANSWERED', 'C002');

-- Insert invoices (minimum 6)
INSERT IGNORE INTO invoices (invoice_number, customer_id, invoice_date, due_date, subtotal, tax_amount, total_amount, status) VALUES
('INV-2024-001', 'C001', CURDATE() - INTERVAL 30 DAY, CURDATE() - INTERVAL 1 DAY, 125.50, 12.55, 138.05, 'Paid'),
('INV-2024-002', 'C002', CURDATE() - INTERVAL 25 DAY, CURDATE() + INTERVAL 5 DAY, 87.25, 8.73, 95.98, 'Sent'),
('INV-2024-003', 'C003', CURDATE() - INTERVAL 20 DAY, CURDATE() + INTERVAL 10 DAY, 156.75, 15.68, 172.43, 'Sent'),
('INV-2024-004', 'C004', CURDATE() - INTERVAL 15 DAY, CURDATE() + INTERVAL 15 DAY, 203.40, 20.34, 223.74, 'Draft'),
('INV-2024-005', 'C005', CURDATE() - INTERVAL 10 DAY, CURDATE() + INTERVAL 20 DAY, 98.60, 9.86, 108.46, 'Sent'),
('INV-2024-006', 'C006', CURDATE() - INTERVAL 5 DAY, CURDATE() + INTERVAL 25 DAY, 145.80, 14.58, 160.38, 'Draft');

-- Insert invoice items (minimum 12)
INSERT IGNORE INTO invoice_items (invoice_id, description, quantity, unit_price, total_price, item_type) VALUES
(1, 'Voice Calls - Domestic', 150.5, 0.05, 7.53, 'Call'),
(1, 'Voice Calls - International', 45.2, 0.12, 5.42, 'Call'),
(1, 'DID Monthly Fee', 1, 5.00, 5.00, 'DID'),
(2, 'Voice Calls - Domestic', 235.8, 0.05, 11.79, 'Call'),
(2, 'SMS Messages', 120, 0.02, 2.40, 'SMS'),
(3, 'Voice Calls - International', 89.3, 0.15, 13.40, 'Call'),
(3, 'DID Monthly Fee', 2, 5.00, 10.00, 'DID'),
(4, 'Voice Calls - Domestic', 456.7, 0.05, 22.84, 'Call'),
(4, 'Voice Calls - International', 123.4, 0.18, 22.21, 'Call'),
(5, 'SMS Messages', 890, 0.025, 22.25, 'SMS'),
(6, 'Voice Calls - Domestic', 678.9, 0.05, 33.95, 'Call'),
(6, 'DID Monthly Fee', 3, 5.00, 15.00, 'DID');

-- Create and populate payments table
CREATE TABLE IF NOT EXISTS payments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id VARCHAR(20) NOT NULL,
    invoice_id INT,
    amount DECIMAL(10,2) NOT NULL,
    payment_method VARCHAR(50) DEFAULT 'Credit Card',
    payment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'Completed',
    transaction_id VARCHAR(100),
    FOREIGN KEY (customer_id) REFERENCES customers(id),
    FOREIGN KEY (invoice_id) REFERENCES invoices(id)
);

INSERT IGNORE INTO payments (customer_id, invoice_id, amount, payment_method, status, transaction_id) VALUES
('C001', 1, 138.05, 'Credit Card', 'Completed', 'TXN-001-2024'),
('C002', NULL, 50.00, 'Bank Transfer', 'Completed', 'TXN-002-2024'),
('C003', NULL, 75.00, 'Credit Card', 'Completed', 'TXN-003-2024'),
('C004', NULL, 100.00, 'PayPal', 'Completed', 'TXN-004-2024'),
('C005', NULL, 25.00, 'Credit Card', 'Pending', 'TXN-005-2024');

-- Insert SMS messages (minimum 6)
INSERT IGNORE INTO sms_messages (customer_id, from_number, to_number, message, direction, status, cost) VALUES
('C001', '+1-555-1001', '+1-555-9999', 'Hello from iBilling!', 'Outbound', 'Delivered', 0.05),
('C002', '+1-555-1002', '+1-555-8888', 'Your service is active', 'Outbound', 'Delivered', 0.05),
('C003', '+1-555-7777', '+1-555-1003', 'Welcome message', 'Inbound', 'Delivered', 0.00),
('C004', '+1-555-1004', '+1-555-6666', 'Account notification', 'Outbound', 'Sent', 0.05),
('C005', '+1-555-5555', '+1-555-1005', 'Service reminder', 'Inbound', 'Delivered', 0.00),
('C006', '+1-555-1006', '+1-555-4444', 'Thank you message', 'Outbound', 'Delivered', 0.05);

-- Insert SMS templates (minimum 7)
INSERT IGNORE INTO sms_templates (title, message, category) VALUES
('Welcome Message', 'Welcome to iBilling! Your account is now active.', 'welcome'),
('Low Balance Alert', 'Your account balance is low. Please top up to continue using our services.', 'billing'),
('Payment Confirmation', 'Payment received successfully. Thank you!', 'billing'),
('Service Maintenance', 'Scheduled maintenance will occur tonight from 2-4 AM.', 'maintenance'),
('Account Suspended', 'Your account has been suspended due to non-payment.', 'billing'),
('Service Activation', 'Your new service has been activated successfully.', 'service'),
('Invoice Ready', 'Your monthly invoice is ready for review.', 'billing');

-- Create and populate support_tickets table
CREATE TABLE IF NOT EXISTS support_tickets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id VARCHAR(20),
    subject VARCHAR(200) NOT NULL,
    description TEXT,
    status VARCHAR(20) DEFAULT 'Open',
    priority VARCHAR(20) DEFAULT 'Medium',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(id)
);

INSERT IGNORE INTO support_tickets (customer_id, subject, description, status, priority) VALUES
('C001', 'Call Quality Issues', 'Experiencing poor call quality on international calls', 'Open', 'High'),
('C002', 'Billing Question', 'Need clarification on last months charges', 'Resolved', 'Low'),
('C003', 'Service Setup', 'Need help setting up new DID number', 'In Progress', 'Medium'),
('C004', 'Account Access', 'Cannot login to customer portal', 'Open', 'Medium'),
('C005', 'Feature Request', 'Would like to add call recording feature', 'Open', 'Low');

-- Create and populate audit_logs table  
CREATE TABLE IF NOT EXISTS audit_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(50),
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50),
    resource_id VARCHAR(50),
    details TEXT,
    ip_address VARCHAR(45),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT IGNORE INTO audit_logs (user_id, action, resource_type, resource_id, details, ip_address) VALUES
('admin', 'CREATE', 'customer', 'C001', 'Created new customer account', '192.168.1.100'),
('admin', 'UPDATE', 'customer', 'C002', 'Updated customer billing information', '192.168.1.100'),
('admin', 'CREATE', 'trunk', '1', 'Added new SIP trunk', '192.168.1.100'),
('operator', 'VIEW', 'invoice', 'INV-2024-001', 'Viewed customer invoice', '192.168.1.101'),
('admin', 'DELETE', 'did', '+1-555-9999', 'Removed unused DID number', '192.168.1.100');
EOF

    if [ $? -eq 0 ]; then
        print_status "✅ Database tables populated successfully!"
    else
        print_error "Failed to populate some database tables"
        return 1
    fi
    
    # Show updated counts
    print_status "Updated table counts:"
    for table in customers rates did_numbers admin_users trunks routes sipusers voicemail cdr invoices invoice_items payments sms_messages sms_templates support_tickets audit_logs system_settings; do
        count=$(mysql -u asterisk -p"${asterisk_db_password}" asterisk -sN -e "SELECT COUNT(*) FROM $table;" 2>/dev/null)
        print_status "$table: $count records"
    done
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    populate_missing_data "$1" "$2"
fi
