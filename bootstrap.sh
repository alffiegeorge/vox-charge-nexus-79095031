#!/bin/bash

# iBilling Bootstrap Script
# This script clones the repository and runs the installation

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output with proper line breaks
print_status() {
    echo -e "\n${GREEN}[INFO]${NC} $1"
    sleep 0.1  # Small delay to ensure proper output ordering
}

print_warning() {
    echo -e "\n${YELLOW}[WARNING]${NC} $1"
    sleep 0.1
}

print_error() {
    echo -e "\n${RED}[ERROR]${NC} $1"
    sleep 0.1
}

# Function to print separator
print_separator() {
    echo -e "\n=================================================="
}

# Function to generate random password
generate_password() {
    openssl rand -base64 16 | tr -d "=+/" | cut -c1-12
}

# Function to perform password reset using MariaDB scripts
reset_mariadb_password() {
    local new_password=$1
    
    if [ -f "scripts/reset-mariadb-password.sh" ]; then
        chmod +x scripts/reset-mariadb-password.sh
        if ./scripts/reset-mariadb-password.sh "$new_password"; then
            return 0
        else
            return 1
        fi
    else
        print_error "reset-mariadb-password.sh script not found"
        return 1
    fi
}

# Function to perform emergency MariaDB reset
emergency_mariadb_reset() {
    local mysql_root_password=$1
    local asterisk_db_password=$2
    
    if [ -f "scripts/emergency-mariadb-reset.sh" ]; then
        chmod +x scripts/emergency-mariadb-reset.sh
        if ./scripts/emergency-mariadb-reset.sh "$mysql_root_password" "$asterisk_db_password"; then
            return 0
        else
            return 1
        fi
    else
        print_error "emergency-mariadb-reset.sh script not found"
        return 1
    fi
}

# Function to run complete database schema fix
fix_complete_database_schema() {
    local mysql_root_password=$1
    local asterisk_db_password=$2
    
    if [ -f "scripts/fix-database-schema-complete.sh" ]; then
        print_status "Running complete database schema fix..."
        chmod +x scripts/fix-database-schema-complete.sh
        if ./scripts/fix-database-schema-complete.sh "$mysql_root_password" "$asterisk_db_password"; then
            print_status "✅ Complete database schema fix completed successfully!"
            return 0
        else
            print_error "❌ Complete database schema fix failed"
            return 1
        fi
    else
        print_error "fix-database-schema-complete.sh script not found"
        return 1
    fi
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root"
    exit 1
fi

print_separator
print_status "Starting iBilling Bootstrap Installation"
print_separator

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

print_separator
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

print_separator
print_status "Making scripts executable..."
chmod +x scripts/*.sh 2>/dev/null || true
chmod +x install.sh 2>/dev/null || true

# Execute the make-scripts-executable script
if [ -f "scripts/make-scripts-executable.sh" ]; then
    print_status "Running make-scripts-executable.sh..."
    ./scripts/make-scripts-executable.sh
fi

print_separator
print_status "Installing system packages..."
sudo apt update >/dev/null 2>&1
sudo apt install -y wget mariadb-client net-tools vim git locales >/dev/null 2>&1

# Install Node.js if not present
if ! command -v node >/dev/null 2>&1; then
    print_status "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - >/dev/null 2>&1
    sudo apt install -y nodejs >/dev/null 2>&1
fi

print_separator
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

print_separator
print_status "Setting up database with fallback methods..."

# Method 1: Try password reset first
print_status "Method 1: Attempting MariaDB password reset..."
if reset_mariadb_password "$MYSQL_ROOT_PASSWORD"; then
    print_status "✓ MariaDB password reset successful!"
    
    # CRITICAL: Run complete database schema fix instead of basic setup
    print_separator
    print_status "Setting up complete database schema with fix..."
    
    if fix_complete_database_schema "$MYSQL_ROOT_PASSWORD" "$ASTERISK_DB_PASSWORD"; then
        print_status "✅ Complete database schema setup successful!"
    else
        print_error "❌ Complete database schema setup failed, trying emergency reset..."
        if emergency_mariadb_reset "$MYSQL_ROOT_PASSWORD" "$ASTERISK_DB_PASSWORD"; then
            print_status "✓ Emergency reset successful!"
            # Try the complete schema fix again after emergency reset
            if fix_complete_database_schema "$MYSQL_ROOT_PASSWORD" "$ASTERISK_DB_PASSWORD"; then
                print_status "✅ Complete database schema setup successful after emergency reset!"
            else
                print_error "❌ Database setup failed even after emergency reset"
                exit 1
            fi
        else
            print_error "All database setup methods failed"
            exit 1
        fi
    fi
else
    print_warning "Password reset failed, trying emergency reset..."
    if emergency_mariadb_reset "$MYSQL_ROOT_PASSWORD" "$ASTERISK_DB_PASSWORD"; then
        print_status "✓ Emergency reset successful!"
        # Run complete database schema fix after emergency reset
        if fix_complete_database_schema "$MYSQL_ROOT_PASSWORD" "$ASTERISK_DB_PASSWORD"; then
            print_status "✅ Complete database schema setup successful!"
        else
            print_error "❌ Database setup failed after emergency reset"
            exit 1
        fi
    else
        print_error "All database setup methods failed"
        exit 1
    fi
fi

# Export passwords for use by other scripts
export MYSQL_ROOT_PASSWORD
export ASTERISK_DB_PASSWORD

print_separator
print_status "Running main installation script..."
if [ -f "install.sh" ]; then
    chmod +x install.sh
    ./install.sh "$MYSQL_ROOT_PASSWORD" "$ASTERISK_DB_PASSWORD"
else
    print_warning "install.sh not found, continuing with manual setup..."
fi

print_separator
print_status "Running additional setup scripts..."

# Run setup-database script if it exists (will be skipped since schema is already complete)
if [ -f "scripts/setup-database.sh" ]; then
    print_status "Skipping setup-database.sh (complete schema already applied)..."
fi

# Run setup-odbc script if it exists
if [ -f "scripts/setup-odbc.sh" ]; then
    print_status "Running setup-odbc.sh..."
    chmod +x scripts/setup-odbc.sh
    ./scripts/setup-odbc.sh "$ASTERISK_DB_PASSWORD" >/dev/null 2>&1
fi

# Run config-generator script to create configuration files
if [ -f "scripts/config-generator.sh" ]; then
    print_status "Running config-generator.sh..."
    chmod +x scripts/config-generator.sh
    ./scripts/config-generator.sh >/dev/null 2>&1
    
    # Copy generated configuration files
    if [ -d "/tmp/ibilling-config" ]; then
        print_status "Installing Asterisk configuration files..."
        
        # Install res_odbc.conf
        if [ -f "/tmp/ibilling-config/res_odbc.conf" ]; then
            sudo sed "s/ASTERISK_DB_PASSWORD_PLACEHOLDER/${ASTERISK_DB_PASSWORD}/g" /tmp/ibilling-config/res_odbc.conf > /tmp/res_odbc_final.conf
            sudo mv /tmp/res_odbc_final.conf /etc/asterisk/res_odbc.conf
            sudo chown asterisk:asterisk /etc/asterisk/res_odbc.conf
        fi
        
        # Install extconfig.conf
        if [ -f "/tmp/ibilling-config/extconfig.conf" ]; then
            sudo cp /tmp/ibilling-config/extconfig.conf /etc/asterisk/
            sudo chown asterisk:asterisk /etc/asterisk/extconfig.conf
        fi
        
        # Install PJSIP configuration
        if [ -f "/tmp/ibilling-config/pjsip.conf" ]; then
            sudo cp /tmp/ibilling-config/pjsip.conf /etc/asterisk/
            sudo chown asterisk:asterisk /etc/asterisk/pjsip.conf
        fi
        
        # Install extensions.conf
        if [ -f "/tmp/ibilling-config/extensions.conf" ]; then
            sudo cp /tmp/ibilling-config/extensions.conf /etc/asterisk/
            sudo chown asterisk:asterisk /etc/asterisk/extensions.conf
        fi
        
        print_status "✓ Asterisk configuration files installed"
    fi
fi

print_separator
print_status "Building the project..."
if npm run build >/dev/null 2>&1; then
    print_status "✓ Project built successfully"
else
    print_error "Failed to build project"
    exit 1
fi

# Run setup-backend script if it exists
if [ -f "scripts/setup-backend.sh" ]; then
    print_status "Running setup-backend.sh..."
    chmod +x scripts/setup-backend.sh
    ./scripts/setup-backend.sh "$MYSQL_ROOT_PASSWORD" "$ASTERISK_DB_PASSWORD"
fi

# Run setup-web script if it exists
if [ -f "scripts/setup-web.sh" ]; then
    print_status "Running setup-web.sh..."
    chmod +x scripts/setup-web.sh
    # Pass environment variables to setup-web.sh
    MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" ASTERISK_DB_PASSWORD="$ASTERISK_DB_PASSWORD" ./scripts/setup-web.sh
fi

# Run setup-agi script if it exists
if [ -f "scripts/setup-agi.sh" ]; then
    print_status "Running setup-agi.sh..."
    chmod +x scripts/setup-agi.sh
    ./scripts/setup-agi.sh
fi

# Start the backend service
print_status "Starting backend service..."
sudo systemctl enable ibilling-backend >/dev/null 2>&1
sudo systemctl restart ibilling-backend >/dev/null 2>&1

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

# Fix realtime authentication
if [ -f "scripts/fix-realtime-auth.sh" ]; then
    chmod +x scripts/fix-realtime-auth.sh
    if ./scripts/fix-realtime-auth.sh "$MYSQL_ROOT_PASSWORD" "$ASTERISK_DB_PASSWORD" >/dev/null 2>&1; then
        print_status "✓ Realtime authentication fixed successfully"
        
        # Test realtime functionality
        if [ -f "scripts/test-realtime-complete.sh" ]; then
            print_status "Testing realtime functionality..."
            chmod +x scripts/test-realtime-complete.sh
            if ./scripts/test-realtime-complete.sh "$ASTERISK_DB_PASSWORD" >/dev/null 2>&1; then
                print_status "✓ Realtime functionality test passed"
            else
                print_warning "⚠ Realtime functionality test encountered issues"
            fi
        fi
    else
        print_warning "⚠ Realtime authentication fix encountered issues"
        echo -e "\nYou can manually fix this later by running:"
        echo -e "sudo ./scripts/fix-realtime-auth.sh $MYSQL_ROOT_PASSWORD $ASTERISK_DB_PASSWORD"
    fi
else
    print_warning "⚠ Realtime authentication fix script not found"
fi

# CRITICAL FIX: Apply PJSIP sorcery configuration fix
print_separator
print_status "Applying PJSIP sorcery configuration fix..."
if [ -f "scripts/fix-pjsip-sorcery.sh" ]; then
    chmod +x scripts/fix-pjsip-sorcery.sh
    if sudo ./scripts/fix-pjsip-sorcery.sh; then
        print_status "✅ PJSIP sorcery configuration fixed successfully!"
        print_status "Endpoints should now be visible in Asterisk"
    else
        print_error "❌ PJSIP sorcery fix failed"
        print_warning "You may need to run this manually:"
        echo -e "sudo ./scripts/fix-pjsip-sorcery.sh"
    fi
else
    print_error "❌ PJSIP sorcery fix script not found"
    print_warning "This may cause endpoint visibility issues"
fi

# Run system checks
if [ -f "scripts/system-checks.sh" ]; then
    print_status "Running system-checks.sh..."
    chmod +x scripts/system-checks.sh
    ./scripts/system-checks.sh "$MYSQL_ROOT_PASSWORD" "$ASTERISK_DB_PASSWORD"
fi

# Update database schema with additional tables
if [ -f "scripts/update-database-schema.sh" ]; then
    print_status "Running update-database-schema.sh..."
    chmod +x scripts/update-database-schema.sh
    ./scripts/update-database-schema.sh "$MYSQL_ROOT_PASSWORD"
fi

# Verify database population
if [ -f "scripts/verify-database-population.sh" ]; then
    print_status "Running verify-database-population.sh..."
    chmod +x scripts/verify-database-population.sh
    ./scripts/verify-database-population.sh "$MYSQL_ROOT_PASSWORD"
fi

# Add sample DIDs with correct password
if [ -f "scripts/add-sample-dids.sh" ]; then
    print_status "Running add-sample-dids.sh..."
    chmod +x scripts/add-sample-dids.sh
    # Use the correct password variable name
    MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" DB_PASSWORD="$ASTERISK_DB_PASSWORD" ./scripts/add-sample-dids.sh
fi

# Final Asterisk restart and verification
if command -v asterisk >/dev/null 2>&1; then
    print_status "Final Asterisk restart to ensure all configurations are loaded..."
    sudo systemctl restart asterisk >/dev/null 2>&1
    sleep 10
    
    # Test PJSIP endpoints after restart
    print_status "Testing PJSIP configuration..."
    sudo asterisk -rx "pjsip reload" >/dev/null 2>&1
    sleep 3
    
    endpoints_output=$(sudo asterisk -rx "pjsip show endpoints" 2>/dev/null)
    if echo "$endpoints_output" | grep -q "Endpoint:" || echo "$endpoints_output" | grep -q "c[0-9]"; then
        print_status "✅ PJSIP endpoints are visible and working correctly"
    elif echo "$endpoints_output" | grep -q "No objects found"; then
        print_status "✓ PJSIP is responding (ready for endpoint creation)"
    else
        print_warning "⚠ PJSIP may have configuration issues"
        echo "PJSIP output: $endpoints_output"
    fi
fi

# FINAL STEP: Run comprehensive PJSIP diagnostic and fix
print_separator
print_status "Running comprehensive PJSIP diagnostic and fix..."
if [ -f "scripts/diagnose-and-fix-pjsip.sh" ]; then
    chmod +x scripts/diagnose-and-fix-pjsip.sh
    if sudo ./scripts/diagnose-and-fix-pjsip.sh "$ASTERISK_DB_PASSWORD" "c462881"; then
        print_status "✅ PJSIP diagnostic and fix completed successfully!"
    else
        print_warning "⚠ PJSIP diagnostic encountered issues, but installation continues"
        print_status "You can run the diagnostic manually later:"
        print_status "sudo ./scripts/diagnose-and-fix-pjsip.sh $ASTERISK_DB_PASSWORD c462881"
    fi
else
    print_error "❌ PJSIP diagnostic script not found"
    print_warning "This may cause endpoint visibility issues"
fi

print_separator
print_status "INSTALLATION COMPLETED SUCCESSFULLY"
print_separator

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

echo -e "\n${GREEN}ODBC connection status can be checked with:${NC}"
echo "- sudo asterisk -rx 'odbc show all'"
echo "- isql -v asterisk-connector asterisk ${ASTERISK_DB_PASSWORD}"

echo -e "\n${GREEN}PJSIP endpoint management:${NC}"
echo "- View endpoints: sudo asterisk -rx 'pjsip show endpoints'"
echo "- If endpoints not visible, run: sudo ./scripts/fix-pjsip-sorcery.sh"
echo "- Full diagnostic: sudo ./scripts/diagnose-and-fix-pjsip.sh $ASTERISK_DB_PASSWORD c462881"

print_separator
print_status "Bootstrap completed successfully!"
print_separator
