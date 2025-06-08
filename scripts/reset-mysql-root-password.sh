
#!/bin/bash

# Reset MySQL root password script for iBilling
source "$(dirname "$0")/utils.sh"

reset_mysql_root_password() {
    local new_password=${1:-$(generate_password)}
    
    print_status "Resetting MySQL root password..."
    
    # Stop MariaDB service
    print_status "Stopping MariaDB service..."
    sudo systemctl stop mariadb
    
    # Start MariaDB in safe mode without grant tables
    print_status "Starting MariaDB in safe mode..."
    sudo mysqld_safe --skip-grant-tables --skip-networking &
    MYSQLD_PID=$!
    
    # Wait for MySQL to start
    sleep 5
    
    # Reset root password
    print_status "Resetting root password..."
    mysql -u root <<EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${new_password}';
FLUSH PRIVILEGES;
EOF
    
    # Kill the safe mode process
    sudo kill $MYSQLD_PID 2>/dev/null || true
    sleep 2
    
    # Start MariaDB normally
    print_status "Starting MariaDB service normally..."
    sudo systemctl start mariadb
    
    # Test the new password
    print_status "Testing new root password..."
    if mysql -u root -p"${new_password}" -e "SELECT 1;" >/dev/null 2>&1; then
        print_status "✓ MySQL root password reset successfully"
        
        # Update backend environment file if it exists
        if [ -f "/opt/billing/.env" ]; then
            print_status "Updating backend environment file..."
            # Note: We don't update DB_PASSWORD since that's for asterisk user, not root
            print_status "Backend environment file uses asterisk user, no update needed"
        fi
        
        print_status "New MySQL root password: ${new_password}"
        print_warning "SAVE THIS PASSWORD SECURELY!"
        
        return 0
    else
        print_error "Failed to reset MySQL root password"
        return 1
    fi
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -gt 1 ]; then
        echo "Usage: $0 [new_password]"
        echo "If no password provided, a random one will be generated"
        exit 1
    fi
    
    reset_mysql_root_password "$1"
fi
