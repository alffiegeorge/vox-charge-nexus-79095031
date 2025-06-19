
#!/bin/bash

# Complete database cleanup script for iBilling
source "$(dirname "$0")/utils.sh"

clean_database_completely() {
    local mysql_root_password=${1:-"admin123"}
    
    print_status "Performing complete database cleanup..."
    
    # Stop MariaDB first
    sudo systemctl stop mariadb
    sleep 3
    
    # Start MariaDB in safe mode to bypass authentication
    print_status "Starting MariaDB in safe mode..."
    sudo mysqld_safe --skip-grant-tables --skip-networking &
    sleep 5
    
    # Complete cleanup - drop everything
    print_status "Dropping database and removing users..."
    mysql -u root <<EOF
FLUSH PRIVILEGES;
DROP DATABASE IF EXISTS asterisk;
DROP USER IF EXISTS 'asterisk'@'localhost';
DROP USER IF EXISTS 'asterisk'@'%';
DELETE FROM mysql.user WHERE User='asterisk';
DELETE FROM mysql.db WHERE User='asterisk';
FLUSH PRIVILEGES;
EOF
    
    # Reset root user completely
    print_status "Resetting root user authentication..."
    mysql -u root <<EOF
FLUSH PRIVILEGES;
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
UPDATE mysql.user SET Password=PASSWORD('${mysql_root_password}') WHERE User='root' AND Host='localhost';
UPDATE mysql.user SET authentication_string=PASSWORD('${mysql_root_password}') WHERE User='root' AND Host='localhost';
UPDATE mysql.user SET plugin='mysql_native_password' WHERE User='root' AND Host='localhost';
FLUSH PRIVILEGES;
EOF
    
    # Stop safe mode
    print_status "Stopping safe mode and restarting MariaDB normally..."
    sudo pkill mysqld_safe 2>/dev/null || true
    sudo pkill mysqld 2>/dev/null || true
    sleep 3
    
    # Start MariaDB normally
    sudo systemctl start mariadb
    sudo systemctl enable mariadb
    sleep 5
    
    # Verify root access
    print_status "Testing root access after cleanup..."
    if mysql -u root -p"${mysql_root_password}" -e "SELECT 1;" >/dev/null 2>&1; then
        print_status "✓ Root access verified after cleanup"
    else
        print_error "✗ Root access still failing after cleanup"
        print_status "Attempting alternative authentication reset..."
        
        # Alternative method - reset without password first
        sudo systemctl stop mariadb
        sleep 3
        sudo mysqld_safe --skip-grant-tables --skip-networking &
        sleep 5
        
        mysql -u root <<EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysql_root_password}';
FLUSH PRIVILEGES;
EOF
        
        sudo pkill mysqld_safe 2>/dev/null || true
        sudo pkill mysqld 2>/dev/null || true
        sleep 3
        sudo systemctl start mariadb
        sleep 5
        
        if mysql -u root -p"${mysql_root_password}" -e "SELECT 1;" >/dev/null 2>&1; then
            print_status "✓ Root access verified with alternative method"
        else
            print_error "✗ Root access still failing - manual intervention may be needed"
            return 1
        fi
    fi
    
    # Show current databases to confirm cleanup
    print_status "Current databases after cleanup:"
    mysql -u root -p"${mysql_root_password}" -e "SHOW DATABASES;"
    
    # Show current users to confirm cleanup
    print_status "Current users after cleanup:"
    mysql -u root -p"${mysql_root_password}" -e "SELECT User, Host FROM mysql.user;"
    
    # Clear backend environment file database password
    if [ -f "/opt/billing/web/backend/.env" ]; then
        sudo sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=/" /opt/billing/web/backend/.env
        print_status "✓ Cleared database password from backend environment"
    fi
    
    print_status "Database cleanup completed successfully!"
    print_status "MySQL root password: ${mysql_root_password}"
    print_status "Asterisk database and user have been completely removed"
    print_status ""
    print_status "You can now run the database setup script to create fresh database and user:"
    print_status "./scripts/fix-database-auth.sh"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -eq 0 ]; then
        clean_database_completely "admin123"
    elif [ $# -eq 1 ]; then
        clean_database_completely "$1"
    else
        echo "Usage: $0 [mysql_root_password]"
        echo "   or: $0 (use default: admin123)"
        exit 1
    fi
fi
