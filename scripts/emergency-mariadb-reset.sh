
#!/bin/bash

# Emergency MariaDB reset script - Enhanced for severe corruption
source "$(dirname "$0")/utils.sh"

emergency_mariadb_reset() {
    local mysql_root_password=${1:-"admin123"}
    local asterisk_db_password=${2:-"asterisk123"}
    
    print_status "=== EMERGENCY MARIADB RESET (SEVERE CORRUPTION) ==="
    
    # Step 1: Kill all MySQL/MariaDB processes completely
    print_status "Killing all MySQL/MariaDB processes..."
    sudo pkill -9 -f mysqld || true
    sudo pkill -9 -f mariadbd || true
    sudo pkill -9 -f mysqld_safe || true
    sudo killall -9 mysqld 2>/dev/null || true
    sudo killall -9 mariadbd 2>/dev/null || true
    sleep 5
    
    # Step 2: Stop all services
    print_status "Stopping all MySQL/MariaDB services..."
    sudo systemctl stop mariadb || true
    sudo systemctl stop mysql || true
    sudo systemctl disable mariadb || true
    sudo systemctl disable mysql || true
    sleep 3
    
    # Step 3: Remove all socket and pid files
    print_status "Removing all socket and pid files..."
    sudo rm -f /var/run/mysqld/mysqld.sock || true
    sudo rm -f /tmp/mysql.sock || true
    sudo rm -f /var/lib/mysql/mysql.sock || true
    sudo rm -f /var/run/mysqld/mysqld.pid || true
    sudo rm -f /var/lib/mysql/*.pid || true
    
    # Step 4: Backup and remove corrupted data (NUCLEAR OPTION)
    print_status "Backing up and removing corrupted MySQL data directory..."
    if [ -d "/var/lib/mysql" ]; then
        sudo mv /var/lib/mysql "/var/lib/mysql.corrupted.$(date +%Y%m%d_%H%M%S)" || true
    fi
    
    # Step 5: Completely purge and reinstall MariaDB
    print_status "Completely purging and reinstalling MariaDB..."
    sudo apt remove --purge -y mariadb-server mariadb-client mariadb-common mysql-common || true
    sudo apt autoremove -y || true
    sudo apt autoclean || true
    
    # Remove any remaining config files
    sudo rm -rf /etc/mysql || true
    sudo rm -rf /var/lib/mysql || true
    sudo rm -rf /var/log/mysql || true
    
    # Update package list and install fresh MariaDB
    sudo apt update
    sudo apt install -y mariadb-server mariadb-client
    
    # Step 6: Initialize MariaDB with proper permissions
    print_status "Initializing fresh MariaDB installation..."
    sudo mkdir -p /var/run/mysqld
    sudo chown mysql:mysql /var/run/mysqld
    sudo chmod 755 /var/run/mysqld
    
    # Step 7: Start MariaDB normally
    print_status "Starting fresh MariaDB installation..."
    sudo systemctl enable mariadb
    sudo systemctl start mariadb
    sleep 10
    
    # Step 8: Test if MariaDB is accessible (fresh install usually has no root password)
    print_status "Testing fresh MariaDB access..."
    if mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
        print_status "✓ Fresh MariaDB accessible without password"
        use_password=""
    else
        print_status "Fresh MariaDB requires authentication setup"
        use_password="-p${mysql_root_password}"
    fi
    
    # Step 9: Set up authentication and create database
    print_status "Setting up authentication and creating asterisk database..."
    mysql -u root <<EOF
-- Set root password
ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysql_root_password}';
FLUSH PRIVILEGES;

-- Create asterisk database and user
CREATE DATABASE asterisk CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'asterisk'@'localhost' IDENTIFIED BY '${asterisk_db_password}';
GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk'@'localhost';
FLUSH PRIVILEGES;
EOF
    
    if [ $? -eq 0 ]; then
        print_status "✓ Database setup successful"
    else
        print_error "✗ Database setup failed"
        return 1
    fi
    
    # Step 10: Test connections
    print_status "Testing database connections..."
    if mysql -u root -p"${mysql_root_password}" -e "SELECT 1;" >/dev/null 2>&1; then
        print_status "✓ Root connection successful"
    else
        print_error "✗ Root connection failed"
        return 1
    fi
    
    if mysql -u asterisk -p"${asterisk_db_password}" asterisk -e "SELECT 1;" >/dev/null 2>&1; then
        print_status "✓ Asterisk user connection successful"
    else
        print_error "✗ Asterisk user connection failed"
        return 1
    fi
    
    # Step 11: Create essential database schema
    print_status "Creating essential database schema..."
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
    
    # Step 12: Secure the installation
    print_status "Securing MariaDB installation..."
    mysql -u root -p"${mysql_root_password}" <<EOF
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
    
    print_status "=== EMERGENCY RESET COMPLETED SUCCESSFULLY ==="
    echo "MySQL Root Password: ${mysql_root_password}"
    echo "Asterisk DB Password: ${asterisk_db_password}"
    echo ""
    print_status "MariaDB has been completely reinstalled and configured"
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
