
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
    
    # Install npm dependencies
    print_status "Installing npm dependencies..."
    if npm install; then
        print_status "Dependencies installed successfully"
    else
        print_error "Failed to install dependencies"
        exit 1
    fi

    # Build the project
    print_status "Building the project..."
    if npm run build; then
        print_status "Project built successfully"
    else
        print_error "Failed to build project"
        exit 1
    fi
    
    # Setup Nginx
    print_status "Configuring Nginx..."
    
    # Install Nginx if not present
    sudo apt install -y nginx
    
    # Clean existing Nginx configurations
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo rm -f /etc/nginx/sites-enabled/ibilling
    sudo rm -f /etc/nginx/sites-available/ibilling
    
    # Copy Nginx configuration
    if [ -f "config/nginx-ibilling.conf" ]; then
        sudo cp "config/nginx-ibilling.conf" /etc/nginx/sites-available/ibilling
        print_status "Nginx configuration copied"
    else
        print_error "Nginx configuration file not found"
        exit 1
    fi

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
    print_status "1. Start the backend service: sudo systemctl start ibilling-backend"
    print_status "2. Access the web interface at http://your-server-ip"
    print_status ""
    print_status "For troubleshooting, check:"
    print_status "- Asterisk status: sudo systemctl status asterisk"
    print_status "- Backend logs: sudo journalctl -u ibilling-backend -f"
    print_status "- Nginx status: sudo systemctl status nginx"
    print_status "- Node.js version: node --version"
else
    print_error "Installation failed. Check the logs above for details."
    exit 1
fi

print_status "Bootstrap completed successfully!"
