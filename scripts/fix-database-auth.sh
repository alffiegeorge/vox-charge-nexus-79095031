
#!/bin/bash

# Fix database authentication issues
source "$(dirname "$0")/utils.sh"

fix_database_authentication() {
    local mysql_root_password=${1:-"admin123"}
    local asterisk_db_password=${2:-"asterisk123"}
    
    print_status "Fixing MariaDB authentication issues..."
    
    # Stop MariaDB first
    sudo systemctl stop mariadb
    sleep 3
    
    # Start MariaDB in safe mode to reset authentication
    print_status "Starting MariaDB in safe mode..."
    sudo mysqld_safe --skip-grant-tables --skip-networking &
    sleep 5
    
    # Connect and fix authentication
    print_status "Resetting root password and creating asterisk user..."
    mysql -u root <<EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysql_root_password}';
DROP DATABASE IF EXISTS asterisk;
CREATE DATABASE asterisk CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
DROP USER IF EXISTS 'asterisk'@'localhost';
CREATE USER 'asterisk'@'localhost' IDENTIFIED BY '${asterisk_db_password}';
GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk'@'localhost';
FLUSH PRIVILEGES;
EOF
    
    # Stop safe mode
    print_status "Stopping safe mode and restarting MariaDB normally..."
    sudo pkill mysqld_safe 2>/dev/null || true
    sudo pkill mysqld 2>/dev/null || true
    sleep 3
    
    # Start MariaDB normally
    sudo systemctl start mariadb
    sleep 5
    
    # Test the connection
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
    
    # Update backend environment file
    print_status "Updating backend environment file..."
    if [ -f "/opt/billing/web/backend/.env" ]; then
        sudo sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=${asterisk_db_password}/" /opt/billing/web/backend/.env
    fi
    
    # Create basic database schema
    print_status "Creating basic database tables..."
    mysql -u root -p"${mysql_root_password}" asterisk <<EOF
-- Basic CDR table for call records
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
    PRIMARY KEY (id)
);

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
EOF
    
    # Restart backend service
    print_status "Restarting backend service..."
    sudo systemctl restart ibilling-backend
    sleep 3
    
    # Test the health endpoint
    if curl -s http://localhost:3001/health | grep -q '"database":"Connected"'; then
        print_status "✓ Backend database connection successful"
    else
        print_warning "⚠ Backend may still have database connection issues"
    fi
    
    print_status "Database authentication fix completed!"
    print_status "MySQL root password: ${mysql_root_password}"
    print_status "Asterisk DB password: ${asterisk_db_password}"
    print_status "Default admin login: admin / admin123"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -eq 0 ]; then
        # Use default passwords
        fix_database_authentication "admin123" "asterisk123"
    elif [ $# -eq 1 ]; then
        # Use provided asterisk password, default root password
        fix_database_authentication "admin123" "$1"
    elif [ $# -eq 2 ]; then
        # Use both provided passwords
        fix_database_authentication "$1" "$2"
    else
        echo "Usage: $0 [mysql_root_password] [asterisk_db_password]"
        echo "   or: $0 [asterisk_db_password]"
        echo "   or: $0 (use defaults)"
        exit 1
    fi
fi
