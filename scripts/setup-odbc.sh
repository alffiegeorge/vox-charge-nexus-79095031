
#!/bin/bash

# ODBC setup script for iBilling
source "$(dirname "$0")/utils.sh"

setup_odbc() {
    local asterisk_db_password=$1
    
    print_status "Configuring ODBC..."
    
    # Write ODBC driver config
    sudo cp "$(dirname "$0")/../config/odbcinst.ini" /etc/odbcinst.ini

    # Write ODBC DSN config from template
    sudo cp "$(dirname "$0")/../config/odbc.ini.template" /etc/odbc.ini
    sudo sed -i "s/ASTERISK_DB_PASSWORD_PLACEHOLDER/${asterisk_db_password}/g" /etc/odbc.ini

    print_status "ODBC configuration completed"
}

test_odbc_connection() {
    local asterisk_db_password=$1
    
    print_status "Testing ODBC connection..."
    if isql -v asterisk-connector asterisk "${asterisk_db_password}" <<< "SELECT 1;" >/dev/null 2>&1; then
        print_status "✓ ODBC connection test successful"
        return 0
    else
        print_warning "✗ ODBC connection test failed"
        return 1
    fi
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -ne 1 ]; then
        echo "Usage: $0 <asterisk_db_password>"
        exit 1
    fi
    setup_odbc "$1"
    test_odbc_connection "$1"
fi
