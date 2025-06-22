
#!/bin/bash

# Fix PJSIP endpoints for all customers
source "$(dirname "$0")/utils.sh"

fix_all_pjsip_endpoints() {
    local mysql_root_password=${1:-"iii34i3j2"}
    local asterisk_db_password=${2:-"fjjdal221"}
    
    print_status "=== Fixing PJSIP Endpoints for All Customers ==="
    
    # Get customers with SIP credentials but no PJSIP endpoints
    print_status "Finding customers with missing PJSIP endpoints..."
    
    local missing_customers=$(mysql -u asterisk -p"${asterisk_db_password}" asterisk -N -e "
        SELECT sc.customer_id, sc.sip_username, sc.sip_password, c.name
        FROM sip_credentials sc
        JOIN customers c ON sc.customer_id = c.id
        WHERE sc.status = 'active'
        AND NOT EXISTS (SELECT 1 FROM ps_endpoints WHERE id = sc.sip_username)
        ORDER BY sc.customer_id;
    " 2>/dev/null)
    
    if [ -z "$missing_customers" ]; then
        print_status "✓ No missing PJSIP endpoints found"
    else
        print_status "Found customers with missing PJSIP endpoints. Fixing..."
        
        # Process each missing endpoint
        echo "$missing_customers" | while read -r customer_id sip_username sip_password customer_name; do
            if [ -n "$customer_id" ]; then
                print_status "Creating PJSIP endpoint for: $customer_id ($customer_name)"
                
                # Create endpoint
                mysql -u asterisk -p"${asterisk_db_password}" asterisk -e "
                    INSERT INTO ps_endpoints (id, transport, aors, auth, context, disallow, allow, 
                                             direct_media, ice_support, force_rport, 
                                             rtp_symmetric, send_rpid, send_pai, trust_id_inbound, callerid)
                    VALUES ('$sip_username', 'transport-udp', '$sip_username', '$sip_username', 'from-internal', 'all', 'ulaw,alaw,g722,g729',
                            'no', 'yes', 'yes', 'yes', 'yes', 'yes', 'yes', '\"$customer_name\" <$sip_username>')
                    ON DUPLICATE KEY UPDATE
                    aors = VALUES(aors), auth = VALUES(auth), callerid = VALUES(callerid);
                " 2>/dev/null
                
                # Create auth
                mysql -u asterisk -p"${asterisk_db_password}" asterisk -e "
                    INSERT INTO ps_auths (id, auth_type, username, password)
                    VALUES ('$sip_username', 'userpass', '$sip_username', '$sip_password')
                    ON DUPLICATE KEY UPDATE
                    username = VALUES(username), password = VALUES(password);
                " 2>/dev/null
                
                # Create AOR with integer value for remove_existing
                mysql -u asterisk -p"${asterisk_db_password}" asterisk -e "
                    INSERT INTO ps_aors (id, max_contacts, remove_existing, qualify_frequency)
                    VALUES ('$sip_username', 1, 1, 60)
                    ON DUPLICATE KEY UPDATE
                    max_contacts = VALUES(max_contacts), remove_existing = VALUES(remove_existing);
                " 2>/dev/null
                
                if [ $? -eq 0 ]; then
                    print_status "✓ PJSIP endpoint created for $customer_id"
                else
                    print_error "✗ Failed to create PJSIP endpoint for $customer_id"
                fi
            fi
        done
    fi
    
    # Also fix any customers that might have SIP credentials but no entry at all
    print_status "Checking for customers without SIP credentials..."
    local customers_without_sip=$(mysql -u asterisk -p"${asterisk_db_password}" asterisk -N -e "
        SELECT c.id, c.name
        FROM customers c
        WHERE NOT EXISTS (SELECT 1 FROM sip_credentials WHERE customer_id = c.id)
        ORDER BY c.id;
    " 2>/dev/null)
    
    if [ -n "$customers_without_sip" ]; then
        print_status "Found customers without SIP credentials. Creating..."
        
        echo "$customers_without_sip" | while read -r customer_id customer_name; do
            if [ -n "$customer_id" ]; then
                print_status "Creating SIP credentials for: $customer_id ($customer_name)"
                
                local sip_username=$(echo "$customer_id" | tr '[:upper:]' '[:lower:]')
                local sip_password=$(openssl rand -base64 12 | tr -d '/+=' | cut -c1-12)
                local sip_domain="172.31.10.10"
                
                # Create SIP credentials
                mysql -u asterisk -p"${asterisk_db_password}" asterisk -e "
                    INSERT INTO sip_credentials (customer_id, sip_username, sip_password, sip_domain, status)
                    VALUES ('$customer_id', '$sip_username', '$sip_password', '$sip_domain', 'active')
                    ON DUPLICATE KEY UPDATE
                    sip_password = VALUES(sip_password), sip_domain = VALUES(sip_domain);
                " 2>/dev/null
                
                # Create PJSIP endpoint
                mysql -u asterisk -p"${asterisk_db_password}" asterisk -e "
                    INSERT INTO ps_endpoints (id, transport, aors, auth, context, disallow, allow, 
                                             direct_media, ice_support, force_rport, 
                                             rtp_symmetric, send_rpid, send_pai, trust_id_inbound, callerid)
                    VALUES ('$sip_username', 'transport-udp', '$sip_username', '$sip_username', 'from-internal', 'all', 'ulaw,alaw,g722,g729',
                            'no', 'yes', 'yes', 'yes', 'yes', 'yes', 'yes', '\"$customer_name\" <$sip_username>')
                    ON DUPLICATE KEY UPDATE
                    aors = VALUES(aors), auth = VALUES(auth), callerid = VALUES(callerid);
                " 2>/dev/null
                
                # Create PJSIP auth
                mysql -u asterisk -p"${asterisk_db_password}" asterisk -e "
                    INSERT INTO ps_auths (id, auth_type, username, password)
                    VALUES ('$sip_username', 'userpass', '$sip_username', '$sip_password')
                    ON DUPLICATE KEY UPDATE
                    username = VALUES(username), password = VALUES(password);
                " 2>/dev/null
                
                # Create PJSIP AOR
                mysql -u asterisk -p"${asterisk_db_password}" asterisk -e "
                    INSERT INTO ps_aors (id, max_contacts, remove_existing, qualify_frequency)
                    VALUES ('$sip_username', 1, 1, 60)
                    ON DUPLICATE KEY UPDATE
                    max_contacts = VALUES(max_contacts), remove_existing = VALUES(remove_existing);
                " 2>/dev/null
                
                if [ $? -eq 0 ]; then
                    print_status "✓ Complete PJSIP setup created for $customer_id"
                else
                    print_error "✗ Failed to create complete PJSIP setup for $customer_id"
                fi
            fi
        done
    fi
    
    # Reload PJSIP configuration
    print_status "Reloading PJSIP configuration..."
    sudo asterisk -rx "pjsip reload" >/dev/null 2>&1
    sleep 3
    
    # Verify endpoints are now visible
    print_status "Verifying PJSIP endpoints..."
    local endpoint_count=$(sudo asterisk -rx "pjsip show endpoints" 2>/dev/null | grep -c "Endpoint:")
    
    if [ "$endpoint_count" -gt 0 ]; then
        print_status "✓ PJSIP endpoints are now visible ($endpoint_count endpoints)"
        
        # Show all SIP credentials for reference
        print_status ""
        print_status "=== SIP Registration Credentials ==="
        mysql -u asterisk -p"${asterisk_db_password}" asterisk -e "
            SELECT 
                sc.customer_id as 'Customer ID',
                c.name as 'Customer Name',
                sc.sip_username as 'SIP Username',
                sc.sip_password as 'SIP Password',
                sc.sip_domain as 'SIP Domain'
            FROM sip_credentials sc
            JOIN customers c ON sc.customer_id = c.id
            WHERE sc.status = 'active'
            ORDER BY sc.customer_id;
        " 2>/dev/null
        
    else
        print_error "✗ No PJSIP endpoints visible after fix"
    fi
    
    print_status ""
    print_status "✅ PJSIP endpoint fix completed!"
    print_status ""
    print_status "To test registration:"
    print_status "1. Use the SIP credentials shown above"
    print_status "2. Configure your SIP client with server: 172.31.10.10:5060"
    print_status "3. Check registration status: sudo asterisk -rx 'pjsip show contacts'"
    print_status "4. Monitor logs: sudo journalctl -u asterisk -f"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    fix_all_pjsip_endpoints "$1" "$2"
fi
