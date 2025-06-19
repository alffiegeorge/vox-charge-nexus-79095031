
#!/bin/bash

# Reload PJSIP realtime configuration
source "$(dirname "$0")/utils.sh"

reload_pjsip_realtime() {
    local asterisk_db_password=$1
    
    if [ -z "$asterisk_db_password" ]; then
        print_error "Usage: $0 <asterisk_db_password>"
        return 1
    fi
    
    print_status "=== Reloading PJSIP Realtime Configuration ==="
    
    # 1. Copy updated configuration files
    print_status "1. Updating configuration files..."
    sudo cp /opt/billing/web/config/extconfig.conf /etc/asterisk/extconfig.conf
    sudo cp /opt/billing/web/config/pjsip.conf /etc/asterisk/pjsip.conf
    sudo chown asterisk:asterisk /etc/asterisk/extconfig.conf /etc/asterisk/pjsip.conf
    sudo chmod 644 /etc/asterisk/extconfig.conf /etc/asterisk/pjsip.conf
    
    # 2. Test database connection
    print_status "2. Testing database connection..."
    if ! mysql -u asterisk -p"${asterisk_db_password}" asterisk -e "SELECT COUNT(*) FROM ps_endpoints;" >/dev/null 2>&1; then
        print_error "✗ Database connection failed"
        return 1
    fi
    print_status "✓ Database connection works"
    
    # 3. Ensure all required tables exist and have data
    print_status "3. Checking realtime tables..."
    local endpoint_count=$(mysql -u asterisk -p"${asterisk_db_password}" asterisk -sN -e "SELECT COUNT(*) FROM ps_endpoints;")
    local auth_count=$(mysql -u asterisk -p"${asterisk_db_password}" asterisk -sN -e "SELECT COUNT(*) FROM ps_auths;")
    local aor_count=$(mysql -u asterisk -p"${asterisk_db_password}" asterisk -sN -e "SELECT COUNT(*) FROM ps_aors;")
    
    print_status "✓ Found $endpoint_count endpoints, $auth_count auths, $aor_count AORs"
    
    # 4. Force complete module reload
    print_status "4. Reloading Asterisk modules..."
    sudo asterisk -rx "module unload res_pjsip.so" >/dev/null 2>&1
    sudo asterisk -rx "module unload res_config_odbc.so" >/dev/null 2>&1
    sleep 3
    sudo asterisk -rx "module load res_config_odbc.so" >/dev/null 2>&1
    sleep 2
    sudo asterisk -rx "module load res_pjsip.so" >/dev/null 2>&1
    sleep 5
    
    # 5. Reload all PJSIP configuration
    sudo asterisk -rx "pjsip reload" >/dev/null 2>&1
    sleep 3
    
    # 6. Test realtime loading
    print_status "5. Testing realtime functionality..."
    local realtime_test=$(sudo asterisk -rx "realtime load ps_endpoints id c001" 2>/dev/null)
    if [[ "$realtime_test" != *"Failed"* ]] && [[ "$realtime_test" != "" ]]; then
        print_status "✓ Realtime loading works for c001"
        print_status "Endpoint data: $realtime_test"
    else
        print_error "✗ Realtime loading failed for c001"
        return 1
    fi
    
    # 7. Test ODBC connection
    print_status "6. Testing ODBC connection from Asterisk..."
    local odbc_test=$(sudo asterisk -rx "odbc show all" 2>/dev/null)
    if [[ "$odbc_test" == *"asterisk"* ]] && [[ "$odbc_test" == *"Connected"* || "$odbc_test" == *"Number of active connections"* ]]; then
        print_status "✓ ODBC connection active"
    else
        print_error "✗ ODBC connection not active"
        return 1
    fi
    
    # 8. Show current PJSIP status
    print_status "7. Current PJSIP status..."
    print_status "Transports:"
    sudo asterisk -rx "pjsip show transports" 2>/dev/null
    
    print_status "Endpoints (may be empty until registration):"
    sudo asterisk -rx "pjsip show endpoints" 2>/dev/null
    
    print_status "✅ PJSIP realtime reload completed!"
    print_status ""
    print_status "Now try registering with these credentials:"
    print_status "- Server: $(hostname -I | awk '{print $1}'):5060"
    print_status "- Username: c001"
    print_status "- Password: JAY1qyB4ypSO"
    print_status "- Transport: UDP"
}

# Make script executable
chmod +x "$0"

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    reload_pjsip_realtime "$1"
fi
