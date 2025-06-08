
#!/bin/bash

# Database setup script for iBilling
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

setup_database() {
    local mysql_root_password=$1
    local asterisk_db_password=$2
    
    print_status "Configuring MariaDB..."
    sudo systemctl start mariadb
    sudo systemctl enable mariadb

    # Check if root password is already set
    print_status "Checking MariaDB root password status..."
    
    # Try to connect without password first
    if mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
        print_status "MariaDB root has no password set, securing installation..."
        
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
        print_status "✓ MariaDB secured with new password"
        
    elif mysql -u root -p"${mysql_root_password}" -e "SELECT 1;" >/dev/null 2>&1; then
        print_status "✓ MariaDB root password already matches provided password"
        
    else
        print_warning "MariaDB root password is set but doesn't match provided password"
        print_status "Attempting to use existing root password..."
        
        # Prompt for existing password
        echo "Enter the existing MariaDB root password:"
        read -s existing_password
        
        if mysql -u root -p"${existing_password}" -e "SELECT 1;" >/dev/null 2>&1; then
            print_status "✓ Connected with existing password"
            mysql_root_password="${existing_password}"
        else
            print_error "Cannot connect to MariaDB. Please check the root password or reset it manually."
            print_status "To reset MariaDB root password, run:"
            echo "  sudo systemctl stop mariadb"
            echo "  sudo mysqld_safe --skip-grant-tables &"
            echo "  mysql -u root"
            echo "  Then in MySQL: FLUSH PRIVILEGES; ALTER USER 'root'@'localhost' IDENTIFIED BY 'newpassword';"
            return 1
        fi
    fi

    # Create Asterisk database and user
    print_status "Creating Asterisk database and user..."
    mysql -u root -p"${mysql_root_password}" <<EOF
CREATE DATABASE IF NOT EXISTS asterisk CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'asterisk'@'localhost' IDENTIFIED BY '${asterisk_db_password}';
GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk'@'localhost';
FLUSH PRIVILEGES;
EOF

    if [ $? -ne 0 ]; then
        print_error "Failed to create Asterisk database and user"
        return 1
    fi

    # Create database tables - use the fix-database-schema script
    print_status "Creating database tables..."
    if [ -f "${SCRIPT_DIR}/fix-database-schema.sh" ]; then
        # Use the comprehensive schema from fix-database-schema.sh
        echo "${mysql_root_password}" | "${SCRIPT_DIR}/fix-database-schema.sh"
    else
        print_warning "fix-database-schema.sh not found, using basic schema"
        # Fallback to basic schema if available
        if [ -f "${SCRIPT_DIR}/../config/database-schema.sql" ]; then
            mysql -u root -p"${mysql_root_password}" asterisk < "${SCRIPT_DIR}/../config/database-schema.sql"
        fi
    fi
    
    print_status "Database setup completed successfully"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -ne 2 ]; then
        echo "Usage: $0 <mysql_root_password> <asterisk_db_password>"
        exit 1
    fi
    setup_database "$1" "$2"
fi
