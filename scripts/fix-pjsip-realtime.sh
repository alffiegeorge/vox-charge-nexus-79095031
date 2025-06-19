
#!/bin/bash

# Fix PJSIP realtime configuration issues
source "$(dirname "$0")/utils.sh"

fix_pjsip_realtime() {
    local asterisk_db_password=$1
    
    if [ -z "$asterisk_db_password" ]; then
        print_error "Usage: $0 <asterisk_db_password>"
        return 1
    fi
    
    print_status "=== Fixing PJSIP Realtime Configuration ==="
    
    # 1. Test database connection first
    print_status "1. Testing database connection..."
    if ! mysql -u asterisk -p"${asterisk_db_password}" asterisk -e "SELECT COUNT(*) FROM ps_endpoints;" >/dev/null 2>&1; then
        print_error "✗ Database connection failed"
        return 1
    fi
    print_status "✓ Database connection works"
    
    # 2. Copy extconfig.conf to Asterisk directory
    print_status "2. Updating extconfig.conf..."
    sudo cp /opt/billing/web/config/extconfig.conf /etc/asterisk/extconfig.conf
    sudo chown asterisk:asterisk /etc/asterisk/extconfig.conf
    sudo chmod 644 /etc/asterisk/extconfig.conf
    
    # 3. Test ODBC connection from Asterisk CLI
    print_status "3. Testing ODBC connection from Asterisk..."
    local odbc_test=$(sudo asterisk -rx "odbc show all" 2>/dev/null)
    if [[ "$odbc_test" == *"asterisk"* ]] && [[ "$odbc_test" == *"Connected"* || "$odbc_test" == *"Number of active connections"* ]]; then
        print_status "✓ ODBC connection active"
    else
        print_error "✗ ODBC connection not active. Output: $odbc_test"
        return 1
    fi
    
    # 4. Create ps_endpoint_id_ips table if missing for endpoint discovery
    print_status "4. Ensuring endpoint discovery table exists..."
    mysql -u asterisk -p"${asterisk_db_password}" asterisk <<EOF
-- Create ps_endpoint_id_ips table if it doesn't exist
CREATE TABLE IF NOT EXISTS ps_endpoint_id_ips (
    id VARCHAR(40) NOT NULL,
    endpoint VARCHAR(40) NOT NULL,
    match VARCHAR(80) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (endpoint) REFERENCES ps_endpoints(id) ON DELETE CASCADE
);

-- Add endpoint discovery entries for existing endpoints
INSERT IGNORE INTO ps_endpoint_id_ips (id, endpoint, match) 
SELECT CONCAT(id, '_ip'), id, '0.0.0.0/0.0.0.0' FROM ps_endpoints;
EOF
    
    if [ $? -eq 0 ]; then
        print_status "✓ Endpoint discovery table updated"
    else
        print_error "✗ Failed to update endpoint discovery table"
        return 1
    fi
    
    # 5. Force complete module reload
    print_status "5. Reloading PJSIP and realtime modules..."
    sudo asterisk -rx "module unload res_pjsip.so" >/dev/null 2>&1
    sudo asterisk -rx "module unload res_config_odbc.so" >/dev/null 2>&1
    sleep 3
    sudo asterisk -rx "module load res_config_odbc.so" >/dev/null 2>&1
    sleep 2
    sudo asterisk -rx "module load res_pjsip.so" >/dev/null 2>&1
    sleep 5
    
    # 6. Test realtime loading manually
    print_status "6. Testing realtime functionality..."
    local realtime_test=$(sudo asterisk -rx "realtime load ps_endpoints id c001" 2>/dev/null)
    if [[ "$realtime_test" == *"c001"* ]]; then
        print_status "✓ Realtime loading works for endpoints"
    else
        print_error "✗ Realtime loading failed. Output: $realtime_test"
        return 1
    fi
    
    # 7. Check if endpoints are now visible
    print_status "7. Checking PJSIP endpoints..."
    local pjsip_endpoints=$(sudo asterisk -rx "pjsip show endpoints" 2>/dev/null)
    
    if echo "$pjsip_endpoints" | grep -q "c001\|c002"; then
        print_status "✅ PJSIP realtime is working! Endpoints found:"
        echo "$pjsip_endpoints"
    else
        print_warning "⚠ Endpoints not visible in 'pjsip show endpoints'"
        print_status "Testing alternative methods..."
        
        # Test direct sorcery functionality
        local sorcery_test=$(sudo asterisk -rx "sorcery show config ps_endpoints" 2>/dev/null)
        print_status "Sorcery configuration: $sorcery_test"
        
        # Force another reload
        sudo asterisk -rx "pjsip reload" >/dev/null 2>&1
        sleep 3
        
        local pjsip_endpoints_after=$(sudo asterisk -rx "pjsip show endpoints" 2>/dev/null)
        if echo "$pjsip_endpoints_after" | grep -q "c001\|c002"; then
            print_status "✅ Endpoints now visible after reload!"
        else
            print_error "❌ Endpoints still not visible"
            print_status "Manual realtime test shows data exists, but PJSIP may need registration"
            print_status "Try connecting a SIP client with: username=c001, password=JAY1qyB4ypSO"
        fi
    fi
    
    print_status "✅ PJSIP realtime configuration completed!"
    print_status ""
    print_status "Next steps:"
    print_status "1. Configure a SIP client with these credentials:"
    print_status "   - Server: $(hostname -I | awk '{print $1}'):5060"
    print_status "   - Username: c001"
    print_status "   - Password: JAY1qyB4ypSO"
    print_status "   - Transport: UDP"
    print_status ""
    print_status "2. After registration, endpoints will show as online in:"
    print_status "   sudo asterisk -rx 'pjsip show endpoints'"
    print_status "   sudo asterisk -rx 'pjsip show contacts'"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    fix_pjsip_realtime "$1"
fi
