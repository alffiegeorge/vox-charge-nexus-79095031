
#!/bin/bash

# Diagnose SIP registration failures for Asterisk 22
source "$(dirname "$0")/utils.sh"

diagnose_registration_failure() {
    local customer_id=${1:-"c001"}
    
    print_status "=== Diagnosing SIP Registration Failure for ${customer_id} ==="
    
    # 1. Check if endpoint exists in database
    print_status "1. Checking endpoint in database..."
    local db_endpoint=$(mysql -u asterisk -pfjjdal221 asterisk -e "SELECT id, aors, auth FROM ps_endpoints WHERE id='${customer_id}';" 2>/dev/null)
    
    if echo "$db_endpoint" | grep -q "$customer_id"; then
        print_status "✓ Endpoint exists in database:"
        echo "$db_endpoint"
    else
        print_error "✗ Endpoint not found in database"
        return 1
    fi
    
    # 2. Check AOR configuration
    print_status "2. Checking AOR configuration..."
    local db_aor=$(mysql -u asterisk -pfjjdal221 asterisk -e "SELECT id, max_contacts, remove_existing, qualify_frequency FROM ps_aors WHERE id='${customer_id}';" 2>/dev/null)
    
    if echo "$db_aor" | grep -q "$customer_id"; then
        print_status "✓ AOR exists in database:"
        echo "$db_aor"
    else
        print_error "✗ AOR not found in database"
        return 1
    fi
    
    # 3. Check authentication
    print_status "3. Checking authentication..."
    local db_auth=$(mysql -u asterisk -pfjjdal221 asterisk -e "SELECT id, username, auth_type FROM ps_auths WHERE id='${customer_id}';" 2>/dev/null)
    
    if echo "$db_auth" | grep -q "$customer_id"; then
        print_status "✓ Authentication exists in database:"
        echo "$db_auth"
    else
        print_error "✗ Authentication not found in database"
        return 1
    fi
    
    # 4. Check Asterisk can see the endpoint
    print_status "4. Checking Asterisk endpoint visibility..."
    local asterisk_endpoint=$(sudo asterisk -rx "pjsip show endpoint ${customer_id}" 2>/dev/null)
    
    if echo "$asterisk_endpoint" | grep -q "Endpoint.*${customer_id}"; then
        print_status "✓ Asterisk can see the endpoint"
    else
        print_error "✗ Asterisk cannot see the endpoint"
        print_status "Trying realtime load..."
        sudo asterisk -rx "realtime load ps_endpoints id ${customer_id}" >/dev/null 2>&1
        sleep 2
        
        local asterisk_endpoint_retry=$(sudo asterisk -rx "pjsip show endpoint ${customer_id}" 2>/dev/null)
        if echo "$asterisk_endpoint_retry" | grep -q "Endpoint.*${customer_id}"; then
            print_status "✓ Endpoint visible after realtime load"
        else
            print_error "✗ Endpoint still not visible"
        fi
    fi
    
    # 5. Check contacts table
    print_status "5. Checking contacts table..."
    local db_contacts=$(mysql -u asterisk -pfjjdal221 asterisk -e "SELECT id, uri, endpoint FROM ps_contacts WHERE endpoint='${customer_id}';" 2>/dev/null)
    
    if echo "$db_contacts" | grep -q "$customer_id"; then
        print_status "✓ Contacts exist:"
        echo "$db_contacts"
    else
        print_status "ℹ No contacts found (normal if not registered)"
    fi
    
    # 6. Enable detailed PJSIP logging
    print_status "6. Enabling detailed PJSIP logging..."
    sudo asterisk -rx "pjsip set logger on" >/dev/null 2>&1
    sudo asterisk -rx "core set verbose 5" >/dev/null 2>&1
    sudo asterisk -rx "core set debug 3" >/dev/null 2>&1
    
    print_status "✓ Detailed logging enabled"
    
    # 7. Show current PJSIP status
    print_status "7. Current PJSIP status..."
    print_status "Transports:"
    sudo asterisk -rx "pjsip show transports" 2>/dev/null || print_error "Failed to show transports"
    
    print_status "Endpoints:"
    sudo asterisk -rx "pjsip show endpoints" 2>/dev/null || print_error "Failed to show endpoints"
    
    print_status "Contacts:"
    sudo asterisk -rx "pjsip show contacts" 2>/dev/null || print_error "Failed to show contacts"
    
    # 8. Check recent Asterisk logs for errors
    print_status "8. Recent Asterisk logs (last 2 minutes)..."
    sudo journalctl -u asterisk --since "2 minutes ago" --no-pager | tail -10
    
    print_status ""
    print_status "=== Diagnosis Complete ==="
    print_status ""
    print_status "Next steps to test registration:"
    print_status "1. Configure SIP client with:"
    print_status "   - Server: 172.31.10.10:5060"
    print_status "   - Username: ${customer_id}"
    print_status "   - Password: [check ps_auths table]"
    print_status "   - Transport: UDP"
    print_status ""
    print_status "2. Monitor logs during registration attempt:"
    print_status "   sudo journalctl -u asterisk -f"
    print_status ""
    print_status "3. Check registration status:"
    print_status "   sudo asterisk -rx 'pjsip show contacts'"
}

# Execute if run directly  
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    diagnose_registration_failure "$1"
fi
