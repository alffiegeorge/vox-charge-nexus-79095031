
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

# List of files to download (only files that exist in the repository)
files_to_download=(
    "install.sh"
    "scripts/utils.sh"
    "scripts/debug-asterisk.sh"
    "scripts/setup-database.sh"
    "scripts/setup-web.sh"
    "config/res_odbc.conf"
    "config/cdr_adaptive_odbc.conf"
    "config/extconfig.conf"
    "config/extensions.conf"
    "config/pjsip.conf"
    "config/odbcinst.ini"
    "config/odbc.ini.template"
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

# Check if install.sh was downloaded successfully
if [ ! -f "install.sh" ]; then
    print_error "Critical file install.sh not found. Cannot continue."
    exit 1
fi

print_status "Essential files downloaded successfully"

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
    print_status "2. Start the backend service: sudo systemctl start ibilling-backend"
    print_status "3. Access the web interface at http://your-server-ip"
    print_status ""
    print_status "For troubleshooting, check:"
    print_status "- Asterisk status: sudo systemctl status asterisk"
    print_status "- Backend logs: sudo journalctl -u ibilling-backend -f"
    print_status "- Nginx status: sudo systemctl status nginx"
else
    print_error "Installation failed. Check the logs above for details."
    exit 1
fi

# Clean up temporary files
cd ~
sudo rm -rf "$TEMP_DIR"

print_status "Bootstrap completed successfully!"
