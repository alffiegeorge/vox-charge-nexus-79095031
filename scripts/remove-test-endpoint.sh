
#!/bin/bash

# Script to remove test endpoint
source "$(dirname "$0")/utils.sh"

remove_test_endpoint() {
    local asterisk_db_password=$1
    
    if [ -z "$asterisk_db_password" ]; then
        print_error "Usage: $0 <asterisk_db_password>"
        return 1
    fi
    
    print_status "Removing test endpoint..."
    
    # Remove test endpoint from database
    mysql -u asterisk -p"${asterisk_db_password}" asterisk <<EOF
DELETE FROM ps_endpoints WHERE id = 'test1001';
DELETE FROM ps_auths WHERE id = 'test1001';
DELETE FROM ps_aors WHERE id = 'test1001';
EOF

    if [ $? -eq 0 ]; then
        print_status "✓ Test endpoint removed from database"
        
        # Reload PJSIP
        sudo asterisk -rx "pjsip reload" >/dev/null 2>&1
        sleep 2
        
        print_status "✓ Test endpoint cleanup completed"
    else
        print_error "Failed to remove test endpoint"
        return 1
    fi
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    remove_test_endpoint "$1"
fi
