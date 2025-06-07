
#!/bin/bash

# Utility functions for iBilling installation

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
    openssl rand -base64 32
}

# Function to check if service is running
check_service() {
    local service_name=$1
    if sudo systemctl is-active --quiet "$service_name"; then
        print_status "✓ $service_name is running"
        return 0
    else
        print_error "✗ $service_name is not running"
        return 1
    fi
}

# Function to create directory with permissions
create_directory() {
    local dir_path=$1
    local owner=${2:-$USER:$USER}
    
    sudo mkdir -p "$dir_path"
    if [ "$owner" != "root:root" ]; then
        sudo chown -R "$owner" "$dir_path"
    fi
    print_status "Created directory: $dir_path"
}

# Function to backup file if it exists
backup_file() {
    local file_path=$1
    local backup_dir=${2:-/etc/asterisk/backup}
    
    if [ -f "$file_path" ]; then
        sudo mkdir -p "$backup_dir"
        sudo cp "$file_path" "$backup_dir/$(basename $file_path).orig" 2>/dev/null || true
        print_status "Backed up: $file_path"
    fi
}
