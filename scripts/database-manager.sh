
#!/bin/bash

# Database management module - Updated version
source "$(dirname "$0")/utils.sh"

check_mysql_access() {
    local mysql_root_password=$1
    
    # Test if MySQL is accessible without password
    if mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
        print_status "MySQL root access available without password"
        return 0
    fi
    
    # Test if MySQL is accessible with provided password
    if [ -n "$mysql_root_password" ] && mysql -u root -p"${mysql_root_password}" -e "SELECT 1;" >/dev/null 2>&1; then
        print_status "MySQL root access available with provided password"
        return 0
    fi
    
    return 1
}

reset_mysql_completely() {
    local mysql_root_password=$1
    local asterisk_db_password=$2
    
    print_status "Performing complete MySQL reset..."
    
    # Stop MariaDB
    sudo systemctl stop mariadb
    sleep 3
    
    # Start in safe mode
    print_status "Starting MariaDB in safe mode..."
    sudo mysqld_safe --skip-grant-tables --skip-networking &
    sleep 5
    
    # Reset everything
    print_status "Resetting all database users and permissions..."
    mysql -u root <<EOF
FLUSH PRIVILEGES;
DROP DATABASE IF EXISTS asterisk;
DROP USER IF EXISTS 'asterisk'@'localhost';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysql_root_password}';
CREATE DATABASE asterisk CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'asterisk'@'localhost' IDENTIFIED BY '${asterisk_db_password}';
GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk'@'localhost';
FLUSH PRIVILEGES;
EOF
    
    # Stop safe mode
    print_status "Stopping safe mode..."
    sudo pkill mysqld_safe 2>/dev/null || true
    sudo pkill mysqld 2>/dev/null || true
    sleep 3
    
    # Start normally
    sudo systemctl start mariadb
    sudo systemctl enable mariadb
    sleep 5
    
    # Verify connections
    if mysql -u root -p"${mysql_root_password}" -e "SELECT 1;" >/dev/null 2>&1; then
        print_status "✓ Root access restored"
    else
        print_error "✗ Root access still failing"
        return 1
    fi
    
    if mysql -u asterisk -p"${asterisk_db_password}" asterisk -e "SELECT 1;" >/dev/null 2>&1; then
        print_status "✓ Asterisk user access working"
    else
        print_error "✗ Asterisk user access failing"
        return 1
    fi
    
    return 0
}

setup_database() {
    local mysql_root_password=$1
    local asterisk_db_password=$2
    
    print_status "Setting up database with improved error handling..."
    
    # Ensure MariaDB is installed and running
    if ! systemctl is-active --quiet mariadb; then
        print_status "Starting MariaDB service..."
        sudo systemctl start mariadb
        sudo systemctl enable mariadb
        sleep 5
    fi
    
    # Check if we can access the database
    if ! check_mysql_access "$mysql_root_password"; then
        print_warning "Cannot access MySQL with current credentials, performing reset..."
        if ! reset_mysql_completely "$mysql_root_password" "$asterisk_db_password"; then
            print_error "Failed to reset MySQL. Manual intervention required."
            exit 1
        fi
    else
        print_status "MySQL access verified, proceeding with setup..."
        # Still create the asterisk user and database if they don't exist
        mysql -u root -p"${mysql_root_password}" <<EOF
CREATE DATABASE IF NOT EXISTS asterisk CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'asterisk'@'localhost' IDENTIFIED BY '${asterisk_db_password}';
GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk'@'localhost';
FLUSH PRIVILEGES;
EOF
    fi
    
    # Create database tables
    create_database_tables "$mysql_root_password"
    
    print_status "Database setup completed successfully"
}

create_database_tables() {
    local mysql_root_password=$1
    
    print_status "Creating database tables..."
    
    # Use the schema file if it exists, otherwise create basic tables
    if [ -f "config/database-schema.sql" ]; then
        if mysql -u root -p"${mysql_root_password}" asterisk < "config/database-schema.sql"; then
            print_status "✓ Database schema applied successfully"
        else
            print_error "✗ Failed to apply database schema, creating basic tables..."
            create_basic_tables "$mysql_root_password"
        fi
    else
        print_status "Creating basic tables..."
        create_basic_tables "$mysql_root_password"
    fi
}

create_basic_tables() {
    local mysql_root_password=$1
    
    print_status "Creating basic tables manually..."
    mysql -u root -p"${mysql_root_password}" asterisk <<EOF
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
EOF
    
    print_status "✓ Basic tables created successfully"
}

# Updated function to be called from other scripts
fix_database_auth() {
    local mysql_root_password=${1:-"admin123"}
    local asterisk_db_password=${2:-"asterisk123"}
    
    setup_database "$mysql_root_password" "$asterisk_db_password"
    
    # Update backend environment
    if [ -f "/opt/billing/web/backend/.env" ]; then
        sudo sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=${asterisk_db_password}/" /opt/billing/web/backend/.env
        print_status "✓ Backend environment updated"
    fi
    
    # Restart backend
    sudo systemctl restart ibilling-backend 2>/dev/null || true
}
