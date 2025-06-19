
#!/bin/bash

# iBilling installation main script

# Make scripts executable if they exist
if [ -d "scripts" ]; then
    chmod +x scripts/*.sh 2>/dev/null || true
fi

# Check if we have utils.sh (the main utility file we downloaded)
if [ ! -f "scripts/utils.sh" ]; then
    echo "Error: scripts/utils.sh not found. Please ensure the bootstrap script completed successfully."
    exit 1
fi

# Source the utility functions
source "scripts/utils.sh"

main() {
    print_status "Starting iBilling installation..."
    
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
    
    # Setup database
    if [ -n "$MYSQL_ROOT_PASSWORD" ] && [ -n "$ASTERISK_DB_PASSWORD" ]; then
        if [ -f "scripts/setup-database.sh" ]; then
            chmod +x scripts/setup-database.sh
            ./scripts/setup-database.sh "$MYSQL_ROOT_PASSWORD" "$ASTERISK_DB_PASSWORD"
        else
            print_error "Database setup script not found"
            exit 1
        fi
    fi
    
    # Setup ODBC (if script exists from previous runs)
    if [ -f "scripts/setup-odbc.sh" ]; then
        chmod +x scripts/setup-odbc.sh
        ./scripts/setup-odbc.sh "$ASTERISK_DB_PASSWORD"
    else
        print_status "Setting up ODBC manually..."
        setup_odbc_manual "$ASTERISK_DB_PASSWORD"
    fi
    
    # Install Asterisk
    if [ -f "scripts/install-asterisk.sh" ]; then
        chmod +x scripts/install-asterisk.sh
        ./scripts/install-asterisk.sh "$ASTERISK_DB_PASSWORD"
    else
        print_error "Asterisk installation script not found"
        exit 1
    fi
    
    # Create backend service environment
    setup_backend_service "$ASTERISK_DB_PASSWORD"
    
    print_status "iBilling installation completed successfully!"
    print_status ""
    print_status "Next steps:"
    print_status "1. Set up the web frontend with: scripts/setup-web.sh"
    print_status "2. Configure your first customer endpoints"
    print_status "3. Test the installation with the verification commands"
}

setup_odbc_manual() {
    local asterisk_db_password=$1
    
    print_status "Installing and configuring ODBC for Asterisk realtime..."
    
    # Install ODBC packages
    sudo apt update
    sudo apt install -y unixodbc unixodbc-dev libmariadb-dev odbc-mariadb \
        libodbc1 odbcinst1debian2
    
    # Write ODBC driver config
    if [ -f "config/odbcinst.ini" ]; then
        sudo cp config/odbcinst.ini /etc/odbcinst.ini
    fi

    # Write ODBC DSN config
    if [ -f "config/odbc.ini.template" ]; then
        sudo cp config/odbc.ini.template /etc/odbc.ini
        sudo sed -i "s/ASTERISK_DB_PASSWORD_PLACEHOLDER/${asterisk_db_password}/g" /etc/odbc.ini
    fi

    print_status "ODBC configuration completed"
}

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
    sudo tee /etc/systemd/system/ibilling-backend.service > /dev/null <<EOL
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
EOL

    # Reload systemd
    sudo systemctl daemon-reload
    
    print_status "Backend service configured"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
