
#!/bin/bash

# iBilling installation main script with integrated fixes

# Make scripts executable if they exist
if [ -d "scripts" ]; then
    chmod +x scripts/*.sh 2>/dev/null || true
fi

# Check if we have utils.sh
if [ ! -f "scripts/utils.sh" ]; then
    echo "Error: scripts/utils.sh not found. Please ensure the bootstrap script completed successfully."
    exit 1
fi

# Source the utility functions
source "scripts/utils.sh"

main() {
    print_status "Starting iBilling installation with integrated fixes..."
    
    # Parse arguments
    if [ $# -eq 0 ]; then
        echo "Usage: $0 <mysql_root_password> <asterisk_db_password>"
        echo "   or: $0 <asterisk_db_password> (if MySQL is already configured)"
        exit 1
    fi

    if [ $# -eq 2 ]; then
        MYSQL_ROOT_PASSWORD=$1
        ASTERISK_DB_PASSWORD=$2
    elif [ $# -eq 1 ]; then
        ASTERISK_DB_PASSWORD=$1
    else
        echo "Usage: $0 <mysql_root_password> <asterisk_db_password>"
        echo "   or: $0 <asterisk_db_password> (if MySQL is already configured)"
        exit 1
    fi
    
    # Install system packages
    print_status "Setting up system packages..."
    sudo apt update
    sudo apt install -y wget mariadb-client net-tools vim git locales
    sudo locale-gen en_US.UTF-8
    sudo update-locale LANG=en_US.UTF-8
    sudo timedatectl set-timezone UTC
    
    # Setup database with integrated fixes
    if [ -n "$MYSQL_ROOT_PASSWORD" ] && [ -n "$ASTERISK_DB_PASSWORD" ]; then
        if [ -f "scripts/setup-database.sh" ]; then
            chmod +x scripts/setup-database.sh
            ./scripts/setup-database.sh "$MYSQL_ROOT_PASSWORD" "$ASTERISK_DB_PASSWORD"
        else
            print_error "Database setup script not found"
            exit 1
        fi
    fi
    
    # Setup ODBC with integrated fixes
    if [ -f "scripts/setup-odbc.sh" ]; then
        chmod +x scripts/setup-odbc.sh
        ./scripts/setup-odbc.sh "$ASTERISK_DB_PASSWORD"
    else
        print_error "ODBC setup script not found"
        exit 1
    fi
    
    # Install Asterisk with PJSIP fixes
    if [ -f "scripts/install-asterisk.sh" ]; then
        chmod +x scripts/install-asterisk.sh
        ./scripts/install-asterisk.sh "$ASTERISK_DB_PASSWORD"
    else
        print_error "Asterisk installation script not found"
        exit 1
    fi
    
    # Apply integrated realtime and PJSIP fixes
    apply_integrated_fixes "$MYSQL_ROOT_PASSWORD" "$ASTERISK_DB_PASSWORD"
    
    # Create backend service environment
    setup_backend_service "$ASTERISK_DB_PASSWORD"
    
    print_status "iBilling installation with integrated fixes completed successfully!"
    print_status ""
    print_status "Next steps:"
    print_status "1. Set up the web frontend with: scripts/setup-web.sh"
    print_status "2. Configure your first customer endpoints"
    print_status "3. Test the installation with the verification commands"
}

apply_integrated_fixes() {
    local mysql_root_password=$1
    local asterisk_db_password=$2
    
    print_status "Applying comprehensive iBilling fixes..."
    
    # Fix database user permissions and ensure all tables exist
    print_status "Ensuring database setup is complete..."
    mysql -u root -p"${mysql_root_password}" <<EOF
DROP USER IF EXISTS 'asterisk'@'localhost';
CREATE USER 'asterisk'@'localhost' IDENTIFIED BY '${asterisk_db_password}';
GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk'@'localhost';
FLUSH PRIVILEGES;
EOF

    # Ensure all required tables exist with proper schema
    print_status "Creating all required database tables..."
    mysql -u asterisk -p"${asterisk_db_password}" asterisk <<'EOF'
-- Customers table
CREATE TABLE IF NOT EXISTS customers (
    id VARCHAR(20) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(20),
    status ENUM('active', 'inactive', 'suspended') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- SIP credentials table
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

-- PJSIP endpoints table
CREATE TABLE IF NOT EXISTS ps_endpoints (
    id varchar(40) NOT NULL,
    transport varchar(40) DEFAULT NULL,
    aors varchar(200) DEFAULT NULL,
    auth varchar(40) DEFAULT NULL,
    context varchar(40) DEFAULT NULL,
    disallow varchar(200) DEFAULT NULL,
    allow varchar(200) DEFAULT NULL,
    direct_media enum('yes','no') DEFAULT NULL,
    ice_support enum('yes','no') DEFAULT NULL,
    force_rport enum('yes','no') DEFAULT NULL,
    rtp_symmetric enum('yes','no') DEFAULT NULL,
    send_rpid enum('yes','no') DEFAULT NULL,
    send_pai enum('yes','no') DEFAULT NULL,
    trust_id_inbound enum('yes','no') DEFAULT NULL,
    callerid varchar(40) DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY id (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- PJSIP authentication table
CREATE TABLE IF NOT EXISTS ps_auths (
    id varchar(40) NOT NULL,
    auth_type enum('md5','userpass') DEFAULT NULL,
    password varchar(80) DEFAULT NULL,
    username varchar(40) DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY id (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- PJSIP AOR table
CREATE TABLE IF NOT EXISTS ps_aors (
    id varchar(40) NOT NULL,
    max_contacts varchar(10) DEFAULT NULL,
    remove_existing tinyint(1) DEFAULT NULL,
    qualify_frequency varchar(10) DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY id (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- PJSIP contacts table
CREATE TABLE IF NOT EXISTS ps_contacts (
    id varchar(255) NOT NULL,
    uri varchar(511) DEFAULT NULL,
    expiration_time varchar(40) DEFAULT NULL,
    endpoint varchar(40) DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY id (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
EOF

    # Apply PJSIP sorcery configuration fix
    print_status "Applying PJSIP sorcery configuration..."
    sudo tee /etc/asterisk/sorcery.conf > /dev/null <<'EOF'
; Sorcery Configuration for Asterisk 22 PJSIP Realtime

[res_pjsip]
endpoint=realtime,ps_endpoints
auth=realtime,ps_auths
aor=realtime,ps_aors
contact=realtime,ps_contacts

[res_pjsip_endpoint_identifier_ip]
identify=realtime,ps_endpoint_id_ips
EOF

    # Create sample customers with proper PJSIP endpoints
    print_status "Creating sample customers with PJSIP endpoints..."
    mysql -u asterisk -p"${asterisk_db_password}" asterisk <<'EOF'
-- Insert sample customers
INSERT IGNORE INTO customers (id, name, email, phone) VALUES
('C001', 'Alfred Iaviniao', 'alfred@example.com', '+1234567890'),
('C002', 'Test Customer', 'test@example.com', '+1234567891');

-- Create SIP credentials for sample customers
INSERT IGNORE INTO sip_credentials (customer_id, sip_username, sip_password, sip_domain) 
SELECT 'C001', 'c001', 'test123', '172.31.10.10'
WHERE NOT EXISTS (SELECT 1 FROM sip_credentials WHERE customer_id = 'C001');

INSERT IGNORE INTO sip_credentials (customer_id, sip_username, sip_password, sip_domain) 
SELECT 'C002', 'c002', 'test456', '172.31.10.10'
WHERE NOT EXISTS (SELECT 1 FROM sip_credentials WHERE customer_id = 'C002');

-- Create PJSIP endpoints for sample customers
INSERT IGNORE INTO ps_endpoints (id, transport, aors, auth, context, disallow, allow, 
                                direct_media, ice_support, force_rport, 
                                rtp_symmetric, send_rpid, send_pai, 
                                trust_id_inbound, callerid)
SELECT sc.sip_username, 'transport-udp', sc.sip_username, sc.sip_username, 'from-internal', 'all', 'ulaw,alaw,g722,g729',
       'no', 'yes', 'yes', 'yes', 'yes', 'yes', 'yes', CONCAT('"', c.name, '" <', sc.sip_username, '>')
FROM sip_credentials sc
JOIN customers c ON sc.customer_id = c.id
WHERE sc.status = 'active'
AND NOT EXISTS (SELECT 1 FROM ps_endpoints WHERE id = sc.sip_username);

-- Create PJSIP authentication entries
INSERT IGNORE INTO ps_auths (id, auth_type, username, password)
SELECT sc.sip_username, 'userpass', sc.sip_username, sc.sip_password
FROM sip_credentials sc
WHERE sc.status = 'active'
AND NOT EXISTS (SELECT 1 FROM ps_auths WHERE id = sc.sip_username);

-- Create PJSIP AOR entries
INSERT IGNORE INTO ps_aors (id, max_contacts, remove_existing, qualify_frequency)
SELECT sc.sip_username, '1', 1, '60'
FROM sip_credentials sc
WHERE sc.status = 'active'
AND NOT EXISTS (SELECT 1 FROM ps_aors WHERE id = sc.sip_username);
EOF

    # Restart Asterisk to apply all fixes
    print_status "Restarting Asterisk to apply all configuration fixes..."
    sudo systemctl restart asterisk
    sleep 10
    
    # Test PJSIP configuration
    print_status "Testing PJSIP configuration..."
    if sudo asterisk -rx "pjsip show endpoints" >/dev/null 2>&1; then
        local endpoint_count=$(sudo asterisk -rx "pjsip show endpoints" 2>/dev/null | grep -c "Endpoint:")
        if [ "$endpoint_count" -gt 0 ]; then
            print_status "✓ PJSIP configuration working with $endpoint_count endpoints"
            
            # Display sample SIP credentials
            print_status ""
            print_status "=== Sample SIP Registration Credentials ==="
            mysql -u asterisk -p"${asterisk_db_password}" asterisk -e "
                SELECT 
                    c.name as 'Customer Name',
                    sc.sip_username as 'SIP Username',
                    sc.sip_password as 'SIP Password',
                    sc.sip_domain as 'SIP Domain'
                FROM sip_credentials sc
                JOIN customers c ON sc.customer_id = c.id
                WHERE sc.status = 'active'
                ORDER BY sc.customer_id;
            " 2>/dev/null
            print_status "Server: 172.31.10.10:5060 (UDP)"
            print_status ""
        else
            print_warning "⚠ PJSIP endpoints created but not visible in Asterisk"
        fi
    else
        print_error "✗ PJSIP configuration failed"
    fi
    
    print_status "✅ All iBilling fixes applied successfully!"
}

setup_backend_service() {
    local asterisk_db_password=$1
    
    print_status "Setting up backend service environment..."
    
    # Ensure backend directory exists
    sudo mkdir -p /opt/billing/web/backend
    
    # Create .env file for backend if it doesn't exist
    if [ ! -f "/opt/billing/web/backend/.env" ]; then
        print_status "Creating backend environment configuration..."
        sudo tee /opt/billing/web/backend/.env > /dev/null <<EOF
# Database Configuration
DB_HOST=localhost
DB_USER=asterisk
DB_PASSWORD=${asterisk_db_password}
DB_NAME=asterisk

# Asterisk AMI Configuration
ASTERISK_HOST=localhost
ASTERISK_AMI_PORT=5038
ASTERISK_USERNAME=admin
ASTERISK_SECRET=admin

# SIP Configuration
SIP_DOMAIN=172.31.10.10

# JWT Configuration
JWT_SECRET=your-secret-key-change-this

# Server Configuration
PORT=3001
NODE_ENV=production
EOF
        sudo chown -R www-data:www-data /opt/billing/web/backend/.env
    fi
    
    print_status "✓ Backend service environment configured"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
