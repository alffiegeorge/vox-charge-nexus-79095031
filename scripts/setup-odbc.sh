
#!/bin/bash

# ODBC setup script for iBilling with integrated fixes
source "$(dirname "$0")/utils.sh"

setup_odbc() {
    local asterisk_db_password=$1
    
    print_status "Installing and configuring ODBC for Asterisk realtime..."
    
    # Install ODBC packages
    sudo apt update
    sudo apt install -y unixodbc unixodbc-dev libmariadb-dev odbc-mariadb \
        libodbc1 odbcinst1debian2
    
    # Write ODBC driver config
    print_status "Configuring ODBC drivers..."
    sudo tee /etc/odbcinst.ini > /dev/null <<'EOF'
[MariaDB]
Description=MariaDB ODBC Driver
Driver=/usr/lib/x86_64-linux-gnu/odbc/libmaodbc.so
Setup=/usr/lib/x86_64-linux-gnu/odbc/libodbcmyS.so
FileUsage=1
EOF

    # Write ODBC DSN config
    print_status "Configuring ODBC data source..."
    sudo tee /etc/odbc.ini > /dev/null <<EOF
[asterisk-connector]
Description=MySQL connection to 'asterisk' database
Driver=MariaDB
Database=asterisk
Server=localhost
Port=3306
Socket=/var/run/mysqld/mysqld.sock
Option=3
CharacterSet=utf8
EOF

    # Update res_odbc.conf with modern Asterisk 22 syntax
    print_status "Updating ODBC configuration with modern Asterisk 22 syntax..."
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
EOF

    # Set proper file permissions
    sudo chown asterisk:asterisk /etc/asterisk/res_odbc.conf
    sudo chmod 640 /etc/asterisk/res_odbc.conf

    # Test ODBC connection
    test_odbc_connection "$asterisk_db_password"
    
    print_status "ODBC configuration completed"
}

test_odbc_connection() {
    local asterisk_db_password=$1
    
    print_status "Testing ODBC connection..."
    
    # Test with isql if available
    if command -v isql >/dev/null 2>&1; then
        if echo "SELECT 1 as test;" | isql -v asterisk-connector asterisk "${asterisk_db_password}" 2>/dev/null | grep -q "test"; then
            print_status "✓ ODBC connection test successful"
            return 0
        else
            print_warning "⚠ ODBC connection test failed with isql"
        fi
    else
        print_warning "isql command not available"
    fi

    # Alternative test using odbcinst
    if odbcinst -q -s | grep -q "asterisk-connector"; then
        print_status "✓ ODBC DSN is configured"
    else
        print_error "✗ ODBC DSN configuration failed"
        return 1
    fi

    return 0
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -ne 1 ]; then
        echo "Usage: $0 <asterisk_db_password>"
        exit 1
    fi
    setup_odbc "$1"
fi
