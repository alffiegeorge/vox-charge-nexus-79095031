
#!/bin/bash

# Fix database schema for Asterisk 22 compatibility
source "$(dirname "$0")/utils.sh"

fix_asterisk22_schema() {
    local mysql_root_password=$1
    local asterisk_db_password=$2
    
    if [ -z "$mysql_root_password" ] || [ -z "$asterisk_db_password" ]; then
        print_error "Usage: $0 <mysql_root_password> <asterisk_db_password>"
        return 1
    fi
    
    print_status "=== Fixing Database Schema for Asterisk 22 Compatibility ==="
    
    # Test database connection first
    print_status "1. Testing database connection..."
    if ! mysql -u asterisk -p"${asterisk_db_password}" asterisk -e "SELECT 1;" >/dev/null 2>&1; then
        print_error "✗ Database connection failed"
        return 1
    fi
    print_status "✓ Database connection successful"
    
    # Apply schema fixes
    print_status "2. Applying Asterisk 22 schema fixes..."
    mysql -u asterisk -p"${asterisk_db_password}" asterisk <<EOF
-- Fix 1: Add missing qualify_2xx_only column to ps_contacts
ALTER TABLE ps_contacts ADD COLUMN IF NOT EXISTS qualify_2xx_only ENUM('yes','no') DEFAULT 'no';

-- Fix 2: Increase id column size in ps_contacts to accommodate full contact URI
ALTER TABLE ps_contacts MODIFY id VARCHAR(255);

-- Fix 3: Correct data types for numeric fields in ps_aors
ALTER TABLE ps_aors MODIFY max_contacts INT DEFAULT 1;
ALTER TABLE ps_aors MODIFY remove_existing INT DEFAULT 0;
ALTER TABLE ps_aors MODIFY qualify_frequency INT DEFAULT 0;

-- Fix 4: Ensure ps_endpoint_id_ips table exists for endpoint discovery
CREATE TABLE IF NOT EXISTS ps_endpoint_id_ips (
    id VARCHAR(40) NOT NULL,
    endpoint VARCHAR(40) NOT NULL,
    \`match\` VARCHAR(80) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (endpoint) REFERENCES ps_endpoints(id) ON DELETE CASCADE
);

-- Show table structures to verify fixes
DESCRIBE ps_contacts;
DESCRIBE ps_aors;
DESCRIBE ps_endpoint_id_ips;
EOF
    
    if [ $? -eq 0 ]; then
        print_status "✓ Schema fixes applied successfully"
    else
        print_error "✗ Failed to apply schema fixes"
        return 1
    fi
    
    # Clear stale data that might cause issues
    print_status "3. Clearing stale PJSIP data..."
    mysql -u asterisk -p"${asterisk_db_password}" asterisk <<EOF
-- Clear all dynamic PJSIP data to start fresh
TRUNCATE TABLE ps_contacts;
DELETE FROM ps_endpoints WHERE id LIKE 'c%';
DELETE FROM ps_auths WHERE id LIKE 'c%';
DELETE FROM ps_aors WHERE id LIKE 'c%';
DELETE FROM ps_endpoint_id_ips WHERE endpoint LIKE 'c%';
EOF
    
    if [ $? -eq 0 ]; then
        print_status "✓ Stale data cleared successfully"
    else
        print_error "✗ Failed to clear stale data"
        return 1
    fi
    
    # Copy updated configuration files
    print_status "4. Updating Asterisk configuration files..."
    
    # Update sorcery.conf
    sudo cp /opt/billing/web/config/sorcery.conf /etc/asterisk/sorcery.conf
    sudo chown asterisk:asterisk /etc/asterisk/sorcery.conf
    sudo chmod 644 /etc/asterisk/sorcery.conf
    
    # Update pjsip.conf
    sudo cp /opt/billing/web/config/pjsip.conf /etc/asterisk/pjsip.conf
    sudo chown asterisk:asterisk /etc/asterisk/pjsip.conf
    sudo chmod 644 /etc/asterisk/pjsip.conf
    
    print_status "✓ Configuration files updated"
    
    # Restart Asterisk to apply changes
    print_status "5. Restarting Asterisk..."
    sudo systemctl restart asterisk
    sleep 15
    
    # Verify PJSIP module is loaded
    print_status "6. Verifying PJSIP configuration..."
    local pjsip_status=$(sudo asterisk -rx "pjsip show transports" 2>/dev/null)
    
    if echo "$pjsip_status" | grep -q "udp.*0.0.0.0:5060"; then
        print_status "✓ PJSIP transports are active"
    else
        print_error "✗ PJSIP transports not active"
        return 1
    fi
    
    # Test realtime functionality
    print_status "7. Testing realtime functionality..."
    local realtime_test=$(sudo asterisk -rx "realtime load ps_endpoints id test" 2>/dev/null)
    if [[ "$realtime_test" != *"Failed"* ]]; then
        print_status "✓ Realtime functionality working"
    else
        print_warning "⚠ Realtime test inconclusive (this is normal if no test endpoint exists)"
    fi
    
    print_status "✅ Asterisk 22 schema fixes completed successfully!"
    print_status ""
    print_status "Next steps:"
    print_status "1. Create a new customer via the web interface"
    print_status "2. Check that the endpoint appears with: sudo asterisk -rx 'pjsip show endpoints'"
    print_status "3. Configure a SIP client and attempt registration"
    print_status "4. Monitor logs with: sudo journalctl -u asterisk -f"
    
    return 0
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    fix_asterisk22_schema "$1" "$2"
fi
