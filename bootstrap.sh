
#!/bin/bash

# iBilling Bootstrap Script
# This script clones the repository and runs the installation

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to generate random password
generate_password() {
    openssl rand -base64 16 | tr -d "=+/" | cut -c1-12
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root"
    exit 1
fi

# Generate random passwords if not provided
if [ $# -eq 0 ]; then
    print_status "No passwords provided, generating random passwords..."
    MYSQL_ROOT_PASSWORD=$(generate_password)
    ASTERISK_DB_PASSWORD=$(generate_password)
    print_status "Generated MySQL root password: $MYSQL_ROOT_PASSWORD"
    print_status "Generated Asterisk DB password: $ASTERISK_DB_PASSWORD"
    print_status "Please save these passwords securely!"
elif [ $# -eq 1 ]; then
    ASTERISK_DB_PASSWORD=$1
    print_status "Using provided Asterisk DB password"
elif [ $# -eq 2 ]; then
    MYSQL_ROOT_PASSWORD=$1
    ASTERISK_DB_PASSWORD=$2
    print_status "Using provided passwords"
else
    echo "Usage: $0 [mysql_root_password] [asterisk_db_password]"
    echo "   or: $0 [asterisk_db_password] (if MySQL is already configured)"
    echo "   or: $0 (to generate random passwords)"
    exit 1
fi

# GitHub repository URL
REPO_URL="https://github.com/alffiegeorge/vox-charge-nexus-79095031.git"

# Setup directories
print_status "Setting up directories..."
sudo mkdir -p /opt/billing
cd /opt/billing

# Remove existing installation if any
if [ -d "web" ]; then
    print_status "Removing existing installation..."
    sudo rm -rf web
fi

# Clone the repository
print_status "Cloning iBilling repository..."
if sudo git clone "$REPO_URL" web; then
    print_status "Repository cloned successfully"
else
    print_error "Failed to clone repository"
    exit 1
fi

# Change to the repository directory
cd web

# Set permissions for the current user
current_user=$(whoami)
sudo chown -R "$current_user:$current_user" /opt/billing/web

# Make scripts executable
print_status "Making scripts executable..."
chmod +x scripts/*.sh 2>/dev/null || true
chmod +x install.sh 2>/dev/null || true

# Install system packages
print_status "Installing system packages..."
sudo apt update
sudo apt install -y wget mariadb-client net-tools vim git locales

# Install Node.js if not present
if ! command -v node >/dev/null 2>&1; then
    print_status "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt install -y nodejs
fi

# Install backend dependencies BEFORE running the main installation
print_status "Installing backend dependencies..."
if [ -d "backend" ]; then
    cd backend
    if [ -f "package.json" ]; then
        npm install
        print_status "✓ Backend dependencies installed"
    else
        print_warning "No package.json found in backend directory"
    fi
    cd ..
else
    print_warning "Backend directory not found"
fi

# Install frontend dependencies
print_status "Installing frontend dependencies..."
if [ -f "package.json" ]; then
    npm install
    print_status "✓ Frontend dependencies installed"
else
    print_warning "No package.json found in root directory"
fi

# Run the installation script
print_status "Starting iBilling installation..."
if [ -n "$MYSQL_ROOT_PASSWORD" ] && [ -n "$ASTERISK_DB_PASSWORD" ]; then
    ./install.sh "$MYSQL_ROOT_PASSWORD" "$ASTERISK_DB_PASSWORD"
elif [ -n "$ASTERISK_DB_PASSWORD" ]; then
    ./install.sh "$ASTERISK_DB_PASSWORD"
else
    print_error "No passwords provided to installation script"
    exit 1
fi

# Check installation result
if [ $? -eq 0 ]; then
    print_status "iBilling core installation completed successfully!"
    
    # Build the project
    print_status "Building the project..."
    if npm run build; then
        print_status "Project built successfully"
    else
        print_error "Failed to build project"
        exit 1
    fi
    
    # Setup backend environment with correct database password
    print_status "Configuring backend environment..."
    
    # Generate JWT secret
    local jwt_secret=$(openssl rand -base64 32)
    
    # Create/update backend environment file
    sudo tee /opt/billing/web/backend/.env > /dev/null <<EOL
# Database Configuration
DB_HOST=localhost
DB_PORT=3306
DB_NAME=asterisk
DB_USER=asterisk
DB_PASSWORD=${ASTERISK_DB_PASSWORD}

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
    sudo chmod 600 /opt/billing/web/backend/.env
    sudo chown "$current_user:$current_user" /opt/billing/web/backend/.env
    
    # Update systemd service to use correct working directory
    print_status "Updating systemd service..."
    sudo tee /etc/systemd/system/ibilling-backend.service > /dev/null <<EOL
[Unit]
Description=iBilling Backend API Server
After=network.target mysql.service

[Service]
Type=simple
User=$current_user
WorkingDirectory=/opt/billing/web/backend
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
EnvironmentFile=/opt/billing/web/backend/.env

[Install]
WantedBy=multi-user.target
EOL

    # Reload systemd
    sudo systemctl daemon-reload
    
    # Setup Nginx
    print_status "Configuring Nginx..."
    
    # Install Nginx if not present
    sudo apt install -y nginx
    
    # Clean existing Nginx configurations
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo rm -f /etc/nginx/sites-enabled/ibilling
    sudo rm -f /etc/nginx/sites-available/ibilling
    
    # Create Nginx configuration
    sudo tee /etc/nginx/sites-available/ibilling > /dev/null <<EOL
server {
    listen 80;
    server_name _;
    
    root /opt/billing/web/dist;
    index index.html;
    
    # Frontend static files
    location / {
        try_files \$uri \$uri/ /index.html;
    }
    
    # API proxy to backend
    location /api/ {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # Auth routes
    location /auth/ {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # Health check
    location /health {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

    # Enable the site
    sudo ln -sf /etc/nginx/sites-available/ibilling /etc/nginx/sites-enabled/

    # Test and reload Nginx
    if sudo nginx -t; then
        print_status "Nginx configuration test passed"
        sudo systemctl enable nginx
        sudo systemctl reload nginx
        print_status "Nginx reloaded successfully"
    else
        print_error "Nginx configuration test failed"
        exit 1
    fi
    
    # Start the backend service
    print_status "Starting backend service..."
    sudo systemctl enable ibilling-backend
    sudo systemctl restart ibilling-backend
    
    # Wait for service to start
    sleep 5
    
    # Check service status
    if sudo systemctl is-active --quiet ibilling-backend; then
        print_status "✓ Backend service is running"
    else
        print_error "✗ Backend service failed to start"
        print_status "Checking service logs..."
        sudo journalctl -u ibilling-backend --no-pager -n 20
    fi
    
    print_status ""
    print_status "=== INSTALLATION COMPLETED SUCCESSFULLY ==="
    if [ -n "$MYSQL_ROOT_PASSWORD" ]; then
        print_status "MySQL root password: $MYSQL_ROOT_PASSWORD"
    fi
    print_status "Asterisk DB password: $ASTERISK_DB_PASSWORD"
    print_status "Please save these passwords securely!"
    print_status ""
    print_status "Installation location: /opt/billing/web"
    print_status ""
    print_status "Next steps:"
    print_status "1. Access the web interface at http://172.31.10.10"
    print_status "2. Login with admin/admin123"
    print_status ""
    print_status "For troubleshooting, check:"
    print_status "- Backend service: sudo systemctl status ibilling-backend"
    print_status "- Backend logs: sudo journalctl -u ibilling-backend -f"
    print_status "- Nginx status: sudo systemctl status nginx"
    print_status "- Database: mysql -u asterisk -p"
else
    print_error "Installation failed. Check the logs above for details."
    exit 1
fi

print_status "Bootstrap completed successfully!"
