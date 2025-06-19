
#!/bin/bash

# Script to add a test endpoint for demonstrating realtime functionality
source "$(dirname "$0")/utils.sh"

add_test_endpoint() {
    local asterisk_db_password=$1
    
    if [ -z "$asterisk_db_password" ]; then
        print_error "Usage: $0 <asterisk_db_password>"
        return 1
    fi
    
    print_status "Adding test endpoint to demonstrate realtime functionality..."
    
    # Add test endpoint to database
    mysql -u asterisk -p"${asterisk_db_password}" asterisk <<EOF
-- Clean up any existing test endpoint first
DELETE FROM ps_endpoints WHERE id = 'test1001';
DELETE FROM ps_auths WHERE id = 'test1001';
DELETE FROM ps_aors WHERE id = 'test1001';

-- Insert test endpoint
INSERT INTO ps_endpoints (id, transport, aors, auth, context, disallow, allow, direct_media, ice_support, force_rport, rewrite_contact, rtp_symmetric, send_rpid, callerid)
VALUES ('test1001', 'transport-udp', 'test1001', 'test1001', 'from-internal', 'all', 'ulaw,alaw,g722', 'no', 'yes', 'yes', 'yes', 'yes', 'yes', '"Test User 1001" <test1001>');

-- Insert test auth
INSERT INTO ps_auths (id, auth_type, username, password)
VALUES ('test1001', 'userpass', 'test1001', 'testpass123');

-- Insert test AOR
INSERT INTO ps_aors (id, max_contacts, remove_existing, qualify_frequency)
VALUES ('test1001', 1, 'yes', 60);

-- Show what we added
SELECT 'Endpoint:' as type, id, transport, aors, auth, context FROM ps_endpoints WHERE id = 'test1001'
UNION ALL
SELECT 'Auth:', id, auth_type, username, password, '' FROM ps_auths WHERE id = 'test1001'
UNION ALL
SELECT 'AOR:', id, max_contacts, remove_existing, qualify_frequency, '' FROM ps_aors WHERE id = 'test1001';
EOF

    if [ $? -eq 0 ]; then
        print_status "✓ Test endpoint added to database"
        
        # Reload PJSIP to pick up the new endpoint
        print_status "Reloading PJSIP configuration..."
        sudo asterisk -rx "pjsip reload" >/dev/null 2>&1
        sleep 3
        
        # Check if endpoint shows up
        print_status "Checking PJSIP endpoints..."
        local pjsip_output=$(sudo asterisk -rx "pjsip show endpoints" 2>/dev/null)
        if echo "$pjsip_output" | grep -q "test1001"; then
            print_status "✓ Test endpoint visible in PJSIP:"
            echo "$pjsip_output"
        else
            print_status "Current PJSIP endpoints output:"
            echo "$pjsip_output"
            
            # Try manual realtime load
            print_status "Testing manual realtime load..."
            local realtime_load=$(sudo asterisk -rx "realtime load ps_endpoints id test1001" 2>/dev/null)
            print_status "Realtime load result: $realtime_load"
        fi
        
        print_status ""
        print_status "You can now test SIP registration with:"
        print_status "  Username: test1001"
        print_status "  Password: testpass123"
        print_status "  Server: your_server_ip:5060"
        print_status ""
        print_status "To remove the test endpoint, run:"
        print_status "  ./scripts/remove-test-endpoint.sh ${asterisk_db_password}"
        
    else
        print_error "Failed to add test endpoint to database"
        return 1
    fi
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    add_test_endpoint "$1"
fi
