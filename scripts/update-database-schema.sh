
#!/bin/bash

# Update database schema with additional tables
source "$(dirname "$0")/utils.sh"

update_schema() {
    local mysql_root_password=$1
    
    if [ -z "$mysql_root_password" ]; then
        echo "Enter MySQL root password:"
        read -s mysql_root_password
    fi
    
    print_status "Updating database schema with additional tables..."
    
    mysql -u root -p"${mysql_root_password}" asterisk <<'EOF'
-- SMS History table (for backward compatibility)
CREATE TABLE IF NOT EXISTS sms_history (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    phone_number VARCHAR(20) NOT NULL,
    message TEXT NOT NULL,
    status ENUM('Pending', 'Sent', 'Delivered', 'Failed', 'Scheduled') DEFAULT 'Pending',
    cost DECIMAL(8,4) DEFAULT 0.0000,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    scheduled_at TIMESTAMP NULL,
    INDEX phone_idx (phone_number),
    INDEX status_idx (status),
    INDEX created_at_idx (created_at)
);

-- Call recordings table
CREATE TABLE IF NOT EXISTS call_recordings (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    call_id VARCHAR(50) NOT NULL,
    customer_id VARCHAR(20) DEFAULT NULL,
    src VARCHAR(20) NOT NULL,
    dst VARCHAR(20) NOT NULL,
    filename VARCHAR(255) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    file_size BIGINT DEFAULT 0,
    duration INT DEFAULT 0,
    recording_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status ENUM('Recording', 'Completed', 'Failed', 'Archived') DEFAULT 'Recording',
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL,
    INDEX call_idx (call_id),
    INDEX customer_idx (customer_id),
    INDEX status_idx (status)
);

-- Rate groups table for bulk rate management
CREATE TABLE IF NOT EXISTS rate_groups (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT DEFAULT NULL,
    markup_percentage DECIMAL(5,2) DEFAULT 0.00,
    status ENUM('Active', 'Inactive') DEFAULT 'Active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX name_idx (name)
);

-- Customer groups for bulk management
CREATE TABLE IF NOT EXISTS customer_groups (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT DEFAULT NULL,
    rate_group_id INT(11) DEFAULT NULL,
    billing_cycle ENUM('Monthly', 'Weekly', 'Daily') DEFAULT 'Monthly',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (rate_group_id) REFERENCES rate_groups(id) ON DELETE SET NULL,
    INDEX name_idx (name)
);

-- Customer group assignments
CREATE TABLE IF NOT EXISTS customer_group_assignments (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    customer_id VARCHAR(20) NOT NULL,
    group_id INT(11) NOT NULL,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
    FOREIGN KEY (group_id) REFERENCES customer_groups(id) ON DELETE CASCADE,
    UNIQUE KEY unique_assignment (customer_id, group_id)
);

-- Populate SMS history with sample data
INSERT IGNORE INTO sms_history (phone_number, message, status, cost, created_at) VALUES
('+1-555-0123', 'Welcome to iBilling! Your account is active.', 'Delivered', 0.0500, NOW() - INTERVAL 1 DAY),
('+1-555-0456', 'Your payment has been processed successfully.', 'Delivered', 0.0500, NOW() - INTERVAL 2 DAY),
('+1-555-0789', 'Low balance alert: Please top up your account.', 'Sent', 0.0500, NOW() - INTERVAL 3 DAY),
('+1-555-0321', 'Service maintenance scheduled for tonight.', 'Delivered', 0.0500, NOW() - INTERVAL 4 DAY),
('+1-555-0654', 'Invoice #INV-2024-001 is now available.', 'Failed', 0.0500, NOW() - INTERVAL 5 DAY);

-- Populate rate groups
INSERT IGNORE INTO rate_groups (name, description, markup_percentage, status) VALUES
('Standard Rates', 'Standard rate group for regular customers', 0.00, 'Active'),
('Premium Rates', 'Premium rate group with higher quality routes', 15.00, 'Active'),
('Wholesale Rates', 'Discounted rates for wholesale customers', -10.00, 'Active'),
('Emergency Rates', 'Special rates for emergency services', 0.00, 'Active');

-- Populate customer groups
INSERT IGNORE INTO customer_groups (name, description, rate_group_id, billing_cycle) VALUES
('Retail Customers', 'Individual retail customers', 1, 'Monthly'),
('Small Business', 'Small business customers', 1, 'Monthly'),
('Enterprise', 'Large enterprise customers', 3, 'Monthly'),
('Premium Service', 'Premium service customers', 2, 'Monthly');

-- Assign customers to groups
INSERT IGNORE INTO customer_group_assignments (customer_id, group_id) VALUES
('C001', 1), ('C002', 2), ('C003', 1), ('C004', 2),
('C005', 3), ('C006', 1), ('C007', 4), ('C008', 1);

EOF

    print_status "✅ Database schema updated successfully!"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    update_schema "$1"
fi
