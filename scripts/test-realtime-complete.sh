
#!/bin/bash

# Comprehensive realtime testing script
source "$(dirname "$0")/utils.sh"

test_realtime_complete() {
    local asterisk_db_password=$1
    
    if [ -z "$asterisk_db_password" ]; then
        print_error "Usage: $0 <asterisk_db_password>"
        return 1
    fi
    
    print_status "=== Comprehensive Realtime Test ==="
    
    # Test 1: Database connectivity
    print_status "1. Testing database connectivity..."
    if mysql -u asterisk -p"${asterisk_db_password}" -e "SELECT 1;" asterisk >/dev/null 2>&1; then
        print_status "✓ Database connection works"
    else
        print_error "✗ Database connection failed"
        return 1
    fi
    
    # Test 2: ODBC command line
    print_status "2. Testing ODBC from command line..."
    if echo "SELECT 1 as test;" | isql -v asterisk-connector asterisk "${asterisk_db_password}" 2>/dev/null | grep -q "test"; then
        print_status "✓ ODBC command line works"
    else
        print_error "✗ ODBC command line failed"
        return 1
    fi
    
    # Test 3: Asterisk ODBC connection
    print_status "3. Testing Asterisk ODBC connection..."
    local odbc_output=$(sudo asterisk -rx "odbc show all" 2>/dev/null)
    if echo "$odbc_output" | grep -q "asterisk.*Connected"; then
        print_status "✓ Asterisk ODBC connection active"
    else
        print_error "✗ Asterisk ODBC connection failed"
        echo "ODBC output: $odbc_output"
        return 1
    fi
    
    # Test 4: Realtime tables exist
    print_status "4. Checking realtime tables..."
    local tables=("ps_endpoints" "ps_auths" "ps_aors" "ps_contacts")
    for table in "${tables[@]}"; do
        if mysql -u asterisk -p"${asterisk_db_password}" asterisk -e "SHOW TABLES LIKE '${table}';" 2>/dev/null | grep -q "$table"; then
            print_status "✓ Table $table exists"
        else
            print_error "✗ Table $table missing"
            return 1
        fi
    done
    
    # Test 5: Add test endpoint and verify realtime loading
    print_status "5. Testing realtime endpoint creation..."
    mysql -u asterisk -p"${asterisk_db_password}" asterisk <<EOF
-- Clean up any existing test endpoint
DELETE FROM ps_endpoints WHERE id = 'test100';
DELETE FROM ps_auths WHERE id = 'test100';
DELETE FROM ps_aors WHERE id = 'test100';

-- Insert test endpoint
INSERT INTO ps_endpoints (id, transport, aors, auth, context, disallow, allow, direct_media, ice_support, force_rport, rewrite_contact, rtp_symmetric, send_rpid, callerid)
VALUES ('test100', 'transport-udp', 'test100', 'test100', 'from-internal', 'all', 'ulaw,alaw,g722', 'no', 'yes', 'yes', 'yes', 'yes', 'yes', '"Test User 100" <test100>');

-- Insert test auth
INSERT INTO ps_auths (id, auth_type, username, password)
VALUES ('test100', 'userpass', 'test100', 'testpass123');

-- Insert test AOR
INSERT INTO ps_aors (id, max_contacts, remove_existing, qualify_frequency)
VALUES ('test100', 1, 'yes', 60);
EOF

    if [ $? -eq 0 ]; then
        print_status "✓ Test endpoint added to database"
    else
        print_error "✗ Failed to add test endpoint"
        return 1
    fi
    
    # Test 6: Reload PJSIP and check if endpoint appears
    print_status "6. Testing PJSIP realtime loading..."
    sudo asterisk -rx "pjsip reload" >/dev/null 2>&1
    sleep 5
    
    local pjsip_output=$(sudo asterisk -rx "pjsip show endpoints" 2>/dev/null)
    if echo "$pjsip_output" | grep -q "test100"; then
        print_status "✓ Test endpoint visible in PJSIP"
        print_status "PJSIP Endpoints:"
        echo "$pjsip_output" | grep -A5 -B5 "test100"
    else
        print_error "✗ Test endpoint not visible in PJSIP"
        print_status "Current PJSIP endpoints:"
        echo "$pjsip_output"
        
        # Try manual realtime load
        print_status "Trying manual realtime load..."
        local realtime_load=$(sudo asterisk -rx "realtime load ps_endpoints id test100" 2>/dev/null)
        print_status "Realtime load result: $realtime_load"
        return 1
    fi
    
    # Test 7: Clean up test endpoint
    print_status "7. Cleaning up test endpoint..."
    mysql -u asterisk -p"${asterisk_db_password}" asterisk <<EOF
DELETE FROM ps_endpoints WHERE id = 'test100';
DELETE FROM ps_auths WHERE id = 'test100';
DELETE FROM ps_aors WHERE id = 'test100';
EOF
    
    sudo asterisk -rx "pjsip reload" >/dev/null 2>&1
    
    print_status "✅ All realtime tests passed! PJSIP realtime is working correctly."
    return 0
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    test_realtime_complete "$1"
fi
