
#!/bin/bash

# Test script for PJSIP realtime configuration
source "$(dirname "$0")/utils.sh"

test_realtime_setup() {
    local asterisk_db_password=$1
    
    print_status "Testing PJSIP realtime configuration..."
    
    # Test ODBC connection from command line
    print_status "Testing ODBC connection..."
    if command -v isql >/dev/null 2>&1; then
        if echo "SELECT 1 as test;" | isql -v asterisk-connector asterisk "${asterisk_db_password}" 2>/dev/null | grep -q "test"; then
            print_status "✓ ODBC connection working from command line"
        else
            print_error "✗ ODBC connection failed from command line"
            return 1
        fi
    fi
    
    # Test ODBC connection from Asterisk
    print_status "Testing ODBC connection from Asterisk..."
    odbc_output=$(sudo asterisk -rx "odbc show all" 2>/dev/null)
    if echo "$odbc_output" | grep -q "asterisk.*Connected"; then
        print_status "✓ ODBC connection active in Asterisk"
    else
        print_error "✗ ODBC connection not active in Asterisk"
        print_status "ODBC output: $odbc_output"
        return 1
    fi
    
    # Test realtime tables exist
    print_status "Checking if realtime tables exist..."
    if echo "SHOW TABLES LIKE 'ps_endpoints';" | mysql -u asterisk -p"${asterisk_db_password}" asterisk 2>/dev/null | grep -q "ps_endpoints"; then
        print_status "✓ Realtime tables exist"
    else
        print_error "✗ Realtime tables missing"
        return 1
    fi
    
    # Add a test endpoint to the database
    print_status "Adding test endpoint to database..."
    mysql -u asterisk -p"${asterisk_db_password}" asterisk <<EOF
-- Insert test endpoint
INSERT INTO ps_endpoints (id, transport, aors, auth, context, disallow, allow, direct_media, ice_support, force_rport, rewrite_contact, rtp_symmetric, send_rpid, send_pai, trust_id_inbound, callerid)
VALUES ('testuser', 'transport-udp', 'testuser', 'testuser', 'from-internal', 'all', 'ulaw,alaw,g722', 'no', 'yes', 'yes', 'yes', 'yes', 'yes', 'yes', 'yes', '"Test User" <testuser>')
ON DUPLICATE KEY UPDATE
aors = VALUES(aors), auth = VALUES(auth), callerid = VALUES(callerid);

-- Insert test auth
INSERT INTO ps_auths (id, auth_type, username, password)
VALUES ('testuser', 'userpass', 'testuser', 'testpass123')
ON DUPLICATE KEY UPDATE
username = VALUES(username), password = VALUES(password);

-- Insert test AOR
INSERT INTO ps_aors (id, max_contacts, remove_existing, qualify_frequency)
VALUES ('testuser', 1, 'yes', 60)
ON DUPLICATE KEY UPDATE
max_contacts = VALUES(max_contacts), remove_existing = VALUES(remove_existing);
EOF

    if [ $? -eq 0 ]; then
        print_status "✓ Test endpoint added to database"
    else
        print_error "✗ Failed to add test endpoint to database"
        return 1
    fi
    
    # Reload PJSIP to pick up the new endpoint
    print_status "Reloading PJSIP configuration..."
    sudo asterisk -rx "pjsip reload" >/dev/null 2>&1
    sleep 3
    
    # Test if endpoint shows up
    print_status "Checking if test endpoint appears in PJSIP..."
    pjsip_output=$(sudo asterisk -rx "pjsip show endpoints" 2>/dev/null)
    if echo "$pjsip_output" | grep -q "testuser"; then
        print_status "✓ Test endpoint visible in PJSIP"
        print_status "PJSIP endpoints output:"
        echo "$pjsip_output"
    else
        print_error "✗ Test endpoint not visible in PJSIP"
        print_status "PJSIP endpoints output:"
        echo "$pjsip_output"
        
        # Check realtime load manually
        print_status "Testing manual realtime load..."
        realtime_output=$(sudo asterisk -rx "realtime load ps_endpoints id testuser" 2>/dev/null)
        print_status "Realtime load output: $realtime_output"
        return 1
    fi
    
    print_status "✓ PJSIP realtime configuration test completed successfully"
    return 0
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -ne 1 ]; then
        echo "Usage: $0 <asterisk_db_password>"
        exit 1
    fi
    test_realtime_setup "$1"
fi
