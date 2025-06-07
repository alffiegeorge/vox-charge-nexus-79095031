
#!/bin/bash

# Backend setup script for iBilling
source "$(dirname "$0")/utils.sh"

setup_nodejs_backend() {
    print_status "Setting up Node.js backend..."
    
    # Create backend directory if it doesn't exist
    create_directory "/opt/billing/backend"
    
    # Copy backend files
    print_status "Copying backend application files..."
    sudo cp -r "$(dirname "$0")/../backend/"* /opt/billing/backend/
    
    # Set proper ownership
    sudo chown -R $USER:$USER /opt/billing/backend
    
    # Install dependencies
    print_status "Installing backend dependencies..."
    cd /opt/billing/backend
    npm install
    
    print_status "Backend setup completed"
}

create_backend_service() {
    print_status "Creating systemd service for backend..."
    
    # Create systemd service file
    sudo tee /etc/systemd/system/ibilling-backend.service > /dev/null <<EOF
[Unit]
Description=iBilling Backend API Server
After=network.target mysql.service

[Service]
Type=simple
User=$USER
WorkingDirectory=/opt/billing/backend
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
EnvironmentFile=/opt/billing/.env

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start the service
    sudo systemctl daemon-reload
    sudo systemctl enable ibilling-backend
    
    print_status "Backend service created"
}

setup_database_schema() {
    local mysql_root_password=$1
    
    print_status "Setting up additional database tables for backend..."
    
    # Create users table for authentication
    mysql -u root -p"${mysql_root_password}" asterisk <<EOF
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    role ENUM('admin', 'customer', 'operator') NOT NULL DEFAULT 'customer',
    status ENUM('active', 'inactive', 'suspended') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Insert default admin user (password: admin123)
INSERT IGNORE INTO users (username, password, email, role, status) VALUES 
('admin', '\$2a\$10\$YourHashedPasswordHere', 'admin@ibilling.local', 'admin', 'active');
EOF

    print_status "Database schema updated"
}

setup_backend_environment() {
    local asterisk_db_password=$1
    
    print_status "Configuring backend environment..."
    
    # Generate JWT secret
    local jwt_secret=$(openssl rand -base64 32)
    
    # Create backend-specific environment variables
    cat >> /opt/billing/.env <<EOF

# Backend API Configuration
JWT_SECRET=${jwt_secret}
API_PORT=3001

# Backend Database Connection
API_DB_HOST=localhost
API_DB_PORT=3306
API_DB_NAME=asterisk
API_DB_USER=asterisk
API_DB_PASSWORD=${asterisk_db_password}
EOF

    print_status "Backend environment configured"
}

start_backend_service() {
    print_status "Starting backend service..."
    
    sudo systemctl start ibilling-backend
    
    # Wait a moment and check if service started successfully
    sleep 3
    
    if sudo systemctl is-active --quiet ibilling-backend; then
        print_status "✓ Backend service started successfully"
    else
        print_error "✗ Backend service failed to start"
        print_status "Checking service logs..."
        sudo journalctl -u ibilling-backend --no-pager -n 20
        return 1
    fi
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -ne 2 ]; then
        echo "Usage: $0 <mysql_root_password> <asterisk_db_password>"
        exit 1
    fi
    
    setup_nodejs_backend
    setup_database_schema "$1"
    setup_backend_environment "$2"
    create_backend_service
    start_backend_service
fi
