
#!/bin/bash

# Diagnose PJSIP realtime configuration
source "$(dirname "$0")/utils.sh"

diagnose_pjsip_realtime() {
    local asterisk_db_password=$1
    
    if [ -z "$asterisk_db_password" ]; then
        print_error "Usage: $0 <asterisk_db_password>"
        return 1
    fi
    
    print_status "=== PJSIP Realtime Diagnosis ==="
    
    # Check if endpoints exist in database
    print_status "1. Checking endpoints in database..."
    local endpoint_count=$(mysql -u asterisk -p"${asterisk_db_password}" asterisk -e "SELECT COUNT(*) FROM ps_endpoints;" 2>/dev/null | tail -1)
    print_status "Endpoints in database: $endpoint_count"
    
    if [ "$endpoint_count" = "0" ]; then
        print_status "No endpoints found in database. Adding test endpoint..."
        
        # Add test endpoint
        mysql -u asterisk -p"${asterisk_db_password}" asterisk <<EOF
-- Insert test endpoint
INSERT INTO ps_endpoints (id, transport, aors, auth, context, disallow, allow, direct_media, ice_support, force_rport, rewrite_contact, rtp_symmetric, send_rpid, callerid)
VALUES ('test1001', 'transport-udp', 'test1001', 'test1001', 'from-internal', 'all', 'ulaw,alaw,g722', 'no', 'yes', 'yes', 'yes', 'yes', 'yes', '"Test User 1001" <test1001>');

-- Insert test auth
INSERT INTO ps_auths (id, auth_type, username, password)
VALUES ('test1001', 'userpass', 'test1001', 'testpass123');

-- Insert test AOR
INSERT INTO ps_aors (id, max_contacts, remove_existing, qualify_frequency)
VALUES ('test1001', 1, 'yes', 60);
EOF
        
        if [ $? -eq 0 ]; then
            print_status "✓ Test endpoint added to database"
        else
            print_error "Failed to add test endpoint"
            return 1
        fi
    fi
    
    # Check ODBC connection from Asterisk
    print_status "2. Testing ODBC connection from Asterisk..."
    local odbc_status=$(sudo asterisk -rx "odbc show all" 2>/dev/null)
    echo "ODBC Status: $odbc_status"
    
    # Test realtime load manually
    print_status "3. Testing manual realtime load..."
    local realtime_test=$(sudo asterisk -rx "realtime load ps_endpoints id test1001" 2>/dev/null)
    print_status "Realtime load result: $realtime_test"
    
    # Check extconfig.conf
    print_status "4. Checking extconfig.conf configuration..."
    if [ -f /etc/asterisk/extconfig.conf ]; then
        print_status "extconfig.conf contents:"
        sudo cat /etc/asterisk/extconfig.conf
    else
        print_error "extconfig.conf not found!"
        return 1
    fi
    
    # Check if sorcery is using realtime
    print_status "5. Testing sorcery realtime..."
    local sorcery_test=$(sudo asterisk -rx "sorcery show config ps_endpoints" 2>/dev/null)
    print_status "Sorcery config for ps_endpoints: $sorcery_test"
    
    # Try to force reload PJSIP with realtime
    print_status "6. Forcing PJSIP reload..."
    sudo asterisk -rx "module unload res_pjsip.so" >/dev/null 2>&1
    sleep 2
    sudo asterisk -rx "module load res_pjsip.so" >/dev/null 2>&1
    sleep 3
    
    # Check endpoints again
    print_status "7. Checking PJSIP endpoints after reload..."
    local pjsip_endpoints=$(sudo asterisk -rx "pjsip show endpoints" 2>/dev/null)
    echo "PJSIP Endpoints: $pjsip_endpoints"
    
    if echo "$pjsip_endpoints" | grep -q "test1001"; then
        print_status "✅ PJSIP realtime is working!"
    else
        print_error "❌ PJSIP realtime is still not working"
        
        # Additional debugging
        print_status "8. Additional debugging..."
        
        # Check if res_config_odbc is loaded
        local res_config_odbc=$(sudo asterisk -rx "module show like res_config_odbc" 2>/dev/null)
        print_status "res_config_odbc status: $res_config_odbc"
        
        # Check Asterisk logs for errors
        print_status "Recent Asterisk logs (last 10 lines):"
        sudo journalctl -u asterisk --since "2 minutes ago" --no-pager | tail -10
        
        print_status "Suggestions:"
        print_status "1. Check if res_config_odbc.so is loaded: asterisk -rx 'module show like res_config_odbc'"
        print_status "2. Check ODBC connectivity: isql -v asterisk-connector asterisk $asterisk_db_password"
        print_status "3. Verify extconfig.conf has correct ODBC mapping"
        print_status "4. Check Asterisk logs for ODBC/realtime errors"
    fi
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    diagnose_pjsip_realtime "$1"
fi
