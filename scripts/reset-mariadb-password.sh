
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
    sleep 1
    
    if command -v mysql >/dev/null 2>&1; then
        version_info=$(mysql --version 2>/dev/null || echo "MariaDB not accessible")
        print_status "Database version: $version_info"
    else
        print_warning "MySQL/MariaDB command not found, assuming MariaDB is installed"
    fi
    echo ""
    sleep 1
    
    # Step 2: Stop the database server with improved process control
    print_status "Step 2: Stopping MariaDB server..."
    echo ""
    sleep 1
    
    print_status "Stopping MariaDB service..."
    {
        sudo systemctl stop mariadb 2>/dev/null
        sudo systemctl stop mysql 2>/dev/null
    } >/dev/null 2>&1
    sleep 2
    
    print_status "Terminating remaining MariaDB processes..."
    {
        # Stop processes gracefully first
        sudo pkill -15 mysqld 2>/dev/null
        sudo pkill -15 mariadbd 2>/dev/null
        sleep 3
        
        # Force kill if still running
        sudo pkill -9 mysqld 2>/dev/null
        sudo pkill -9 mariadbd 2>/dev/null
        sudo pkill -9 mysqld_safe 2>/dev/null
    } >/dev/null 2>&1
    
    # Wait for processes to actually stop
    sleep 3
    
    # Verify processes are stopped
    if pgrep -f "mysqld\|mariadbd" >/dev/null 2>&1; then
        print_warning "Some MariaDB processes may still be running, continuing anyway..."
    else
        print_status "✓ All MariaDB processes stopped"
    fi
    echo ""
    sleep 1
    
    # Step 3: Start database without permission checking
    print_status "Step 3: Starting MariaDB in safe mode (without grant tables)..."
    echo ""
    sleep 1
    
    # Remove any existing socket files
    print_status "Cleaning up socket files..."
    {
        sudo rm -f /var/run/mysqld/mysqld.sock 2>/dev/null
        sudo rm -f /tmp/mysql.sock 2>/dev/null
        sudo rm -f /var/lib/mysql/mysql.sock 2>/dev/null
    } >/dev/null 2>&1
    sleep 1
    
    # Start MariaDB in safe mode with complete output suppression
    print_status "Starting mysqld_safe with --skip-grant-tables --skip-networking..."
    echo ""
    sleep 1
    
    # Start in background with all output suppressed
    {
        sudo mysqld_safe --skip-grant-tables --skip-networking --user=mysql
    } >/dev/null 2>&1 &
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
            {
                sudo kill -15 $SAFE_PID 2>/dev/null
                sleep 2
                sudo kill -9 $SAFE_PID 2>/dev/null
            } >/dev/null 2>&1
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
                    {
                        sudo kill -15 $SAFE_PID 2>/dev/null
                        sleep 2
                        sudo kill -9 $SAFE_PID 2>/dev/null
                    } >/dev/null 2>&1
                fi
                return 1
            fi
        fi
    fi
    
    # Step 5: Restart database server normally
    print_status "Step 5: Restarting MariaDB normally..."
    echo ""
    sleep 1
    
    # Stop the safe mode instance with improved cleanup
    print_status "Stopping safe mode instance..."
    {
        if [ -n "$SAFE_PID" ]; then
            sudo kill -15 $SAFE_PID 2>/dev/null
            sleep 3
            sudo kill -9 $SAFE_PID 2>/dev/null
        fi
        
        # Clean up PID files
        if [ -f /var/run/mysqld/mysqld.pid ]; then
            sudo kill -15 $(cat /var/run/mysqld/mysqld.pid) 2>/dev/null
        fi
        
        if [ -f /var/run/mariadb/mariadb.pid ]; then
            sudo kill -15 $(cat /var/run/mariadb/mariadb.pid) 2>/dev/null
        fi
        
        # Final cleanup of all MariaDB processes
        sudo pkill -15 mysqld_safe 2>/dev/null
        sudo pkill -15 mysqld 2>/dev/null
        sudo pkill -15 mariadbd 2>/dev/null
        sleep 3
        sudo pkill -9 mysqld_safe 2>/dev/null
        sudo pkill -9 mysqld 2>/dev/null
        sudo pkill -9 mariadbd 2>/dev/null
    } >/dev/null 2>&1
    
    sleep 3
    
    # Start MariaDB normally
    print_status "Starting MariaDB service normally..."
    echo ""
    {
        sudo systemctl start mariadb
    } >/dev/null 2>&1
    
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

# ... keep existing code (show_usage function and main execution block)

