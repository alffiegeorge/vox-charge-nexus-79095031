
#!/bin/bash

# iBilling Bootstrap Script
# This script downloads all necessary files and runs the installation

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

# GitHub repository URL - using the actual repository
REPO_URL="https://raw.githubusercontent.com/alffiegeorge/vox-charge-nexus-79095031/refs/heads/main"

# Create temporary directory for downloads
TEMP_DIR="/tmp/ibilling-setup"
sudo rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

print_status "Downloading iBilling installation files..."

# Download file function with proper directory handling
download_file() {
    local file_path=$1
    local url="${REPO_URL}/${file_path}"
    local dir=$(dirname "$file_path")
    
    # Create directory structure if needed
    if [ "$dir" != "." ]; then
        mkdir -p "$dir"
    fi
    
    print_status "Downloading ${file_path}..."
    if wget -q "$url" -O "$file_path"; then
        return 0
    else
        print_error "Failed to download ${file_path} from ${url}"
        return 1
    fi
}

# List of files to download that actually exist in the repository
files_to_download=(
    "scripts/utils.sh"
    "scripts/debug-asterisk.sh"
    "scripts/setup-database.sh"
    "scripts/setup-web.sh"
    "scripts/install-asterisk.sh"
    "scripts/setup-odbc.sh"
    "config/res_odbc.conf"
    "config/cdr_adaptive_odbc.conf"
    "config/extconfig.conf"
    "config/extensions.conf"
    "config/pjsip.conf"
    "config/odbcinst.ini"
    "config/odbc.ini.template"
    "config/nginx-ibilling.conf"
    "backend/.env.example"
)

# Download all files
failed_downloads=()
for file in "${files_to_download[@]}"; do
    if ! download_file "$file"; then
        failed_downloads+=("$file")
    fi
done

# Check if any critical downloads failed
if [ ${#failed_downloads[@]} -gt 0 ]; then
    print_warning "Some files failed to download:"
    for file in "${failed_downloads[@]}"; do
        echo "  - $file"
    done
    print_status "Continuing with available files..."
fi

# Create a simplified install.sh that uses existing scripts
print_status "Creating installation script..."
cat > install.sh << 'EOF'
#!/bin/bash

# iBilling installation main script
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
    
    # Setup ODBC
    if [ -f "scripts/setup-odbc.sh" ]; then
        chmod +x scripts/setup-odbc.sh
        ./scripts/setup-odbc.sh "$ASTERISK_DB_PASSWORD"
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
    print_status "Setting up backend service..."
    sudo mkdir -p /opt/billing
    
    # Generate JWT secret
    jwt_secret=$(openssl rand -base64 32)
    
    # Create environment file
    sudo tee /opt/billing/.env > /dev/null <<EOL
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
    
    print_status "iBilling installation completed successfully!"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
EOF

# Make scripts executable
if [ -d "scripts" ]; then
    chmod +x scripts/*.sh 2>/dev/null || true
fi
chmod +x install.sh

print_status "Starting iBilling installation..."

# Run the main installation script
if [ -n "$MYSQL_ROOT_PASSWORD" ] && [ -n "$ASTERISK_DB_PASSWORD" ]; then
    ./install.sh "$MYSQL_ROOT_PASSWORD" "$ASTERISK_DB_PASSWORD"
elif [ -n "$ASTERISK_DB_PASSWORD" ]; then
    ./install.sh "$ASTERISK_DB_PASSWORD"
fi

# Check installation result
if [ $? -eq 0 ]; then
    print_status "iBilling installation completed successfully!"
    
    # Setup web components manually since setup-web.sh has issues
    print_status "Setting up web frontend and Node.js..."
    
    # Create necessary directories
    sudo mkdir -p /opt/billing/web
    sudo mkdir -p /opt/billing/backend
    
    # Install Node.js if not present
    if ! command -v node >/dev/null 2>&1; then
        print_status "Installing Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt install -y nodejs
    fi
    
    # Manual web setup instead of using problematic script
    print_status "Setting up iBilling frontend manually..."
    
    # Create web directory if it doesn't exist
    sudo mkdir -p /opt/billing/web
    cd /opt/billing/web

    # Remove existing files if any
    sudo rm -rf ./* 2>/dev/null || true
    sudo rm -rf ./.* 2>/dev/null || true

    # Clone the repository
    print_status "Cloning repository..."
    if sudo git clone https://github.com/alffiegeorge/vox-charge-nexus-79095031.git .; then
        print_status "Repository cloned successfully"
    else
        print_error "Failed to clone repository"
        exit 1
    fi

    # Set permissions for the current user
    current_user=$(whoami)
    sudo chown -R "$current_user:$current_user" /opt/billing/web

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
    sudo apt update
    sudo apt install -y nginx
    
    # Clean existing Nginx configurations
    print_status "Cleaning existing Nginx configurations..."
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo rm -f /etc/nginx/sites-enabled/ibilling
    sudo rm -f /etc/nginx/sites-available/ibilling
    
    # Copy Nginx configuration from the downloaded files
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

# Clean up temporary files
cd ~
sudo rm -rf "$TEMP_DIR"

print_status "Bootstrap completed successfully!"
