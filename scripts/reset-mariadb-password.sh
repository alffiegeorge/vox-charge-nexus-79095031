
#!/bin/bash

# MariaDB Password Reset Script
# Based on standard MariaDB password recovery procedures

source "$(dirname "$0")/utils.sh"

reset_mariadb_password() {
    local new_password=${1:-"admin123"}
    
    echo ""
    print_status "=== MARIADB PASSWORD RESET ==="
    echo ""
    sleep 1
    
    print_status "This will reset the MariaDB root password to: $new_password"
    echo ""
    sleep 1
    
    # Step 1: Identify database version
    print_status "Step 1: Identifying database version..."
    echo ""
    sleep 1
    
    if command -v mysql >/dev/null 2>&1; then
        version_info=$(mysql --version 2>/dev/null || echo "MariaDB not accessible")
        print_status "Database version: $version_info"
    else
        print_warning "MySQL/MariaDB command not found, assuming MariaDB is installed"
    fi
    echo ""
    sleep 1
    
    # Step 2: Stop the database server
    print_status "Step 2: Stopping MariaDB server..."
    echo ""
    sleep 1
    
    print_status "Stopping MariaDB service..."
    sudo systemctl stop mariadb >/dev/null 2>&1 || true
    sudo systemctl stop mysql >/dev/null 2>&1 || true
    sleep 2
    
    print_status "Killing remaining MariaDB processes..."
    sudo pkill -9 -f mysqld >/dev/null 2>&1 || true
    sudo pkill -9 -f mariadbd >/dev/null 2>&1 || true
    sleep 3
    
    print_status "✓ MariaDB processes stopped"
    echo ""
    sleep 1
    
    # Step 3: Start database without permission checking
    print_status "Step 3: Starting MariaDB in safe mode (without grant tables)..."
    echo ""
    sleep 1
    
    # Remove any existing socket files
    print_status "Cleaning up socket files..."
    sudo rm -f /var/run/mysqld/mysqld.sock >/dev/null 2>&1 || true
    sudo rm -f /tmp/mysql.sock >/dev/null 2>&1 || true
    sleep 1
    
    # Start MariaDB in safe mode
    print_status "Starting mysqld_safe with --skip-grant-tables --skip-networking..."
    echo ""
    sleep 1
    
    # Redirect all mysqld_safe output to prevent interference
    sudo mysqld_safe --skip-grant-tables --skip-networking >/dev/null 2>&1 &
    SAFE_PID=$!
    
    # Wait for the server to start
    print_status "Waiting for MariaDB to start in safe mode..."
    echo ""
    
    # Test connection with better timing
    local connection_attempts=0
    local max_attempts=15
    
    while [ $connection_attempts -lt $max_attempts ]; do
        connection_attempts=$((connection_attempts + 1))
        
        print_status "Connection attempt $connection_attempts/$max_attempts..."
        
        if mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
            echo ""
            print_status "✓ Successfully connected to MariaDB in safe mode"
            echo ""
            sleep 1
            break
        fi
        
        if [ $connection_attempts -lt $max_attempts ]; then
            sleep 3
        fi
    done
    
    if [ $connection_attempts -eq $max_attempts ]; then
        echo ""
        print_error "Failed to connect to MariaDB in safe mode after $max_attempts attempts"
        echo ""
        
        # Clean up
        if [ -n "$SAFE_PID" ]; then
            sudo kill $SAFE_PID >/dev/null 2>&1 || true
        fi
        return 1
    fi
    
    # Step 4: Change the root password
    print_status "Step 4: Changing root password..."
    echo ""
    sleep 1
    
    # Try ALTER USER method first
    print_status "Attempting password change with ALTER USER..."
    if mysql -u root >/dev/null 2>&1 <<EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${new_password}';
FLUSH PRIVILEGES;
EOF
    then
        print_status "✓ Password changed successfully using ALTER USER"
        echo ""
        password_changed=true
    else
        print_warning "ALTER USER failed, trying SET PASSWORD method..."
        echo ""
        sleep 1
        
        if mysql -u root >/dev/null 2>&1 <<EOF
FLUSH PRIVILEGES;
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${new_password}');
FLUSH PRIVILEGES;
EOF
        then
            print_status "✓ Password changed successfully using SET PASSWORD"
            echo ""
            password_changed=true
        else
            print_warning "SET PASSWORD failed, trying UPDATE method..."
            echo ""
            sleep 1
            
            if mysql -u root >/dev/null 2>&1 <<EOF
FLUSH PRIVILEGES;
UPDATE mysql.user SET authentication_string = PASSWORD('${new_password}') WHERE User = 'root' AND Host = 'localhost';
FLUSH PRIVILEGES;
EOF
            then
                print_status "✓ Password changed successfully using UPDATE"
                echo ""
                password_changed=true
            else
                print_error "All password change methods failed"
                echo ""
                
                # Clean up
                if [ -n "$SAFE_PID" ]; then
                    sudo kill $SAFE_PID >/dev/null 2>&1 || true
                fi
                return 1
            fi
        fi
    fi
    
    # Step 5: Restart database server normally
    print_status "Step 5: Restarting MariaDB normally..."
    echo ""
    sleep 1
    
    # Stop the safe mode instance
    print_status "Stopping safe mode instance..."
    if [ -n "$SAFE_PID" ]; then
        sudo kill $SAFE_PID >/dev/null 2>&1 || true
    fi
    sleep 2
    
    # Alternative cleanup methods
    if [ -f /var/run/mysqld/mysqld.pid ]; then
        sudo kill $(cat /var/run/mysqld/mysqld.pid) >/dev/null 2>&1 || true
    fi
    
    if [ -f /var/run/mariadb/mariadb.pid ]; then
        sudo kill $(cat /var/run/mariadb/mariadb.pid) >/dev/null 2>&1 || true
    fi
    
    # Ensure all processes are stopped
    print_status "Ensuring all MariaDB processes are stopped..."
    sudo pkill -f mysqld_safe >/dev/null 2>&1 || true
    sudo pkill -f mysqld >/dev/null 2>&1 || true
    sudo pkill -f mariadbd >/dev/null 2>&1 || true
    sleep 3
    
    # Start MariaDB normally
    print_status "Starting MariaDB service normally..."
    echo ""
    sudo systemctl start mariadb >/dev/null 2>&1
    
    # Wait for service to be ready with status checks
    print_status "Waiting for MariaDB service to be ready..."
    local service_attempts=0
    local max_service_attempts=10
    
    while [ $service_attempts -lt $max_service_attempts ]; do
        service_attempts=$((service_attempts + 1))
        
        if sudo systemctl is-active --quiet mariadb; then
            print_status "✓ MariaDB service is active"
            break
        fi
        
        print_status "Service start attempt $service_attempts/$max_service_attempts..."
        sleep 2
    done
    
    echo ""
    sleep 1
    
    # Test the new password
    print_status "Testing new password..."
    echo ""
    sleep 1
    
    local password_test_attempts=0
    local max_password_attempts=5
    
    while [ $password_test_attempts -lt $max_password_attempts ]; do
        password_test_attempts=$((password_test_attempts + 1))
        
        if mysql -u root -p"${new_password}" -e "SELECT 1;" >/dev/null 2>&1; then
            print_status "✓ Password reset successful!"
            print_status "✓ MariaDB root password is now: ${new_password}"
            echo ""
            sleep 1
            
            # Secure the installation
            print_status "Securing MariaDB installation..."
            mysql -u root -p"${new_password}" >/dev/null 2>&1 <<EOF
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
            
            print_status "✓ MariaDB installation secured"
            echo ""
            return 0
        fi
        
        if [ $password_test_attempts -lt $max_password_attempts ]; then
            print_status "Password test attempt $password_test_attempts/$max_password_attempts failed, retrying..."
            sleep 3
        fi
    done
    
    print_error "✗ Password reset failed - cannot connect with new password after $max_password_attempts attempts"
    echo ""
    return 1
}

# Display usage information
show_usage() {
    echo ""
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
    echo ""
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
        echo ""
        print_error "Please do not run this script as root"
        print_status "Run as a regular user with sudo access"
        echo ""
        exit 1
    fi
    
    # Check if user has sudo access
    if ! sudo -n true 2>/dev/null; then
        echo ""
        print_error "This script requires sudo access"
        echo ""
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
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Operation cancelled"
        echo ""
        exit 0
    fi
    
    # Execute password reset
    if reset_mariadb_password "$new_password"; then
        echo ""
        echo "=================================================="
        print_status "=== PASSWORD RESET COMPLETED ==="
        echo "=================================================="
        echo ""
        print_status "MariaDB root password: $new_password"
        echo ""
        print_status "You can now connect with:"
        print_status "mysql -u root -p"
        echo ""
        print_status "Remember to:"
        print_status "1. Save your new password securely"
        print_status "2. Update any applications using the old password"
        print_status "3. Consider running mysql_secure_installation for additional security"
        echo ""
    else
        echo ""
        echo "=================================================="
        print_error "=== PASSWORD RESET FAILED ==="
        echo "=================================================="
        echo ""
        print_status "Try running the complete MariaDB reinstall script instead:"
        print_status "./scripts/complete-mariadb-reinstall.sh"
        echo ""
        exit 1
    fi
fi
