
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
    
    # 1. Ensure res_config_odbc is loaded
    print_status "1. Ensuring res_config_odbc module is loaded..."
    sudo asterisk -rx "module load res_config_odbc.so" >/dev/null 2>&1
    
    # 2. Update extconfig.conf with proper mapping
    print_status "2. Updating extconfig.conf..."
    sudo tee /etc/asterisk/extconfig.conf > /dev/null <<EOF
[settings]
; Map Asterisk objects to database tables for realtime

; PJSIP Realtime Configuration
ps_endpoints => odbc,asterisk,ps_endpoints
ps_auths => odbc,asterisk,ps_auths
ps_aors => odbc,asterisk,ps_aors
ps_contacts => odbc,asterisk,ps_contacts

; Legacy SIP realtime (for compatibility)
sipusers => odbc,asterisk,sip_credentials
sippeers => odbc,asterisk,sip_credentials
EOF
    
    # 3. Ensure proper ownership
    sudo chown asterisk:asterisk /etc/asterisk/extconfig.conf
    
    # 4. Test ODBC connection
    print_status "3. Testing ODBC connection..."
    if echo "SELECT 1;" | isql -v asterisk-connector asterisk "${asterisk_db_password}" >/dev/null 2>&1; then
        print_status "✓ ODBC connection works"
    else
        print_error "✗ ODBC connection failed"
        return 1
    fi
    
    # 5. Add test endpoint if not exists
    print_status "4. Ensuring test endpoint exists..."
    mysql -u asterisk -p"${asterisk_db_password}" asterisk <<EOF
-- Insert test endpoint (ignore if exists)
INSERT IGNORE INTO ps_endpoints (id, transport, aors, auth, context, disallow, allow, direct_media, ice_support, force_rport, rewrite_contact, rtp_symmetric, send_rpid, callerid)
VALUES ('test1001', 'transport-udp', 'test1001', 'test1001', 'from-internal', 'all', 'ulaw,alaw,g722', 'no', 'yes', 'yes', 'yes', 'yes', 'yes', '"Test User 1001" <test1001>');

-- Insert test auth (ignore if exists)
INSERT IGNORE INTO ps_auths (id, auth_type, username, password)
VALUES ('test1001', 'userpass', 'test1001', 'testpass123');

-- Insert test AOR (ignore if exists)
INSERT IGNORE INTO ps_aors (id, max_contacts, remove_existing, qualify_frequency)
VALUES ('test1001', 1, 'yes', 60);
EOF
    
    # 6. Force reload all realtime modules
    print_status "5. Reloading realtime modules..."
    sudo asterisk -rx "module unload res_config_odbc.so" >/dev/null 2>&1
    sudo asterisk -rx "module unload res_odbc.so" >/dev/null 2>&1
    sleep 2
    sudo asterisk -rx "module load res_odbc.so" >/dev/null 2>&1
    sudo asterisk -rx "module load res_config_odbc.so" >/dev/null 2>&1
    sleep 3
    
    # 7. Reload PJSIP
    print_status "6. Reloading PJSIP..."
    sudo asterisk -rx "pjsip reload" >/dev/null 2>&1
    sleep 3
    
    # 8. Test if endpoints are now visible
    print_status "7. Testing PJSIP endpoints..."
    local pjsip_endpoints=$(sudo asterisk -rx "pjsip show endpoints" 2>/dev/null)
    
    if echo "$pjsip_endpoints" | grep -q "test1001"; then
        print_status "✅ PJSIP realtime is now working!"
        print_status "Endpoints found:"
        echo "$pjsip_endpoints"
    else
        print_error "❌ PJSIP realtime still not working"
        print_status "Current PJSIP output:"
        echo "$pjsip_endpoints"
        
        # Try manual realtime load
        print_status "Trying manual realtime load..."
        local manual_load=$(sudo asterisk -rx "realtime load ps_endpoints id test1001" 2>/dev/null)
        print_status "Manual load result: $manual_load"
        
        return 1
    fi
    
    print_status "✅ PJSIP realtime configuration fixed successfully!"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    fix_pjsip_realtime "$1"
fi
