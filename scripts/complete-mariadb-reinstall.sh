
#!/bin/bash

# Complete MariaDB reset and reinstall script for iBilling
source "$(dirname "$0")/utils.sh"

complete_mariadb_reinstall() {
    local mysql_root_password=${1:-"admin123"}
    local asterisk_db_password=${2:-"asterisk123"}
    
    print_status "=== COMPLETE MARIADB RESET AND REINSTALL ==="
    
    # Step 1: Try emergency reset first
    print_status "Step 1: Attempting emergency reset..."
    if [ -f "$(dirname "$0")/emergency-mariadb-reset.sh" ]; then
        chmod +x "$(dirname "$0")/emergency-mariadb-reset.sh"
        if "$(dirname "$0")/emergency-mariadb-reset.sh" "$mysql_root_password" "$asterisk_db_password"; then
            print_status "✓ Emergency reset successful! MariaDB is working."
            return 0
        else
            print_warning "Emergency reset failed. Proceeding with complete reinstall..."
        fi
    else
        print_warning "Emergency reset script not found. Proceeding with complete reinstall..."
    fi
    
    # Step 2: Complete uninstall and reinstall
    print_status "Step 2: Performing complete MariaDB uninstall and reinstall..."
    
    # Kill all MySQL/MariaDB processes
    print_status "Killing all MySQL/MariaDB processes..."
    sudo pkill -9 -f mysqld || true
    sudo pkill -9 -f mariadbd || true
    sudo pkill -9 -f mysqld_safe || true
    sudo killall -9 mysqld 2>/dev/null || true
    sudo killall -9 mariadbd 2>/dev/null || true
    sleep 5
    
    # Stop and disable all MySQL/MariaDB services
    print_status "Stopping and disabling services..."
    sudo systemctl stop mariadb || true
    sudo systemctl stop mysql || true
    sudo systemctl disable mariadb || true
    sudo systemctl disable mysql || true
    sleep 3
    
    # Remove all socket and pid files
    print_status "Removing socket and pid files..."
    sudo rm -f /var/run/mysqld/mysqld.sock || true
    sudo rm -f /tmp/mysql.sock || true
    sudo rm -f /var/lib/mysql/mysql.sock || true
    sudo rm -f /var/run/mysqld/mysqld.pid || true
    sudo rm -f /var/lib/mysql/*.pid || true
    
    # Backup existing data
    print_status "Backing up existing data directory..."
    if [ -d "/var/lib/mysql" ]; then
        sudo mv /var/lib/mysql "/var/lib/mysql.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    fi
    
    # Complete package removal
    print_status "Removing all MariaDB/MySQL packages..."
    sudo apt remove --purge -y mariadb-server mariadb-client mariadb-common mysql-common || true
    sudo apt remove --purge -y mariadb-server-10.* mariadb-client-10.* || true
    sudo apt remove --purge -y mysql-server mysql-client || true
    sudo apt autoremove -y || true
    sudo apt autoclean || true
    
    # Remove configuration and data directories
    print_status "Removing configuration and data directories..."
    sudo rm -rf /etc/mysql || true
    sudo rm -rf /var/lib/mysql || true
    sudo rm -rf /var/log/mysql || true
    sudo rm -rf /run/mysqld || true
    sudo rm -rf /var/run/mysqld || true
    
    # Remove any remaining MySQL configuration files
    sudo rm -f /etc/mysql/my.cnf || true
    sudo rm -f /etc/my.cnf || true
    sudo rm -f ~/.my.cnf || true
    
    # Clean package cache
    print_status "Cleaning package cache..."
    sudo apt clean
    sudo apt update
    
    # Install fresh MariaDB
    print_status "Installing fresh MariaDB..."
    export DEBIAN_FRONTEND=noninteractive
    sudo apt install -y mariadb-server mariadb-client
    
    if [ $? -ne 0 ]; then
        print_error "Failed to install MariaDB"
        return 1
    fi
    
    # Create necessary directories with proper permissions
    print_status "Setting up directories and permissions..."
    sudo mkdir -p /var/run/mysqld
    sudo mkdir -p /var/lib/mysql
    sudo chown mysql:mysql /var/run/mysqld
    sudo chown mysql:mysql /var/lib/mysql
    sudo chmod 755 /var/run/mysqld
    
    # Initialize MariaDB if needed
    print_status "Initializing MariaDB..."
    if [ ! -d "/var/lib/mysql/mysql" ]; then
        sudo mysql_install_db --user=mysql --datadir=/var/lib/mysql
    fi
    
    # Start MariaDB service
    print_status "Starting MariaDB service..."
    sudo systemctl enable mariadb
    sudo systemctl start mariadb
    
    # Wait for MariaDB to be ready
    print_status "Waiting for MariaDB to be ready..."
    for i in {1..30}; do
        if sudo mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
            print_status "✓ MariaDB is ready"
            break
        fi
        sleep 2
        if [ $i -eq 30 ]; then
            print_error "MariaDB failed to start properly"
            return 1
        fi
    done
    
    # Configure MariaDB security and create database
    print_status "Configuring MariaDB security and creating database..."
    sudo mysql -u root <<EOF
-- Set root password
ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysql_root_password}';

-- Remove anonymous users
DELETE FROM mysql.user WHERE User='';

-- Remove remote root access
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');

-- Remove test database
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

-- Create asterisk database and user
CREATE DATABASE asterisk CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'asterisk'@'localhost' IDENTIFIED BY '${asterisk_db_password}';
GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk'@'localhost';

-- Apply changes
FLUSH PRIVILEGES;
EOF
    
    if [ $? -ne 0 ]; then
        print_error "Failed to configure MariaDB"
        return 1
    fi
    
    # Test connections
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
    
    # Create basic database schema
    print_status "Creating basic database schema..."
    mysql -u root -p"${mysql_root_password}" asterisk <<'SCHEMA_EOF'
-- Basic users table for authentication
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

-- Basic customers table
CREATE TABLE IF NOT EXISTS customers (
    id VARCHAR(20) NOT NULL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    balance DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    status ENUM('Active', 'Suspended', 'Closed') NOT NULL DEFAULT 'Active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

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

-- Insert default admin user (password: admin123)
INSERT IGNORE INTO users (username, password, email, role, status) VALUES 
('admin', '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin@ibilling.local', 'admin', 'active');

-- Insert sample customer data
INSERT IGNORE INTO customers (id, name, email, balance, status) VALUES 
('CUST001', 'John Doe', 'john.doe@example.com', 100.00, 'Active'),
('CUST002', 'Jane Smith', 'jane.smith@example.com', 250.75, 'Active'),
('CUST003', 'Bob Johnson', 'bob.johnson@example.com', 0.00, 'Suspended');
SCHEMA_EOF
    
    # Update backend environment file if it exists
    if [ -f "/opt/billing/web/backend/.env" ]; then
        print_status "Updating backend environment file..."
        sudo sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=${asterisk_db_password}/" /opt/billing/web/backend/.env
    fi
    
    # Restart backend service if it exists
    if sudo systemctl is-enabled ibilling-backend >/dev/null 2>&1; then
        print_status "Restarting backend service..."
        sudo systemctl restart ibilling-backend
        sleep 3
        
        # Test backend connection
        if curl -s http://localhost:3001/health >/dev/null 2>&1; then
            print_status "✓ Backend service is responding"
        else
            print_warning "⚠ Backend service may need more time to start"
        fi
    fi
    
    print_status "=== COMPLETE MARIADB REINSTALL SUCCESSFUL ==="
    print_status "MySQL Root Password: ${mysql_root_password}"
    print_status "Asterisk DB Password: ${asterisk_db_password}"
    print_status ""
    print_status "Database is ready for use!"
    print_status "You can now run the bootstrap script or continue with installation."
    
    return 0
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -eq 0 ]; then
        complete_mariadb_reinstall "admin123" "asterisk123"
    elif [ $# -eq 1 ]; then
        complete_mariadb_reinstall "admin123" "$1"
    elif [ $# -eq 2 ]; then
        complete_mariadb_reinstall "$1" "$2"
    else
        echo "Usage: $0 [mysql_root_password] [asterisk_db_password]"
        echo "   or: $0 [asterisk_db_password]"
        echo "   or: $0 (use defaults)"
        exit 1
    fi
fi
