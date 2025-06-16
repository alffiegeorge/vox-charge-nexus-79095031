
#!/bin/bash

# ODBC setup script for iBilling
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
    sudo cp "$(dirname "$0")/../config/odbcinst.ini" /etc/odbcinst.ini

    # Write ODBC DSN config from template
    print_status "Configuring ODBC data source..."
    sudo cp "$(dirname "$0")/../config/odbc.ini.template" /etc/odbc.ini
    sudo sed -i "s/ASTERISK_DB_PASSWORD_PLACEHOLDER/${asterisk_db_password}/g" /etc/odbc.ini

    # Verify ODBC driver installation
    print_status "Verifying ODBC driver installation..."
    if odbcinst -q -d | grep -q "MariaDB"; then
        print_status "✓ MariaDB ODBC driver installed"
    else
        print_warning "⚠ MariaDB ODBC driver not found"
    fi

    # Verify DSN configuration
    print_status "Verifying DSN configuration..."
    if odbcinst -q -s | grep -q "asterisk-connector"; then
        print_status "✓ asterisk-connector DSN configured"
    else
        print_warning "⚠ asterisk-connector DSN not found"
    fi

    print_status "ODBC configuration completed"
}

test_odbc_connection() {
    local asterisk_db_password=$1
    
    print_status "Testing ODBC connection..."
    
    # Test with isql
    if command -v isql >/dev/null 2>&1; then
        if echo "SELECT 1 as test;" | isql -v asterisk-connector asterisk "${asterisk_db_password}" 2>/dev/null | grep -q "test"; then
            print_status "✓ ODBC connection test successful"
            return 0
        else
            print_warning "✗ ODBC connection test failed with isql"
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

verify_odbc_realtime() {
    print_status "Verifying ODBC realtime configuration..."
    
    # Check if required configuration files exist
    local config_files=(
        "/etc/asterisk/res_odbc.conf"
        "/etc/asterisk/extconfig.conf"
        "/etc/odbc.ini"
        "/etc/odbcinst.ini"
    )
    
    local missing_files=()
    for file in "${config_files[@]}"; do
        if [ ! -f "$file" ]; then
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        print_error "Missing configuration files: ${missing_files[*]}"
        return 1
    fi
    
    print_status "✓ All ODBC configuration files present"
    return 0
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -ne 1 ]; then
        echo "Usage: $0 <asterisk_db_password>"
        exit 1
    fi
    setup_odbc "$1"
    test_odbc_connection "$1"
    verify_odbc_realtime
fi
