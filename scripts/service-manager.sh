
#!/bin/bash

# Service management module
source "$(dirname "$0")/utils.sh"

manage_backend_service() {
    local asterisk_db_password=$1
    
    print_status "Managing iBilling backend service..."
    
    # Check if service exists
    if sudo systemctl list-units --full -all | grep -Fq "ibilling-backend.service"; then
        print_status "Service exists - stopping and disabling..."
        sudo systemctl stop ibilling-backend 2>/dev/null || true
        sudo systemctl disable ibilling-backend 2>/dev/null || true
        
        # Wait for service to fully stop
        sleep 3
        print_status "✓ Existing service stopped"
    else
        print_status "Service does not exist - will create new service"
    fi
    
    # Create environment file
    create_environment_file "$asterisk_db_password"
    
    # Create new systemd service file
    create_systemd_service
    
    # Only enable service if backend directory will exist
    if [ -d "/opt/billing/web/backend" ] && [ -f "/opt/billing/web/backend/server.js" ]; then
        # Reload systemd and enable service
        sudo systemctl daemon-reload
        sudo systemctl enable ibilling-backend
        print_status "✓ Backend service configured and enabled"
    else
        # Just reload systemd, don't enable yet
        sudo systemctl daemon-reload
        print_status "✓ Backend service configured (will be enabled when backend files are available)"
    fi
}

create_environment_file() {
    local asterisk_db_password=$1
    
    print_status "Creating environment configuration..."
    sudo mkdir -p /opt/billing
    
    # Generate JWT secret
    local jwt_secret=$(openssl rand -base64 32)
    
    # Create new environment file
    sudo tee /opt/billing/.env > /dev/null <<EOF
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
EOF

    # Set proper permissions
    sudo chmod 600 /opt/billing/.env
    sudo chown root:root /opt/billing/.env
}

create_systemd_service() {
    print_status "Creating systemd service..."
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
}

setup_system() {
    print_status "Setting up system..."
    
    # Update package lists
    sudo apt update

    # Install necessary packages
    sudo apt install -y wget mariadb-client net-tools vim git

    # Fix locale issues
    print_status "Fixing locale settings..."
    sudo apt install -y locales
    sudo locale-gen en_US.UTF-8
    sudo update-locale LANG=en_US.UTF-8

    # Set timezone
    sudo timedatectl set-timezone UTC
    
    print_status "System setup completed"
}
