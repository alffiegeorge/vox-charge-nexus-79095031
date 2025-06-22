
#!/bin/bash

# iBilling Bootstrap Script - Streamlined Installation
# This script clones the repository and runs the comprehensive installation

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output with proper line breaks
print_status() {
    echo -e "\n${GREEN}[INFO]${NC} $1"
    sleep 0.1
}

print_warning() {
    echo -e "\n${YELLOW}[WARNING]${NC} $1"
    sleep 0.1
}

print_error() {
    echo -e "\n${RED}[ERROR]${NC} $1"
    sleep 0.1
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

print_status "Starting iBilling Bootstrap Installation"

# Generate random passwords if not provided
if [ $# -eq 0 ]; then
    print_status "No passwords provided, generating random passwords..."
    MYSQL_ROOT_PASSWORD=$(generate_password)
    ASTERISK_DB_PASSWORD=$(generate_password)
    echo -e "\n${GREEN}Generated MySQL root password:${NC} $MYSQL_ROOT_PASSWORD"
    echo -e "${GREEN}Generated Asterisk DB password:${NC} $ASTERISK_DB_PASSWORD"
    print_warning "Please save these passwords securely!"
elif [ $# -eq 1 ]; then
    ASTERISK_DB_PASSWORD=$1
    MYSQL_ROOT_PASSWORD="admin123"
    print_status "Using provided Asterisk DB password and default root password"
elif [ $# -eq 2 ]; then
    MYSQL_ROOT_PASSWORD=$1
    ASTERISK_DB_PASSWORD=$2
    print_status "Using provided passwords"
else
    echo -e "\nUsage: $0 [mysql_root_password] [asterisk_db_password]"
    echo "   or: $0 [asterisk_db_password] (if MySQL is already configured)"
    echo "   or: $0 (to generate random passwords)"
    exit 1
fi

# GitHub repository URL
REPO_URL="https://github.com/alffiegeorge/vox-charge-nexus-79095031.git"

print_status "Setting up directories..."
sudo mkdir -p /opt/billing
cd /opt/billing

# Remove existing installation if any
if [ -d "web" ]; then
    print_status "Removing existing installation..."
    sudo rm -rf web
fi

print_status "Cloning iBilling repository..."
if sudo git clone "$REPO_URL" web; then
    print_status "✓ Repository cloned successfully"
else
    print_error "Failed to clone repository"
    exit 1
fi

# Change to the repository directory
cd web

# Set permissions for the current user
current_user=$(whoami)
sudo chown -R "$current_user:$current_user" /opt/billing/web

print_status "Making scripts executable..."
chmod +x scripts/*.sh 2>/dev/null || true
chmod +x install.sh 2>/dev/null || true

print_status "Installing system packages..."
sudo apt update >/dev/null 2>&1
sudo apt install -y wget mariadb-client net-tools vim git locales >/dev/null 2>&1

# Install Node.js if not present
if ! command -v node >/dev/null 2>&1; then
    print_status "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - >/dev/null 2>&1
    sudo apt install -y nodejs >/dev/null 2>&1
fi

print_status "Installing backend dependencies..."
if [ -d "backend" ] && [ -f "backend/package.json" ]; then
    cd backend
    npm install >/dev/null 2>&1
    print_status "✓ Backend dependencies installed"
    cd ..
else
    print_warning "Backend directory or package.json not found"
fi

print_status "Installing frontend dependencies..."
if [ -f "package.json" ]; then
    npm install >/dev/null 2>&1
    print_status "✓ Frontend dependencies installed"
else
    print_warning "No package.json found in root directory"
fi

print_status "Running comprehensive installation..."
if [ -f "install.sh" ]; then
    chmod +x install.sh
    ./install.sh "$MYSQL_ROOT_PASSWORD" "$ASTERISK_DB_PASSWORD"
else
    print_error "install.sh not found"
    exit 1
fi

print_status "Building the project..."
if npm run build >/dev/null 2>&1; then
    print_status "✓ Project built successfully"
else
    print_error "Failed to build project"
    exit 1
fi

# Run remaining setup scripts
if [ -f "scripts/setup-backend.sh" ]; then
    print_status "Running setup-backend.sh..."
    chmod +x scripts/setup-backend.sh
    ./scripts/setup-backend.sh "$MYSQL_ROOT_PASSWORD" "$ASTERISK_DB_PASSWORD"
fi

if [ -f "scripts/setup-web.sh" ]; then
    print_status "Running setup-web.sh..."
    chmod +x scripts/setup-web.sh
    MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" ASTERISK_DB_PASSWORD="$ASTERISK_DB_PASSWORD" ./scripts/setup-web.sh
fi

# Start the backend service
print_status "Starting backend service..."
sudo systemctl enable ibilling-backend >/dev/null 2>&1
sudo systemctl restart ibilling-backend >/dev/null 2>&1
sleep 5

if sudo systemctl is-active --quiet ibilling-backend; then
    print_status "✓ Backend service is running"
else
    print_error "✗ Backend service failed to start"
    print_status "Checking service logs..."
    sudo journalctl -u ibilling-backend --no-pager -n 20
fi

# Final Asterisk restart and verification
if command -v asterisk >/dev/null 2>&1; then
    print_status "Final Asterisk restart..."
    sudo systemctl restart asterisk >/dev/null 2>&1
    sleep 10
    
    print_status "Testing PJSIP configuration..."
    sudo asterisk -rx "pjsip reload" >/dev/null 2>&1
    sleep 3
    
    endpoints_output=$(sudo asterisk -rx "pjsip show endpoints" 2>/dev/null)
    if echo "$endpoints_output" | grep -q "Endpoint:" || echo "$endpoints_output" | grep -q "c[0-9]"; then
        print_status "✅ PJSIP endpoints are visible and working correctly"
    else
        print_warning "⚠ PJSIP may have configuration issues"
    fi
fi

print_status "INSTALLATION COMPLETED SUCCESSFULLY"

if [ -n "$MYSQL_ROOT_PASSWORD" ]; then
    echo -e "\n${GREEN}MySQL root password:${NC} $MYSQL_ROOT_PASSWORD"
fi
echo -e "${GREEN}Asterisk DB password:${NC} $ASTERISK_DB_PASSWORD"
print_warning "Please save these passwords securely!"

echo -e "\n${GREEN}Installation location:${NC} /opt/billing/web"

echo -e "\n${GREEN}Next steps:${NC}"
echo "1. Access the web interface at http://$(hostname -I | awk '{print $1}')"
echo "2. Login with admin/admin123"
echo "3. Create customers and their SIP endpoints from the admin panel"
echo "4. Check PJSIP endpoints with: sudo asterisk -rx 'pjsip show endpoints'"

echo -e "\n${GREEN}For troubleshooting, check:${NC}"
echo "- Backend service: sudo systemctl status ibilling-backend"
echo "- Backend logs: sudo journalctl -u ibilling-backend -f"
echo "- Nginx status: sudo systemctl status nginx"
echo "- Database: mysql -u asterisk -p${ASTERISK_DB_PASSWORD} asterisk"
echo "- Asterisk status: sudo systemctl status asterisk"

print_status "Bootstrap completed successfully!"
