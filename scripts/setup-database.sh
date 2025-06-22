
#!/bin/bash

# Database setup script for iBilling with integrated fixes
source "$(dirname "$0")/utils.sh"

setup_database() {
    local mysql_root_password=$1
    local asterisk_db_password=$2
    
    print_status "Configuring MariaDB..."
    
    # Fix MariaDB service first
    fix_mariadb_service
    
    # Secure MariaDB installation
    print_status "Securing MariaDB installation..."
    sudo mysql -u root <<EOF
UPDATE mysql.user SET Password=PASSWORD('${mysql_root_password}') WHERE User='root';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

    # Create Asterisk database and user with proper permissions
    print_status "Creating Asterisk database and user..."
    mysql -u root -p"${mysql_root_password}" <<EOF
DROP DATABASE IF EXISTS asterisk;
DROP USER IF EXISTS 'asterisk'@'localhost';
CREATE DATABASE asterisk CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'asterisk'@'localhost' IDENTIFIED BY '${asterisk_db_password}';
GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk'@'localhost';
FLUSH PRIVILEGES;
EOF

    # Create complete database schema including all tables
    print_status "Creating complete database schema..."
    mysql -u root -p"${mysql_root_password}" asterisk < "$(dirname "$0")/../config/database-schema.sql"
    
    # Verify sip_credentials table exists
    if ! mysql -u asterisk -p"${asterisk_db_password}" asterisk -e "DESCRIBE sip_credentials;" >/dev/null 2>&1; then
        print_status "Creating missing sip_credentials table..."
        mysql -u asterisk -p"${asterisk_db_password}" asterisk <<'EOF'
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
EOF
    fi
    
    # Add sample data
    add_sample_data "$asterisk_db_password"
    
    print_status "Database setup completed successfully"
}

fix_mariadb_service() {
    print_status "Fixing MariaDB service issues..."
    
    # Stop MariaDB if running
    sudo systemctl stop mariadb 2>/dev/null || true
    
    # Check for existing socket files
    if [ -S "/var/run/mysqld/mysqld.sock" ]; then
        print_status "Removing existing socket file..."
        sudo rm -f /var/run/mysqld/mysqld.sock
    fi
    
    # Ensure proper permissions
    sudo mkdir -p /var/run/mysqld
    sudo chown mysql:mysql /var/run/mysqld
    sudo chmod 755 /var/run/mysqld
    
    # Start MariaDB
    print_status "Starting MariaDB..."
    sudo systemctl start mariadb
    
    # Wait for service to be ready
    for i in {1..30}; do
        if sudo systemctl is-active --quiet mariadb; then
            print_status "✓ MariaDB service is running"
            break
        fi
        sleep 1
    done
    
    # Test connection
    if sudo mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
        print_status "✓ MariaDB is accessible"
        return 0
    else
        print_error "✗ MariaDB is not accessible"
        return 1
    fi
}

add_sample_data() {
    local asterisk_db_password=$1
    
    print_status "Adding sample data..."
    
    # Add sample DIDs
    mysql -u asterisk -p"${asterisk_db_password}" asterisk << 'EOF'
INSERT IGNORE INTO did_numbers (number, customer_name, country, rate, type, status, notes) VALUES
('+1-555-0101', 'Unassigned', 'USA', 5.00, 'Local', 'Available', 'Local number for testing'),
('+1-555-0102', 'Unassigned', 'USA', 5.00, 'Local', 'Available', 'Local number for testing'),
('+1-800-555-0103', 'Unassigned', 'USA', 15.00, 'Toll-Free', 'Available', 'Toll-free number'),
('+44-20-7946-0958', 'Unassigned', 'UK', 8.00, 'Local', 'Available', 'London number'),
('+678-555-0104', 'Unassigned', 'Vanuatu', 3.00, 'Local', 'Available', 'Local Vanuatu number'),
('+678-555-0105', 'Unassigned', 'Vanuatu', 3.00, 'Local', 'Available', 'Local Vanuatu number');
EOF

    # Create default admin user
    local admin_hash='$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi'
    mysql -u asterisk -p"${asterisk_db_password}" asterisk <<EOF
INSERT IGNORE INTO users (username, password, email, role, status) VALUES 
('admin', '${admin_hash}', 'admin@ibilling.local', 'admin', 'active');
EOF

    print_status "✓ Sample data added successfully"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -ne 2 ]; then
        echo "Usage: $0 <mysql_root_password> <asterisk_db_password>"
        exit 1
    fi
    setup_database "$1" "$2"
fi
