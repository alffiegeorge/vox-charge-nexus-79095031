
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

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root"
    exit 1
fi

# Get script arguments
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

# GitHub repository URL (adjust this to your actual repository)
REPO_URL="https://raw.githubusercontent.com/your-username/ibilling/main"

# Create temporary directory for downloads
TEMP_DIR="/tmp/ibilling-setup"
sudo rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

print_status "Downloading iBilling installation files..."

# Download all necessary files
download_file() {
    local file_path=$1
    local url="${REPO_URL}/${file_path}"
    
    print_status "Downloading ${file_path}..."
    if ! wget -q "$url" -O "$file_path"; then
        print_error "Failed to download ${file_path}"
        return 1
    fi
    
    # Create directory structure if needed
    local dir=$(dirname "$file_path")
    if [ "$dir" != "." ]; then
        mkdir -p "$dir"
        mv "$(basename "$file_path")" "$file_path"
    fi
    
    return 0
}

# List of files to download
files_to_download=(
    "scripts/utils.sh"
    "scripts/debug-asterisk.sh"
    "scripts/test-realtime.sh"
    "scripts/setup-database.sh"
    "scripts/setup-odbc.sh"
    "scripts/setup-web.sh"
    "scripts/make-executable.sh"
    "config/res_odbc.conf"
    "config/cdr_adaptive_odbc.conf"
    "config/extconfig.conf"
    "config/extensions.conf"
    "config/pjsip.conf"
    "config/odbcinst.ini"
    "config/odbc.ini.template"
    "config/database-schema.sql"
    "config/nginx-ibilling.conf"
    "backend/.env.example"
    "install.sh"
)

# Download all files
failed_downloads=()
for file in "${files_to_download[@]}"; do
    if ! download_file "$file"; then
        failed_downloads+=("$file")
    fi
done

# Check if any downloads failed
if [ ${#failed_downloads[@]} -gt 0 ]; then
    print_error "Failed to download the following files:"
    for file in "${failed_downloads[@]}"; do
        echo "  - $file"
    done
    print_error "Please check your internet connection and repository URL"
    exit 1
fi

print_status "All files downloaded successfully"

# Make scripts executable
chmod +x scripts/*.sh
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
