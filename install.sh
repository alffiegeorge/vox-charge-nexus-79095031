
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
    
    # Apply integrated realtime fixes
    apply_integrated_realtime_fixes "$MYSQL_ROOT_PASSWORD" "$ASTERISK_DB_PASSWORD"
    
    # Create backend service environment
    setup_backend_service "$ASTERISK_DB_PASSWORD"
    
    print_status "iBilling installation with integrated fixes completed successfully!"
    print_status ""
    print_status "Next steps:"
    print_status "1. Set up the web frontend with: scripts/setup-web.sh"
    print_status "2. Configure your first customer endpoints"
    print_status "3. Test the installation with the verification commands"
}

apply_integrated_realtime_fixes() {
    local mysql_root_password=$1
    local asterisk_db_password=$2
    
    print_status "Applying integrated realtime authentication fixes..."
    
    # Fix database user permissions
    print_status "Fixing database user permissions..."
    mysql -u root -p"${mysql_root_password}" <<EOF
DROP USER IF EXISTS 'asterisk'@'localhost';
CREATE USER 'asterisk'@'localhost' IDENTIFIED BY '${asterisk_db_password}';
GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk'@'localhost';
FLUSH PRIVILEGES;
EOF

    # Ensure sip_credentials table exists
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

    # Apply PJSIP sorcery fix
    print_status "Applying PJSIP sorcery configuration fix..."
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

    # Restart Asterisk to apply fixes
    print_status "Restarting Asterisk to apply configuration fixes..."
    sudo systemctl restart asterisk
    sleep 10
    
    # Test PJSIP after fixes
    if sudo asterisk -rx "pjsip show endpoints" >/dev/null 2>&1; then
        print_status "✓ PJSIP configuration working after fixes"
    else
        print_warning "⚠ PJSIP may need additional configuration"
    fi
    
    print_status "✅ Integrated realtime fixes applied successfully!"
}

# ... keep existing code (setup_backend_service function)
setup_backend_service() {
    local asterisk_db_password=$1
    
    print_status "Setting up backend service..."
    sudo mkdir -p /opt/billing
    
    # Generate JWT secret
    local jwt_secret=$(openssl rand -base64 32)
    
    # Create environment file
    sudo tee /opt/billing/.env > /dev/null <<EOL
# Database Configuration
DB_HOST=localhost
DB_PORT=3306
DB_NAME=asterisk
DB_USER=asterisk
DB_PASSWORD=${asterisk_db_password}

# JWT Configuration
JWT_SECRET=${jwt_secret}

# Server Configuration
PORT=3001
NODE_ENV=production

# Asterisk Configuration
ASTERISK_HOST=localhost
ASTERISK_PORT=5038
ASTERISK_USERNAME=admin
ASTERISK_SECRET=
EOL

    # Set proper permissions
    sudo chmod 600 /opt/billing/.env
    sudo chown root:root /opt/billing/.env
    
    # Create systemd service
    sudo tee /etc/systemd/system/ibilling-backend.service > /dev/null <<EOF
[Unit]
Description=iBilling Backend API Server
After=network.target mysql.service

[Service]
Type=simple
User=ihs
WorkingDirectory=/opt/billing/web/backend
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
EnvironmentFile=/opt/billing/.env

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd
    sudo systemctl daemon-reload
    
    print_status "Backend service configured"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
