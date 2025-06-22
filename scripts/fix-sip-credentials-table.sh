
#!/bin/bash

# Fix missing sip_credentials table
source "$(dirname "$0")/utils.sh"

fix_sip_credentials_table() {
    local mysql_root_password=${1:-"iii34i3j2"}
    local asterisk_db_password=${2:-"fjjdal221"}
    
    print_status "Creating missing sip_credentials table..."
    
    # Create the missing sip_credentials table
    mysql -u asterisk -p"${asterisk_db_password}" asterisk <<'EOF'
CREATE TABLE IF NOT EXISTS sip_credentials (
    id INT(11) NOT NULL AUTO_INCREMENT,
    customer_id VARCHAR(20) NOT NULL,
    sip_username VARCHAR(40) NOT NULL UNIQUE,
    sip_password VARCHAR(40) NOT NULL,
    sip_domain VARCHAR(100) NOT NULL DEFAULT '172.31.10.10',
    status ENUM('active', 'inactive', 'suspended') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
    INDEX customer_idx (customer_id),
    INDEX username_idx (sip_username)
);
EOF

    if [ $? -eq 0 ]; then
        print_status "✓ sip_credentials table created successfully"
        
        # Restart backend service to ensure it reconnects to database
        print_status "Restarting backend service..."
        sudo systemctl restart ibilling-backend
        sleep 3
        
        if sudo systemctl is-active --quiet ibilling-backend; then
            print_status "✓ Backend service restarted successfully"
        else
            print_error "✗ Backend service failed to restart"
            return 1
        fi
        
    else
        print_error "✗ Failed to create sip_credentials table"
        return 1
    fi
    
    print_status "✅ SIP credentials table fix completed!"
    print_status "You can now try creating SIP endpoints again."
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    fix_sip_credentials_table "$1" "$2"
fi
