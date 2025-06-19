
#!/bin/bash

# Fix realtime authentication and ODBC connection
source "$(dirname "$0")/utils.sh"

fix_realtime_auth() {
    local mysql_root_password=$1
    local asterisk_db_password=$2
    
    if [ -z "$mysql_root_password" ] || [ -z "$asterisk_db_password" ]; then
        print_error "Usage: $0 <mysql_root_password> <asterisk_db_password>"
        return 1
    fi
    
    print_status "Fixing realtime authentication and ODBC connection..."
    
    # Stop Asterisk first
    sudo systemctl stop asterisk
    sleep 3
    
    # Fix database user permissions
    print_status "Fixing database user permissions..."
    mysql -u root -p"${mysql_root_password}" <<EOF
-- Drop and recreate asterisk user with proper permissions
DROP USER IF EXISTS 'asterisk'@'localhost';
CREATE USER 'asterisk'@'localhost' IDENTIFIED BY '${asterisk_db_password}';
GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk'@'localhost';
FLUSH PRIVILEGES;

-- Test the connection
SELECT User, Host FROM mysql.user WHERE User='asterisk';
EOF

    if [ $? -eq 0 ]; then
        print_status "✓ Database user recreated successfully"
    else
        print_error "Failed to recreate database user"
        return 1
    fi
    
    # Test direct database connection
    print_status "Testing direct database connection..."
    if mysql -u asterisk -p"${asterisk_db_password}" -e "SELECT 1;" asterisk >/dev/null 2>&1; then
        print_status "✓ Direct database connection successful"
    else
        print_error "✗ Direct database connection failed"
        return 1
    fi
    
    # Update ODBC configuration with correct password
    print_status "Updating ODBC configuration..."
    sudo sed "s/ASTERISK_DB_PASSWORD_PLACEHOLDER/${asterisk_db_password}/g" "$(dirname "$0")/../config/res_odbc.conf" > /tmp/res_odbc_final.conf
    sudo mv /tmp/res_odbc_final.conf /etc/asterisk/res_odbc.conf
    sudo chown asterisk:asterisk /etc/asterisk/res_odbc.conf
    sudo chmod 640 /etc/asterisk/res_odbc.conf
    
    # Update system ODBC configuration
    sudo sed -i "s/ASTERISK_DB_PASSWORD_PLACEHOLDER/${asterisk_db_password}/g" /etc/odbc.ini
    
    # Test ODBC connection from command line
    print_status "Testing ODBC connection from command line..."
    if echo "SELECT 1 as test;" | timeout 10 isql -v asterisk-connector asterisk "${asterisk_db_password}" 2>/dev/null | grep -q "test"; then
        print_status "✓ ODBC connection test successful"
    else
        print_error "✗ ODBC connection test failed"
        
        # Try to diagnose the issue
        print_status "Diagnosing ODBC issue..."
        echo "SELECT 1;" | isql asterisk-connector asterisk "${asterisk_db_password}" -v 2>&1 | head -10
        return 1
    fi
    
    # Start Asterisk
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
        
        # Reload PJSIP to ensure it uses realtime
        sudo asterisk -rx "pjsip reload" >/dev/null 2>&1
        sleep 3
        
        print_status "✅ Realtime authentication fixed successfully!"
        return 0
    else
        print_error "✗ ODBC connection still not working in Asterisk"
        
        # Show Asterisk logs for debugging
        print_status "Recent Asterisk logs:"
        sudo journalctl -u asterisk --since "2 minutes ago" | grep -i odbc | tail -5
        return 1
    fi
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    fix_realtime_auth "$1" "$2"
fi
