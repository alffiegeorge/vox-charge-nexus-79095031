
#!/bin/bash

# Emergency MariaDB reset script
source "$(dirname "$0")/utils.sh"

emergency_mariadb_reset() {
    local mysql_root_password=${1:-"admin123"}
    local asterisk_db_password=${2:-"asterisk123"}
    
    print_status "=== EMERGENCY MARIADB RESET ==="
    
    # Step 1: Kill all MySQL/MariaDB processes
    print_status "Killing all MySQL/MariaDB processes..."
    sudo pkill -f mysqld || true
    sudo pkill -f mariadbd || true
    sudo pkill -f mysqld_safe || true
    sleep 5
    
    # Step 2: Stop the service completely
    print_status "Stopping MariaDB service..."
    sudo systemctl stop mariadb || true
    sudo systemctl stop mysql || true
    sleep 3
    
    # Step 3: Remove socket files
    print_status "Removing socket files..."
    sudo rm -f /var/run/mysqld/mysqld.sock || true
    sudo rm -f /tmp/mysql.sock || true
    sudo rm -f /var/lib/mysql/mysql.sock || true
    
    # Step 4: Ensure proper permissions
    print_status "Setting proper permissions..."
    sudo mkdir -p /var/run/mysqld
    sudo chown mysql:mysql /var/run/mysqld
    sudo chmod 755 /var/run/mysqld
    sudo chown -R mysql:mysql /var/lib/mysql
    
    # Step 5: Start MariaDB in recovery mode
    print_status "Starting MariaDB in recovery mode..."
    sudo mysqld_safe --skip-grant-tables --skip-networking --user=mysql &
    sleep 10
    
    # Step 6: Reset authentication completely
    print_status "Resetting authentication system..."
    mysql -u root <<EOF
FLUSH PRIVILEGES;
USE mysql;
UPDATE user SET plugin='mysql_native_password' WHERE User='root';
UPDATE user SET authentication_string=PASSWORD('${mysql_root_password}') WHERE User='root' AND Host='localhost';
UPDATE user SET Password=PASSWORD('${mysql_root_password}') WHERE User='root' AND Host='localhost';
DELETE FROM user WHERE User='';
DELETE FROM user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM db WHERE Db='test' OR Db='test\\_%';
DROP DATABASE IF EXISTS asterisk;
DROP USER IF EXISTS 'asterisk'@'localhost';
DROP USER IF EXISTS 'asterisk'@'%';
DELETE FROM user WHERE User='asterisk';
DELETE FROM db WHERE User='asterisk';
FLUSH PRIVILEGES;
EOF
    
    if [ $? -eq 0 ]; then
        print_status "✓ Authentication reset successful"
    else
        print_error "✗ Authentication reset failed"
        return 1
    fi
    
    # Step 7: Stop recovery mode
    print_status "Stopping recovery mode..."
    sudo pkill -f mysqld_safe || true
    sudo pkill -f mysqld || true
    sleep 5
    
    # Step 8: Start MariaDB normally
    print_status "Starting MariaDB normally..."
    sudo systemctl start mariadb
    sleep 5
    
    # Step 9: Test root access
    print_status "Testing root access..."
    if mysql -u root -p"${mysql_root_password}" -e "SELECT 1;" >/dev/null 2>&1; then
        print_status "✓ Root access working"
    else
        print_error "✗ Root access still failing"
        return 1
    fi
    
    # Step 10: Create asterisk database and user
    print_status "Creating asterisk database and user..."
    mysql -u root -p"${mysql_root_password}" <<EOF
CREATE DATABASE asterisk CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'asterisk'@'localhost' IDENTIFIED BY '${asterisk_db_password}';
GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk'@'localhost';
FLUSH PRIVILEGES;
EOF
    
    # Step 11: Test asterisk user
    print_status "Testing asterisk user access..."
    if mysql -u asterisk -p"${asterisk_db_password}" -e "USE asterisk; SELECT 1;" >/dev/null 2>&1; then
        print_status "✓ Asterisk user access working"
    else
        print_error "✗ Asterisk user access failed"
        return 1
    fi
    
    # Step 12: Create basic tables
    print_status "Creating basic database schema..."
    mysql -u root -p"${mysql_root_password}" asterisk <<EOF
-- Users table for authentication
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

-- Insert default admin user (password: admin123)
INSERT IGNORE INTO users (username, password, email, role, status) VALUES 
('admin', '\$2b\$10\$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin@ibilling.local', 'admin', 'active');

-- Basic customers table
CREATE TABLE IF NOT EXISTS customers (
    id VARCHAR(20) NOT NULL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    balance DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    status ENUM('Active', 'Suspended', 'Closed') NOT NULL DEFAULT 'Active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sample customer data
INSERT IGNORE INTO customers (id, name, email, balance, status) VALUES 
('CUST001', 'John Doe', 'john.doe@example.com', 100.00, 'Active'),
('CUST002', 'Jane Smith', 'jane.smith@example.com', 250.75, 'Active'),
('CUST003', 'Bob Johnson', 'bob.johnson@example.com', 0.00, 'Suspended');

-- Basic CDR table
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
    PRIMARY KEY (id),
    INDEX calldate_idx (calldate),
    INDEX accountcode_idx (accountcode)
);
EOF
    
    print_status "✓ Database schema created successfully"
    
    # Step 13: Enable and start MariaDB service
    print_status "Enabling MariaDB service..."
    sudo systemctl enable mariadb
    
    print_status "=== EMERGENCY RESET COMPLETED SUCCESSFULLY ==="
    echo "MySQL Root Password: ${mysql_root_password}"
    echo "Asterisk DB Password: ${asterisk_db_password}"
    echo ""
    print_status "You can now continue with the bootstrap installation"
    
    return 0
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -eq 0 ]; then
        emergency_mariadb_reset "admin123" "asterisk123"
    elif [ $# -eq 1 ]; then
        emergency_mariadb_reset "admin123" "$1"
    elif [ $# -eq 2 ]; then
        emergency_mariadb_reset "$1" "$2"
    else
        echo "Usage: $0 [mysql_root_password] [asterisk_db_password]"
        echo "   or: $0 [asterisk_db_password]"
        echo "   or: $0 (use defaults)"
        exit 1
    fi
fi
