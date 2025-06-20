
#!/bin/bash

# Fix endpoint discovery issues for PJSIP realtime
source "$(dirname "$0")/utils.sh"

fix_endpoint_discovery() {
    local asterisk_db_password=${1:-"fjjdal221"}
    
    print_status "=== Fixing PJSIP Endpoint Discovery Issues ==="
    
    # 1. Ensure extconfig.conf exists and is properly configured
    print_status "1. Creating/updating extconfig.conf..."
    sudo tee /etc/asterisk/extconfig.conf > /dev/null <<EOF
[settings]
; PJSIP Realtime Configuration
ps_endpoints => odbc,asterisk,ps_endpoints
ps_auths => odbc,asterisk,ps_auths  
ps_aors => odbc,asterisk,ps_aors
ps_contacts => odbc,asterisk,ps_contacts
ps_endpoint_id_ips => odbc,asterisk,ps_endpoint_id_ips

; Legacy SIP realtime (for compatibility)
sipusers => odbc,asterisk,sip_credentials
sippeers => odbc,asterisk,sip_credentials
EOF
    
    sudo chown asterisk:asterisk /etc/asterisk/extconfig.conf
    sudo chmod 644 /etc/asterisk/extconfig.conf
    print_status "✓ extconfig.conf created/updated"
    
    # 2. Ensure sorcery.conf is properly configured
    print_status "2. Updating sorcery.conf..."
    sudo tee /etc/asterisk/sorcery.conf > /dev/null <<EOF
; Sorcery configuration for iBilling PJSIP Realtime - Updated for Asterisk 22
; This file enables database lookups for PJSIP objects

[res_pjsip]
endpoint=realtime,ps_endpoints
auth=realtime,ps_auths
aor=realtime,ps_aors
contact=realtime,ps_contacts

[res_pjsip_endpoint_identifier_ip]
identify=realtime,ps_endpoint_id_ips
EOF
    
    sudo chown asterisk:asterisk /etc/asterisk/sorcery.conf
    sudo chmod 644 /etc/asterisk/sorcery.conf
    print_status "✓ sorcery.conf updated"
    
    # 3. Create ps_endpoint_id_ips table and populate it
    print_status "3. Setting up endpoint identification table..."
    mysql -u asterisk -p"${asterisk_db_password}" asterisk <<EOF
-- Create endpoint identification table
CREATE TABLE IF NOT EXISTS ps_endpoint_id_ips (
    id VARCHAR(40) NOT NULL,
    endpoint VARCHAR(40) NOT NULL,
    \`match\` VARCHAR(80) NOT NULL,
    PRIMARY KEY (id),
    KEY endpoint_idx (endpoint)
);

-- Clear existing entries
DELETE FROM ps_endpoint_id_ips;

-- Add identification entries for all existing endpoints
INSERT INTO ps_endpoint_id_ips (id, endpoint, \`match\`) 
SELECT CONCAT(id, '_ip'), id, '0.0.0.0/0.0.0.0' FROM ps_endpoints
WHERE id IS NOT NULL AND id != '';

-- Show what was added
SELECT * FROM ps_endpoint_id_ips;
EOF
    
    if [ $? -eq 0 ]; then
        print_status "✓ Endpoint identification table configured"
    else
        print_error "✗ Failed to configure endpoint identification table"
        return 1
    fi
    
    # 4. Reload Asterisk modules
    print_status "4. Reloading Asterisk realtime modules..."
    sudo asterisk -rx "module unload res_config_odbc.so" >/dev/null 2>&1
    sudo asterisk -rx "module unload res_pjsip.so" >/dev/null 2>&1
    sleep 3
    sudo asterisk -rx "module load res_config_odbc.so" >/dev/null 2>&1
    sleep 2
    sudo asterisk -rx "module load res_pjsip.so" >/dev/null 2>&1
    sleep 5
    
    # 5. Test the configuration
    print_status "5. Testing endpoint visibility..."
    local endpoints_visible=$(sudo asterisk -rx "pjsip show endpoints" 2>/dev/null)
    
    if echo "$endpoints_visible" | grep -q "c[0-9]"; then
        print_status "✅ Endpoints are now visible!"
        echo "$endpoints_visible"
    else
        print_warning "⚠ Endpoints still not visible, trying alternative approach..."
        
        # Force realtime reload
        sudo asterisk -rx "realtime reload" >/dev/null 2>&1
        sleep 3
        
        # Try showing endpoints again
        local endpoints_retry=$(sudo asterisk -rx "pjsip show endpoints" 2>/dev/null)
        if echo "$endpoints_retry" | grep -q "c[0-9]"; then
            print_status "✅ Endpoints visible after realtime reload!"
        else
            print_error "❌ Endpoints still not visible. Manual debugging needed."
            print_status "Try running: sudo ./scripts/diagnose-endpoint-lookup.sh"
        fi
    fi
    
    print_status ""
    print_status "Next steps:"
    print_status "1. Test SIP client registration again"
    print_status "2. Monitor logs: sudo journalctl -u asterisk -f"
    print_status "3. Check endpoints: sudo asterisk -rx 'pjsip show endpoints'"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    fix_endpoint_discovery "$1"
fi
