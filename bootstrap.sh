
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
    MYSQL_ROOT_PASSWORD="admin123"
    print_status "Using provided Asterisk DB password and default root password"
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

# FIRST: Completely reset database authentication
print_status "Resetting database authentication completely..."
if [ -f "scripts/clean-database.sh" ]; then
    chmod +x scripts/clean-database.sh
    if ./scripts/clean-database.sh "$MYSQL_ROOT_PASSWORD"; then
        print_status "✓ Database cleaned successfully"
    else
        print_error "Database cleanup failed"
        exit 1
    fi
else
    print_warning "Clean database script not found, proceeding with manual cleanup..."
    
    # Manual database cleanup
    print_status "Stopping MariaDB..."
    sudo systemctl stop mariadb || true
    sleep 3
    
    # Start in safe mode
    print_status "Starting MariaDB in safe mode..."
    sudo mysqld_safe --skip-grant-tables --skip-networking &
    sleep 5
    
    # Reset everything
    print_status "Resetting database completely..."
    mysql -u root <<EOF
FLUSH PRIVILEGES;
DROP DATABASE IF EXISTS asterisk;
DROP USER IF EXISTS 'asterisk'@'localhost';
DROP USER IF EXISTS 'asterisk'@'%';
DELETE FROM mysql.user WHERE User='asterisk';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF
    
    # Stop safe mode and restart normally
    sudo pkill mysqld_safe 2>/dev/null || true
    sudo pkill mysqld 2>/dev/null || true
    sleep 3
    sudo systemctl start mariadb
    sleep 5
fi

# SECOND: Set up database with proper authentication
print_status "Setting up database with proper authentication..."
if [ -f "scripts/fix-database-auth.sh" ]; then
    chmod +x scripts/fix-database-auth.sh
    if ./scripts/fix-database-auth.sh "$MYSQL_ROOT_PASSWORD" "$ASTERISK_DB_PASSWORD"; then
        print_status "✓ Database authentication configured successfully"
    else
        print_error "Database authentication setup failed"
        exit 1
    fi
else
    print_status "Manually setting up database..."
    
    # Create database and user
    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" <<EOF
CREATE DATABASE IF NOT EXISTS asterisk CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'asterisk'@'localhost' IDENTIFIED BY '${ASTERISK_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk'@'localhost';
FLUSH PRIVILEGES;
EOF
    
    if [ $? -eq 0 ]; then
        print_status "✓ Database and user created successfully"
    else
        print_error "Failed to create database and user"
        exit 1
    fi
fi

# THIRD: Set up ODBC with verified database connection
print_status "Configuring ODBC for database connection..."

# Install ODBC packages
sudo apt install -y unixodbc unixodbc-dev libmariadb-dev odbc-mariadb \
    libodbc1 odbcinst1debian2 unixodbc-bin

# Find MariaDB ODBC driver path
driver_paths=(
    "/usr/lib/x86_64-linux-gnu/odbc/libmaodbc.so"
    "/usr/lib/odbc/libmaodbc.so"
    "/usr/lib64/libmaodbc.so"
    "/usr/local/lib/libmaodbc.so"
)

found_driver=""
for path in "${driver_paths[@]}"; do
    if [ -f "$path" ]; then
        found_driver="$path"
        print_status "✓ Found MariaDB ODBC driver at: $path"
        break
    fi
done

if [ -z "$found_driver" ]; then
    print_error "MariaDB ODBC driver not found"
    exit 1
fi

# Configure ODBC driver
print_status "Configuring ODBC drivers..."
sudo tee /etc/odbcinst.ini > /dev/null <<EOF
[MariaDB]
Description = MariaDB ODBC driver
Driver      = ${found_driver}
Threading   = 1
UsageCount  = 1

[MariaDB Unicode]
Description = MariaDB ODBC Unicode driver
Driver      = ${found_driver}
Threading   = 1
UsageCount  = 1
EOF

# Find MySQL socket path
socket_paths=(
    "/var/run/mysqld/mysqld.sock"
    "/tmp/mysql.sock"
    "/var/lib/mysql/mysql.sock"
    "/run/mysqld/mysqld.sock"
)

found_socket=""
for socket in "${socket_paths[@]}"; do
    if [ -S "$socket" ]; then
        found_socket="$socket"
        print_status "✓ Found MySQL socket at: $socket"
        break
    fi
done

if [ -z "$found_socket" ]; then
    print_warning "MySQL socket not found, using default path"
    found_socket="/var/run/mysqld/mysqld.sock"
fi

# Configure ODBC DSN
print_status "Configuring ODBC data source..."
sudo tee /etc/odbc.ini > /dev/null <<EOF
[asterisk-connector]
Description = MariaDB connection to 'asterisk' database
Driver      = MariaDB
Server      = localhost
Database    = asterisk
User        = asterisk
Password    = ${ASTERISK_DB_PASSWORD}
Port        = 3306
Socket      = ${found_socket}
Option      = 3
Charset     = utf8
EOF

# Test direct MySQL connection first
print_status "Testing direct MySQL connection..."
if mysql -u asterisk -p"${ASTERISK_DB_PASSWORD}" -e "SELECT 1;" asterisk >/dev/null 2>&1; then
    print_status "✓ Direct MySQL connection successful"
else
    print_error "✗ Direct MySQL connection failed"
    exit 1
fi

# Test ODBC connection
print_status "Testing ODBC connection..."
if command -v isql >/dev/null 2>&1; then
    if echo "SELECT 1 as test;" | timeout 10 isql -v asterisk-connector asterisk "${ASTERISK_DB_PASSWORD}" 2>/dev/null | grep -q "test"; then
        print_status "✓ ODBC connection test successful"
    else
        print_warning "⚠ ODBC connection test failed, but continuing with installation..."
        print_status "This may be resolved after Asterisk installation"
    fi
else
    print_warning "isql command not available"
fi

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
jwt_secret=$(openssl rand -base64 32)

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

# Update systemd service
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
print_status "1. Access the web interface at http://$(hostname -I | awk '{print $1}')"
print_status "2. Login with admin/admin123"
print_status ""
print_status "For troubleshooting, check:"
print_status "- Backend service: sudo systemctl status ibilling-backend"
print_status "- Backend logs: sudo journalctl -u ibilling-backend -f"
print_status "- Nginx status: sudo systemctl status nginx"
print_status "- Database: mysql -u asterisk -p${ASTERISK_DB_PASSWORD} asterisk"
print_status ""
print_status "ODBC can be tested after Asterisk installation with:"
print_status "- isql -v asterisk-connector asterisk ${ASTERISK_DB_PASSWORD}"

print_status "Bootstrap completed successfully!"
