
#!/bin/bash

# Diagnose why PJSIP endpoints are not being found during registration
source "$(dirname "$0")/utils.sh"

diagnose_endpoint_lookup() {
    local asterisk_db_password=${1:-"fjjdal221"}
    
    print_status "=== Diagnosing PJSIP Endpoint Lookup Issues ==="
    
    # 1. Check what endpoints exist in database
    print_status "1. Checking endpoints in database..."
    echo "Endpoints in ps_endpoints table:"
    mysql -u asterisk -p"${asterisk_db_password}" asterisk -e "SELECT id, auth, aors, context FROM ps_endpoints;" 2>/dev/null || print_error "Database query failed"
    
    echo ""
    echo "Authentication in ps_auths table:"
    mysql -u asterisk -p"${asterisk_db_password}" asterisk -e "SELECT id, username, auth_type FROM ps_auths;" 2>/dev/null
    
    echo ""
    echo "AORs in ps_aors table:"
    mysql -u asterisk -p"${asterisk_db_password}" asterisk -e "SELECT id, max_contacts, remove_existing FROM ps_aors;" 2>/dev/null
    
    # 2. Test ODBC connection from Asterisk
    print_status "2. Testing ODBC connection from Asterisk..."
    local odbc_status=$(sudo asterisk -rx "odbc show all" 2>/dev/null)
    echo "$odbc_status"
    
    if echo "$odbc_status" | grep -q "asterisk.*Connected"; then
        print_status "✓ ODBC connection is active"
    else
        print_error "✗ ODBC connection not active"
        return 1
    fi
    
    # 3. Test realtime loading manually for specific endpoints from logs
    print_status "3. Testing realtime loading for specific endpoints..."
    local test_endpoints=("c303940" "c539609" "c462881")
    
    for endpoint in "${test_endpoints[@]}"; do
        print_status "Testing endpoint: $endpoint"
        
        # Check if endpoint exists in database
        local db_check=$(mysql -u asterisk -p"${asterisk_db_password}" asterisk -e "SELECT COUNT(*) as count FROM ps_endpoints WHERE id='${endpoint}';" 2>/dev/null | tail -1)
        echo "  Database check: $db_check endpoint(s) found"
        
        # Try realtime load
        local realtime_result=$(sudo asterisk -rx "realtime load ps_endpoints id ${endpoint}" 2>/dev/null)
        echo "  Realtime load result: $realtime_result"
        
        # Check if Asterisk can see it
        local asterisk_check=$(sudo asterisk -rx "pjsip show endpoint ${endpoint}" 2>/dev/null)
        if echo "$asterisk_check" | grep -q "Endpoint.*${endpoint}"; then
            print_status "  ✓ Asterisk can see endpoint $endpoint"
        else
            print_error "  ✗ Asterisk cannot see endpoint $endpoint"
        fi
        echo ""
    done
    
    # 4. Check current PJSIP endpoints as seen by Asterisk
    print_status "4. Current PJSIP endpoints visible to Asterisk..."
    sudo asterisk -rx "pjsip show endpoints" 2>/dev/null
    
    # 5. Check sorcery configuration
    print_status "5. Checking sorcery configuration..."
    if [ -f /etc/asterisk/sorcery.conf ]; then
        echo "Current sorcery.conf contents:"
        sudo cat /etc/asterisk/sorcery.conf
    else
        print_error "sorcery.conf not found!"
    fi
    
    # 6. Check extconfig configuration
    print_status "6. Checking extconfig configuration..."
    if [ -f /etc/asterisk/extconfig.conf ]; then
        echo "Current extconfig.conf contents:"
        sudo cat /etc/asterisk/extconfig.conf
    else
        print_error "extconfig.conf not found!"
    fi
    
    # 7. Test direct database query that Asterisk should be doing
    print_status "7. Testing direct database queries..."
    echo "Query that Asterisk should be executing for endpoint lookup:"
    mysql -u asterisk -p"${asterisk_db_password}" asterisk -e "SELECT * FROM ps_endpoints WHERE id='c462881';" 2>/dev/null
    
    print_status ""
    print_status "=== Diagnosis Complete ==="
    print_status "Check the output above to identify why endpoints aren't being found."
}

# Execute if run directly  
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    diagnose_endpoint_lookup "$1"
fi
