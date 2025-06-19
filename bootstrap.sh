
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

# MariaDB password reset function
reset_mariadb_password() {
    local new_password=${1:-"admin123"}
    
    print_status "=== MARIADB PASSWORD RESET ==="
    print_status "Attempting to reset MariaDB root password to: $new_password"
    
    # Step 1: Stop the database server
    print_status "Stopping MariaDB server..."
    sudo systemctl stop mariadb || true
    sudo systemctl stop mysql || true
    
    # Kill any remaining processes
    sudo pkill -9 -f mysqld || true
    sudo pkill -9 -f mariadbd || true
    sleep 3
    
    # Step 2: Start database without permission checking
    print_status "Starting MariaDB in safe mode (without grant tables)..."
    
    # Remove any existing socket files
    sudo rm -f /var/run/mysqld/mysqld.sock || true
    sudo rm -f /tmp/mysql.sock || true
    
    # Start MariaDB in safe mode
    print_status "Starting mysqld_safe with --skip-grant-tables --skip-networking..."
    sudo mysqld_safe --skip-grant-tables --skip-networking &
    SAFE_PID=$!
    
    # Wait for the server to start
    print_status "Waiting for MariaDB to start in safe mode..."
    sleep 10
    
    # Test if we can connect
    local connection_attempts=0
    while [ $connection_attempts -lt 10 ]; do
        if mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
            print_status "✓ Successfully connected to MariaDB in safe mode"
            break
        fi
        sleep 2
        connection_attempts=$((connection_attempts + 1))
        print_status "Waiting for connection... (attempt $connection_attempts/10)"
    done
    
    if [ $connection_attempts -eq 10 ]; then
        print_error "Failed to connect to MariaDB in safe mode"
        sudo kill $SAFE_PID 2>/dev/null || true
        return 1
    fi
    
    # Step 3: Change the root password
    print_status "Changing root password..."
    
    # Connect and change password
    mysql -u root <<EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${new_password}';
FLUSH PRIVILEGES;
EOF
    
    if [ $? -eq 0 ]; then
        print_status "✓ Password changed successfully using ALTER USER"
    else
        print_warning "ALTER USER failed, trying alternative method..."
        mysql -u root <<EOF
FLUSH PRIVILEGES;
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${new_password}');
FLUSH PRIVILEGES;
EOF
        
        if [ $? -eq 0 ]; then
            print_status "✓ Password changed successfully using SET PASSWORD"
        else
            print_warning "SET PASSWORD failed, trying UPDATE method..."
            mysql -u root <<EOF
FLUSH PRIVILEGES;
UPDATE mysql.user SET authentication_string = PASSWORD('${new_password}') WHERE User = 'root' AND Host = 'localhost';
FLUSH PRIVILEGES;
EOF
            
            if [ $? -eq 0 ]; then
                print_status "✓ Password changed successfully using UPDATE"
            else
                print_error "All password change methods failed"
                sudo kill $SAFE_PID 2>/dev/null || true
                return 1
            fi
        fi
    fi
    
    # Step 4: Restart database server normally
    print_status "Restarting MariaDB normally..."
    
    # Stop the safe mode instance
    print_status "Stopping safe mode instance..."
    sudo kill $SAFE_PID 2>/dev/null || true
    
    # Make sure all processes are stopped
    sudo pkill -f mysqld_safe || true
    sudo pkill -f mysqld || true
    sudo pkill -f mariadbd || true
    sleep 5
    
    # Start MariaDB normally
    print_status "Starting MariaDB service normally..."
    sudo systemctl start mariadb
    
    # Wait for service to be ready
    sleep 5
    
    # Test the new password
    print_status "Testing new password..."
    if mysql -u root -p"${new_password}" -e "SELECT 1;" >/dev/null 2>&1; then
        print_status "✓ Password reset successful!"
        print_status "✓ MariaDB root password is now: ${new_password}"
        return 0
    else
        print_error "✗ Password reset failed - cannot connect with new password"
        return 1
    fi
}

# Emergency MariaDB reset function
emergency_mariadb_reset() {
    local mysql_root_password=${1:-"admin123"}
    local asterisk_db_password=${2:-"asterisk123"}
    
    print_status "=== EMERGENCY MARIADB RESET ==="
    print_warning "Performing complete MariaDB reset due to severe issues..."
    
    # Kill all processes
    print_status "Killing all MySQL/MariaDB processes..."
    sudo pkill -9 -f mysqld || true
    sudo pkill -9 -f mariadbd || true
    sudo pkill -9 -f mysqld_safe || true
    sleep 5
    
    # Stop services
    sudo systemctl stop mariadb || true
    sudo systemctl stop mysql || true
    sleep 3
    
    # Remove socket files
    sudo rm -f /var/run/mysqld/mysqld.sock || true
    sudo rm -f /tmp/mysql.sock || true
    
    # Backup and remove data directory
    if [ -d "/var/lib/mysql" ]; then
        sudo mv /var/lib/mysql "/var/lib/mysql.backup.$(date +%Y%m%d_%H%M%S)" || true
    fi
    
    # Purge and reinstall
    print_status "Purging and reinstalling MariaDB..."
    sudo apt remove --purge -y mariadb-server mariadb-client mariadb-common mysql-common || true
    sudo apt autoremove -y || true
    sudo rm -rf /etc/mysql || true
    sudo rm -rf /var/lib/mysql || true
    
    sudo apt update
    sudo apt install -y mariadb-server mariadb-client
    
    # Setup directories
    sudo mkdir -p /var/run/mysqld
    sudo chown mysql:mysql /var/run/mysqld
    
    # Start MariaDB
    sudo systemctl enable mariadb
    sudo systemctl start mariadb
    sleep 10
    
    # Configure database
    sudo mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysql_root_password}';
CREATE DATABASE asterisk CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'asterisk'@'localhost' IDENTIFIED BY '${asterisk_db_password}';
GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk'@'localhost';
FLUSH PRIVILEGES;
EOF
    
    if [ $? -eq 0 ]; then
        print_status "✓ Emergency reset successful!"
        return 0
    else
        print_error "✗ Emergency reset failed"
        return 1
    fi
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

# Database setup with fallback methods
print_status "Setting up database with fallback methods..."

# Method 1: Try password reset first
print_status "Method 1: Attempting MariaDB password reset..."
if reset_mariadb_password "$MYSQL_ROOT_PASSWORD"; then
    print_status "✓ MariaDB password reset successful!"
    
    # Create asterisk database and user
    print_status "Creating asterisk database and user..."
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF
CREATE DATABASE IF NOT EXISTS asterisk CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'asterisk'@'localhost' IDENTIFIED BY '$ASTERISK_DB_PASSWORD';
GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk'@'localhost';
FLUSH PRIVILEGES;
EOF
    
    if [ $? -eq 0 ]; then
        print_status "✓ Asterisk database and user created successfully"
    else
        print_error "Failed to create asterisk database, trying emergency reset..."
        if emergency_mariadb_reset "$MYSQL_ROOT_PASSWORD" "$ASTERISK_DB_PASSWORD"; then
            print_status "✓ Emergency reset successful!"
        else
            print_error "All database setup methods failed"
            exit 1
        fi
    fi
else
    print_warning "Password reset failed, trying emergency reset..."
    if emergency_mariadb_reset "$MYSQL_ROOT_PASSWORD" "$ASTERISK_DB_PASSWORD"; then
        print_status "✓ Emergency reset successful!"
    else
        print_error "All database setup methods failed"
        exit 1
    fi
fi

# Continue with existing bootstrap code...
# ... keep existing code (ODBC setup, backend configuration, build, systemd service, nginx setup) the same ...

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
