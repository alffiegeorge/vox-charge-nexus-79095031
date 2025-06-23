
#!/bin/bash

# Backend setup script for iBilling
source "$(dirname "$0")/utils.sh"

setup_nodejs_backend() {
    print_status "Setting up Node.js backend..."
    
    # Create backend directory if it doesn't exist
    create_directory "/opt/billing/web/backend"
    create_directory "/opt/billing/web/backend/routes"
    
    # Copy backend files
    print_status "Copying backend application files..."
    if [ -d "backend" ]; then
        sudo cp -r backend/* /opt/billing/web/backend/
    else
        print_error "Backend directory not found in current location"
        return 1
    fi
    
    # Set proper ownership
    sudo chown -R $USER:$USER /opt/billing/web/backend
    
    # Install dependencies
    print_status "Installing backend dependencies..."
    cd /opt/billing/web/backend
    
    # Install all required dependencies
    npm install express cors jsonwebtoken bcryptjs dotenv mysql2
    
    print_status "Backend setup completed"
}

create_backend_service() {
    print_status "Creating systemd service for backend..."
    
    # Create systemd service file with correct paths
    sudo tee /etc/systemd/system/ibilling-backend.service > /dev/null <<EOF
[Unit]
Description=iBilling Backend API Server
After=network.target mysql.service

[Service]
Type=simple
User=$USER
WorkingDirectory=/opt/billing/web/backend
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
EnvironmentFile=/opt/billing/web/backend/.env

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
-- Hash generated with bcrypt for admin123
INSERT IGNORE INTO users (username, password, email, role, status) VALUES 
('admin', '\$2a\$10\$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin@ibilling.local', 'admin', 'active');
EOF

    print_status "Database schema updated"
}

setup_backend_environment() {
    local asterisk_db_password=$1
    
    print_status "Configuring backend environment..."
    
    # Generate JWT secret
    local jwt_secret=$(openssl rand -base64 32)
    
    # Create environment file in the correct location
    sudo tee /opt/billing/web/backend/.env > /dev/null <<EOF
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

# Asterisk Configuration (for future use)
ASTERISK_HOST=localhost
ASTERISK_PORT=5038
ASTERISK_USERNAME=admin
ASTERISK_SECRET=
EOF

    # Set proper permissions
    sudo chmod 600 /opt/billing/web/backend/.env
    sudo chown $USER:$USER /opt/billing/web/backend/.env
    
    print_status "Backend environment configured"
}

start_backend_service() {
    print_status "Starting backend service..."
    
    # Stop any existing service
    sudo systemctl stop ibilling-backend 2>/dev/null || true
    
    # Start the service
    sudo systemctl start ibilling-backend
    
    # Wait a moment and check if service started successfully
    sleep 5
    
    if sudo systemctl is-active --quiet ibilling-backend; then
        print_status "✓ Backend service started successfully"
        
        # Test the API endpoint
        sleep 3
        if curl -s http://localhost:3001/health > /dev/null; then
            print_status "✓ Backend API is responding"
        else
            print_warning "⚠ Backend service is running but API not responding yet"
        fi
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
