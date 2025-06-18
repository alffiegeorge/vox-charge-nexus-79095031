
#!/bin/bash

# ODBC troubleshooting and fix script for iBilling
source "$(dirname "$0")/utils.sh"

fix_odbc_connection() {
    local asterisk_db_password=$1
    
    print_status "Diagnosing and fixing ODBC connection issues..."
    
    # Stop Asterisk first
    sudo systemctl stop asterisk
    sleep 3
    
    # Check if MariaDB ODBC driver exists in common locations
    print_status "Checking ODBC driver locations..."
    
    local driver_paths=(
        "/usr/lib/x86_64-linux-gnu/odbc/libmaodbc.so"
        "/usr/lib/odbc/libmaodbc.so"
        "/usr/lib64/libmaodbc.so"
        "/usr/local/lib/libmaodbc.so"
        "/opt/mariadb/lib64/libmaodbc.so"
    )
    
    local found_driver=""
    for path in "${driver_paths[@]}"; do
        if [ -f "$path" ]; then
            found_driver="$path"
            print_status "✓ Found MariaDB ODBC driver at: $path"
            break
        fi
    done
    
    if [ -z "$found_driver" ]; then
        print_error "MariaDB ODBC driver not found. Installing..."
        sudo apt update
        sudo apt install -y odbc-mariadb mariadb-client-core-10.6
        
        # Check again
        for path in "${driver_paths[@]}"; do
            if [ -f "$path" ]; then
                found_driver="$path"
                print_status "✓ Found MariaDB ODBC driver at: $path"
                break
            fi
        done
        
        if [ -z "$found_driver" ]; then
            print_error "Still cannot find ODBC driver after installation"
            return 1
        fi
    fi
    
    # Update odbcinst.ini with correct driver path
    print_status "Updating ODBC driver configuration..."
    sudo tee /etc/odbcinst.ini > /dev/null <<EOF
[MariaDB]
Description = MariaDB ODBC driver
Driver      = ${found_driver}
Threading   = 1
UsageCount  = 1

[MariaDB Unicode]
Description = MariaDB ODBC Unicode driver
Driver      = ${found_driver}
Threading   = 1
UsageCount  = 1
EOF
    
    # Find correct MySQL socket path
    print_status "Finding MySQL socket path..."
    local socket_paths=(
        "/var/run/mysqld/mysqld.sock"
        "/tmp/mysql.sock"
        "/var/lib/mysql/mysql.sock"
        "/run/mysqld/mysqld.sock"
    )
    
    local found_socket=""
    for socket in "${socket_paths[@]}"; do
        if [ -S "$socket" ]; then
            found_socket="$socket"
            print_status "✓ Found MySQL socket at: $socket"
            break
        fi
    done
    
    if [ -z "$found_socket" ]; then
        print_warning "MySQL socket not found, using default path"
        found_socket="/var/run/mysqld/mysqld.sock"
    fi
    
    # Update odbc.ini with correct settings
    print_status "Updating ODBC DSN configuration..."
    sudo tee /etc/odbc.ini > /dev/null <<EOF
[asterisk-connector]
Description = MariaDB connection to 'asterisk' database
Driver      = MariaDB
Server      = localhost
Database    = asterisk
User        = asterisk
Password    = ${asterisk_db_password}
Port        = 3306
Socket      = ${found_socket}
Option      = 3
Charset     = utf8
EOF
    
    # Test database connectivity first
    print_status "Testing direct MySQL connection..."
    if mysql -u asterisk -p"${asterisk_db_password}" -e "SELECT 1;" asterisk >/dev/null 2>&1; then
        print_status "✓ Direct MySQL connection successful"
    else
        print_error "✗ Direct MySQL connection failed"
        print_status "Checking if asterisk user exists..."
        mysql -u root -e "SELECT User, Host FROM mysql.user WHERE User='asterisk';" 2>/dev/null || {
            print_error "Cannot check database users. Please verify MySQL root access."
            return 1
        }
        return 1
    fi
    
    # Test ODBC connection
    print_status "Testing ODBC connection..."
    if command -v isql >/dev/null 2>&1; then
        if echo "SELECT 1 as test;" | timeout 10 isql -v asterisk-connector asterisk "${asterisk_db_password}" 2>/dev/null | grep -q "test"; then
            print_status "✓ ODBC connection test successful"
        else
            print_error "✗ ODBC connection test failed"
            
            # Try alternative ODBC test
            print_status "Trying alternative ODBC test..."
            echo "SELECT 1;" | timeout 10 isql asterisk-connector asterisk "${asterisk_db_password}" -v 2>&1 | head -10
            
            # Check ODBC configuration
            print_status "Checking ODBC configuration..."
            odbcinst -q -d 2>/dev/null || print_warning "No ODBC drivers configured"
            odbcinst -q -s 2>/dev/null || print_warning "No ODBC DSNs configured"
        fi
    else
        print_warning "isql command not available, installing unixodbc-bin..."
        sudo apt install -y unixodbc-bin
    fi
    
    # Update Asterisk ODBC configuration with additional options
    print_status "Updating Asterisk ODBC configuration..."
    sudo tee /etc/asterisk/res_odbc.conf > /dev/null <<EOF
[asterisk]
enabled => yes
dsn => asterisk-connector
username => asterisk
password => ${asterisk_db_password}
pooling => no
limit => 1
pre-connect => yes
sanitysql => select 1
connect_timeout => 10
negative_connection_cache => 300
forcecommit => no
isolation => read_committed
EOF
    
    # Ensure proper permissions
    print_status "Setting proper file permissions..."
    sudo chown asterisk:asterisk /etc/asterisk/res_odbc.conf
    sudo chmod 640 /etc/asterisk/res_odbc.conf
    
    # Start Asterisk and test
    print_status "Starting Asterisk..."
    sudo systemctl start asterisk
    sleep 10
    
    # Test ODBC from Asterisk
    print_status "Testing ODBC connection from Asterisk..."
    local odbc_test=$(sudo asterisk -rx "odbc show all" 2>/dev/null)
    echo "ODBC Status: $odbc_test"
    
    if echo "$odbc_test" | grep -q "asterisk.*Connected"; then
        print_status "✓ ODBC connection active in Asterisk"
        
        # Test realtime functionality
        print_status "Testing realtime functionality..."
        sudo asterisk -rx "realtime load ps_endpoints id test" >/dev/null 2>&1
        print_status "✓ Realtime functionality tested"
        
        return 0
    else
        print_error "✗ ODBC connection still not working in Asterisk"
        
        # Show more detailed Asterisk logs
        print_status "Checking Asterisk logs for ODBC errors..."
        sudo journalctl -u asterisk --since "2 minutes ago" | grep -i odbc | tail -10
        
        # Try reloading ODBC module
        print_status "Trying to reload ODBC module..."
        sudo asterisk -rx "module unload res_odbc.so" >/dev/null 2>&1
        sleep 2
        sudo asterisk -rx "module load res_odbc.so" >/dev/null 2>&1
        sleep 3
        
        # Test again
        local odbc_test_retry=$(sudo asterisk -rx "odbc show all" 2>/dev/null)
        if echo "$odbc_test_retry" | grep -q "asterisk.*Connected"; then
            print_status "✓ ODBC connection restored after module reload"
            return 0
        else
            print_error "✗ ODBC connection still failing after reload"
            return 1
        fi
    fi
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -ne 1 ]; then
        echo "Usage: $0 <asterisk_db_password>"
        exit 1
    fi
    fix_odbc_connection "$1"
fi
