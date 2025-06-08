
#!/bin/bash

# Database setup script for iBilling
source "$(dirname "$0")/utils.sh"

setup_database() {
    local mysql_root_password=$1
    local asterisk_db_password=$2
    
    print_status "Configuring MariaDB..."
    sudo systemctl start mariadb
    sudo systemctl enable mariadb

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

    # Create Asterisk database and user
    print_status "Creating Asterisk database and user..."
    sudo mysql -u root -p"${mysql_root_password}" <<EOF
CREATE DATABASE IF NOT EXISTS asterisk CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'asterisk'@'localhost' IDENTIFIED BY '${asterisk_db_password}';
GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk'@'localhost';
FLUSH PRIVILEGES;
EOF

    # Create database tables - use the fix-database-schema script
    print_status "Creating database tables..."
    if [ -f "$(dirname "$0")/fix-database-schema.sh" ]; then
        # Use the comprehensive schema from fix-database-schema.sh
        echo "${mysql_root_password}" | "$(dirname "$0")/fix-database-schema.sh"
    else
        print_warning "fix-database-schema.sh not found, using basic schema"
        # Fallback to basic schema if available
        if [ -f "$(dirname "$0")/../config/database-schema.sql" ]; then
            sudo mysql -u root -p"${mysql_root_password}" asterisk < "$(dirname "$0")/../config/database-schema.sql"
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
