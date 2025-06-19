
#!/bin/bash

# MariaDB Password Reset Script
# Based on standard MariaDB password recovery procedures

source "$(dirname "$0")/utils.sh"

reset_mariadb_password() {
    local new_password=${1:-"admin123"}
    
    print_status "=== MARIADB PASSWORD RESET ==="
    print_status "This will reset the MariaDB root password to: $new_password"
    
    # Step 1: Identify database version
    print_status "Step 1: Identifying database version..."
    if command -v mysql >/dev/null 2>&1; then
        version_info=$(mysql --version 2>/dev/null || echo "MariaDB not accessible")
        print_status "Database version: $version_info"
    else
        print_warning "MySQL/MariaDB command not found, assuming MariaDB is installed"
    fi
    
    # Step 2: Stop the database server
    print_status "Step 2: Stopping MariaDB server..."
    sudo systemctl stop mariadb || true
    sudo systemctl stop mysql || true
    
    # Kill any remaining processes
    sudo pkill -9 -f mysqld || true
    sudo pkill -9 -f mariadbd || true
    sleep 3
    
    # Step 3: Start database without permission checking
    print_status "Step 3: Starting MariaDB in safe mode (without grant tables)..."
    
    # Remove any existing socket files
    sudo rm -f /var/run/mysqld/mysqld.sock || true
    sudo rm -f /tmp/mysql.sock || true
    
    # Start MariaDB in safe mode
    print_status "Starting mysqld_safe with --skip-grant-tables --skip-networking..."
    sudo mysqld_safe --skip-grant-tables --skip-networking &
    SAFE_PID=$!
    
    # Wait for the server to start
    print_status "Waiting for MariaDB to start in safe mode..."
    sleep 10
    
    # Test if we can connect
    local connection_attempts=0
    while [ $connection_attempts -lt 10 ]; do
        if mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
            print_status "✓ Successfully connected to MariaDB in safe mode"
            break
        fi
        sleep 2
        connection_attempts=$((connection_attempts + 1))
        print_status "Waiting for connection... (attempt $connection_attempts/10)"
    done
    
    if [ $connection_attempts -eq 10 ]; then
        print_error "Failed to connect to MariaDB in safe mode"
        sudo kill $SAFE_PID 2>/dev/null || true
        return 1
    fi
    
    # Step 4: Change the root password
    print_status "Step 4: Changing root password..."
    
    # Connect and change password
    mysql -u root <<EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${new_password}';
FLUSH PRIVILEGES;
EOF
    
    if [ $? -eq 0 ]; then
        print_status "✓ Password changed successfully using ALTER USER"
    else
        print_warning "ALTER USER failed, trying alternative method..."
        mysql -u root <<EOF
FLUSH PRIVILEGES;
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${new_password}');
FLUSH PRIVILEGES;
EOF
        
        if [ $? -eq 0 ]; then
            print_status "✓ Password changed successfully using SET PASSWORD"
        else
            print_warning "SET PASSWORD failed, trying UPDATE method..."
            mysql -u root <<EOF
FLUSH PRIVILEGES;
UPDATE mysql.user SET authentication_string = PASSWORD('${new_password}') WHERE User = 'root' AND Host = 'localhost';
FLUSH PRIVILEGES;
EOF
            
            if [ $? -eq 0 ]; then
                print_status "✓ Password changed successfully using UPDATE"
            else
                print_error "All password change methods failed"
                sudo kill $SAFE_PID 2>/dev/null || true
                return 1
            fi
        fi
    fi
    
    # Step 5: Restart database server normally
    print_status "Step 5: Restarting MariaDB normally..."
    
    # Stop the safe mode instance
    print_status "Stopping safe mode instance..."
    sudo kill $SAFE_PID 2>/dev/null || true
    
    # Alternative methods to stop mysqld_safe
    if [ -f /var/run/mysqld/mysqld.pid ]; then
        sudo kill $(cat /var/run/mysqld/mysqld.pid) 2>/dev/null || true
    fi
    
    if [ -f /var/run/mariadb/mariadb.pid ]; then
        sudo kill $(cat /var/run/mariadb/mariadb.pid) 2>/dev/null || true
    fi
    
    # Make sure all processes are stopped
    sudo pkill -f mysqld_safe || true
    sudo pkill -f mysqld || true
    sudo pkill -f mariadbd || true
    sleep 5
    
    # Start MariaDB normally
    print_status "Starting MariaDB service normally..."
    sudo systemctl start mariadb
    
    # Wait for service to be ready
    sleep 5
    
    # Test the new password
    print_status "Testing new password..."
    if mysql -u root -p"${new_password}" -e "SELECT 1;" >/dev/null 2>&1; then
        print_status "✓ Password reset successful!"
        print_status "✓ MariaDB root password is now: ${new_password}"
        
        # Secure the installation
        print_status "Securing MariaDB installation..."
        mysql -u root -p"${new_password}" <<EOF
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
        
        print_status "✓ MariaDB installation secured"
        return 0
        
    else
        print_error "✗ Password reset failed - cannot connect with new password"
        return 1
    fi
}

# Display usage information
show_usage() {
    echo "Usage: $0 [new_password]"
    echo ""
    echo "Reset MariaDB root password when you've lost access"
    echo ""
    echo "Examples:"
    echo "  $0                    # Reset to default password 'admin123'"
    echo "  $0 mynewpassword      # Reset to custom password"
    echo ""
    echo "This script will:"
    echo "1. Stop MariaDB service"
    echo "2. Start MariaDB in safe mode (no password required)"
    echo "3. Reset the root password"
    echo "4. Restart MariaDB normally"
    echo "5. Test the new password"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Check if help requested
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        show_usage
        exit 0
    fi
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        print_error "Please do not run this script as root"
        print_status "Run as a regular user with sudo access"
        exit 1
    fi
    
    # Check if user has sudo access
    if ! sudo -n true 2>/dev/null; then
        print_error "This script requires sudo access"
        exit 1
    fi
    
    # Get new password or use default
    if [ $# -eq 0 ]; then
        new_password="admin123"
        print_status "No password provided, using default: admin123"
    else
        new_password="$1"
    fi
    
    # Confirm action
    echo ""
    print_warning "WARNING: This will reset the MariaDB root password!"
    print_status "New password will be: $new_password"
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Operation cancelled"
        exit 0
    fi
    
    # Execute password reset
    if reset_mariadb_password "$new_password"; then
        print_status ""
        print_status "=== PASSWORD RESET COMPLETED ==="
        print_status "MariaDB root password: $new_password"
        print_status ""
        print_status "You can now connect with:"
        print_status "mysql -u root -p"
        print_status ""
        print_status "Remember to:"
        print_status "1. Save your new password securely"
        print_status "2. Update any applications using the old password"
        print_status "3. Consider running mysql_secure_installation for additional security"
    else
        print_error ""
        print_error "=== PASSWORD RESET FAILED ==="
        print_status "Try running the complete MariaDB reinstall script instead:"
        print_status "./scripts/complete-mariadb-reinstall.sh"
        exit 1
    fi
fi
