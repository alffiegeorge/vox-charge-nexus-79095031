
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
print_status "Creating simplified installation script..."
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
    local jwt_secret=$(openssl rand -base64 32)
    
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
    print_status ""
    print_status "Next steps:"
    print_status "1. Set up the web frontend with: scripts/setup-web.sh"
    print_status "2. Configure your first customer endpoints"
    print_status "3. Test the installation with the verification commands"
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
    
    # Setup web components
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
    
    # Setup backend if scripts are available
    if [ -f "scripts/setup-web.sh" ]; then
        print_status "Running web setup script..."
        sudo chmod +x scripts/setup-web.sh
        sudo ./scripts/setup-web.sh
    else
        print_status "Setting up basic web environment..."
        
        # Setup basic Nginx configuration
        sudo apt install -y nginx
        
        # Create a basic index.html
        sudo tee /var/www/html/index.html > /dev/null <<'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>iBilling System</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 800px; margin: 0 auto; }
        .status { padding: 20px; background: #f0f0f0; border-radius: 5px; margin: 20px 0; }
        .success { background: #d4edda; color: #155724; }
        .warning { background: #fff3cd; color: #856404; }
    </style>
</head>
<body>
    <div class="container">
        <h1>iBilling System - Installation Complete</h1>
        <div class="status success">
            <h3>✓ System Status</h3>
            <p>The iBilling system has been successfully installed with Asterisk 22 and ODBC support.</p>
        </div>
        
        <div class="status warning">
            <h3>⚠ Next Steps Required</h3>
            <ul>
                <li>Configure backend settings in <code>/opt/billing/backend/.env</code></li>
                <li>Install and configure the React frontend</li>
                <li>Start the backend service: <code>sudo systemctl start ibilling-backend</code></li>
            </ul>
        </div>
        
        <div class="status">
            <h3>System Information</h3>
            <p><strong>MySQL Root Password:</strong> Please check installation logs</p>
            <p><strong>Asterisk DB Password:</strong> Please check installation logs</p>
            <p><strong>Asterisk Status:</strong> <code>sudo systemctl status asterisk</code></p>
            <p><strong>ODBC Status:</strong> <code>sudo asterisk -rx 'odbc show all'</code></p>
        </div>
        
        <div class="status">
            <h3>Manual Frontend Setup</h3>
            <p>To complete the React frontend setup, run:</p>
            <pre>
cd /opt/billing/web
sudo git clone https://github.com/alffiegeorge/vox-charge-nexus-79095031.git .
sudo chown -R $USER:$USER /opt/billing/web
npm install
npm run build
            </pre>
        </div>
    </div>
</body>
</html>
HTML
        
        # Start and enable Nginx
        sudo systemctl enable nginx
        sudo systemctl start nginx
        
        print_status "Basic web server configured at http://your-server-ip"
    fi
    
    print_status ""
    print_status "=== IMPORTANT INFORMATION ==="
    if [ -n "$MYSQL_ROOT_PASSWORD" ]; then
        print_status "MySQL root password: $MYSQL_ROOT_PASSWORD"
    fi
    print_status "Asterisk DB password: $ASTERISK_DB_PASSWORD"
    print_status "Please save these passwords securely!"
    print_status ""
    print_status "Next steps:"
    print_status "1. Configure your backend settings in /opt/billing/backend/.env"
    print_status "2. Complete frontend setup if not automated:"
    print_status "   cd /opt/billing/web"
    print_status "   sudo git clone https://github.com/alffiegeorge/vox-charge-nexus-79095031.git ."
    print_status "   sudo chown -R \$USER:\$USER /opt/billing/web"
    print_status "   npm install && npm run build"
    print_status "3. Start the backend service: sudo systemctl start ibilling-backend"
    print_status "4. Access the web interface at http://your-server-ip"
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
