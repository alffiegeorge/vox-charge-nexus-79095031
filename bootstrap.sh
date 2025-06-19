
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

# Clone the repository ONCE
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

# Make all scripts executable
print_status "Making all scripts executable..."
chmod +x scripts/*.sh 2>/dev/null || true
chmod +x install.sh 2>/dev/null || true

# Execute the make-scripts-executable script
if [ -f "scripts/make-scripts-executable.sh" ]; then
    print_status "Running make-scripts-executable.sh..."
    ./scripts/make-scripts-executable.sh
fi

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

# Install backend dependencies FIRST in the correct location
print_status "Installing backend dependencies..."
if [ -d "backend" ] && [ -f "backend/package.json" ]; then
    cd backend
    npm install
    print_status "✓ Backend dependencies installed"
    cd ..
else
    print_warning "Backend directory or package.json not found"
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

# Setup initial database schema with SIP credentials table
print_status "Setting up database schema..."
mysql -u root -p"$MYSQL_ROOT_PASSWORD" asterisk <<EOF
-- Create customers table if it doesn't exist
CREATE TABLE IF NOT EXISTS customers (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    address TEXT,
    status ENUM('active', 'inactive', 'suspended') DEFAULT 'active',
    balance DECIMAL(10,2) DEFAULT 0.00,
    credit_limit DECIMAL(10,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create sip_credentials table for endpoint management
CREATE TABLE IF NOT EXISTS sip_credentials (
    id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL UNIQUE,
    sip_username VARCHAR(50) NOT NULL UNIQUE,
    sip_password VARCHAR(100) NOT NULL,
    sip_domain VARCHAR(100) NOT NULL,
    status ENUM('active', 'inactive', 'suspended') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
);

-- Create PJSIP realtime tables for Asterisk
CREATE TABLE IF NOT EXISTS ps_endpoints (
    id VARCHAR(40) NOT NULL PRIMARY KEY,
    transport VARCHAR(40),
    aors VARCHAR(200),
    auth VARCHAR(40),
    context VARCHAR(40),
    disallow VARCHAR(200),
    allow VARCHAR(200),
    direct_media ENUM('yes','no') DEFAULT 'no',
    connected_line_method ENUM('invite','reinvite','update') DEFAULT 'invite',
    direct_media_method ENUM('invite','reinvite','update') DEFAULT 'invite',
    direct_media_glare_mitigation ENUM('none','outgoing','incoming') DEFAULT 'none',
    disable_direct_media_on_nat ENUM('yes','no') DEFAULT 'no',
    dtmf_mode ENUM('rfc4733','inband','info','auto','auto_info') DEFAULT 'rfc4733',
    external_media_address VARCHAR(40),
    force_rport ENUM('yes','no') DEFAULT 'yes',
    ice_support ENUM('yes','no') DEFAULT 'no',
    identify_by ENUM('username','auth_username','endpoint') DEFAULT 'username',
    mailboxes VARCHAR(40),
    moh_suggest VARCHAR(40),
    outbound_auth VARCHAR(40),
    outbound_proxy VARCHAR(40),
    rewrite_contact ENUM('yes','no') DEFAULT 'no',
    rtp_ipv6 ENUM('yes','no') DEFAULT 'no',
    rtp_symmetric ENUM('yes','no') DEFAULT 'no',
    send_diversion ENUM('yes','no') DEFAULT 'yes',
    send_pai ENUM('yes','no') DEFAULT 'no',
    send_rpid ENUM('yes','no') DEFAULT 'no',
    timers_min_se INTEGER DEFAULT 90,
    timers ENUM('forced','no','required','yes') DEFAULT 'yes',
    timers_sess_expires INTEGER DEFAULT 1800,
    callerid VARCHAR(40),
    from_user VARCHAR(40),
    from_domain VARCHAR(40),
    sub_min_expiry INTEGER DEFAULT 0,
    from_uri VARCHAR(40),
    mwi_from_user VARCHAR(40),
    dtls_verify ENUM('yes','no','fingerprint','certificate') DEFAULT 'no',
    dtls_rekey INTEGER DEFAULT 0,
    dtls_cert_file VARCHAR(200),
    dtls_private_key VARCHAR(200),
    dtls_cipher VARCHAR(200),
    dtls_ca_file VARCHAR(200),
    dtls_ca_path VARCHAR(200),
    dtls_setup ENUM('active','passive','actpass') DEFAULT 'active',
    srtp_tag_32 ENUM('yes','no') DEFAULT 'no',
    media_address VARCHAR(40),
    redirect_method ENUM('user','uri_core','uri_pjsip') DEFAULT 'user',
    set_var TEXT,
    cos_audio INTEGER DEFAULT 0,
    cos_video INTEGER DEFAULT 0,
    message_context VARCHAR(40),
    accountcode VARCHAR(40),
    trust_id_inbound ENUM('yes','no') DEFAULT 'no',
    trust_id_outbound ENUM('yes','no') DEFAULT 'no',
    use_ptime ENUM('yes','no') DEFAULT 'no',
    use_avpf ENUM('yes','no') DEFAULT 'no',
    media_encryption ENUM('no','sdes','dtls') DEFAULT 'no',
    inband_progress ENUM('yes','no') DEFAULT 'no',
    call_group VARCHAR(40),
    pickup_group VARCHAR(40),
    named_call_group VARCHAR(40),
    named_pickup_group VARCHAR(40),
    device_state_busy_at INTEGER DEFAULT 0,
    fax_detect ENUM('yes','no') DEFAULT 'no',
    t38_udptl ENUM('yes','no') DEFAULT 'no',
    t38_udptl_ec ENUM('none','fec','redundancy') DEFAULT 'none',
    t38_udptl_maxdatagram INTEGER DEFAULT 0,
    t38_udptl_nat ENUM('yes','no') DEFAULT 'no',
    t38_udptl_ipv6 ENUM('yes','no') DEFAULT 'no',
    tone_zone VARCHAR(40),
    language VARCHAR(40),
    one_touch_recording ENUM('yes','no') DEFAULT 'no',
    record_on_feature VARCHAR(40),
    record_off_feature VARCHAR(40),
    rtp_engine VARCHAR(40),
    allow_transfer ENUM('yes','no') DEFAULT 'yes',
    allow_subscribe ENUM('yes','no') DEFAULT 'yes',
    sdp_owner VARCHAR(40),
    sdp_session VARCHAR(40),
    tos_audio INTEGER DEFAULT 0,
    tos_video INTEGER DEFAULT 0,
    bind_rtp_to_media_address ENUM('yes','no') DEFAULT 'no',
    voicemail_extension VARCHAR(40)
);

CREATE TABLE IF NOT EXISTS ps_auths (
    id VARCHAR(40) NOT NULL PRIMARY KEY,
    auth_type ENUM('md5','userpass') DEFAULT 'userpass',
    nonce_lifetime INTEGER DEFAULT 32,
    md5_cred VARCHAR(40),
    password VARCHAR(80),
    realm VARCHAR(40),
    username VARCHAR(40)
);

CREATE TABLE IF NOT EXISTS ps_aors (
    id VARCHAR(40) NOT NULL PRIMARY KEY,
    contact VARCHAR(255),
    default_expiration INTEGER DEFAULT 3600,
    mailboxes VARCHAR(80),
    max_contacts INTEGER DEFAULT 1,
    minimum_expiration INTEGER DEFAULT 60,
    remove_existing ENUM('yes','no') DEFAULT 'no',
    qualify_frequency INTEGER DEFAULT 0,
    authenticate_qualify ENUM('yes','no') DEFAULT 'no',
    maximum_expiration INTEGER DEFAULT 7200,
    outbound_proxy VARCHAR(40),
    support_path ENUM('yes','no') DEFAULT 'no',
    qualify_timeout DECIMAL(3,2) DEFAULT 3.0,
    voicemail_extension VARCHAR(40)
);

CREATE TABLE IF NOT EXISTS ps_contacts (
    id VARCHAR(255) NOT NULL PRIMARY KEY,
    uri VARCHAR(255),
    expiration_time BIGINT,
    qualify_frequency INTEGER,
    outbound_proxy VARCHAR(40),
    path TEXT,
    user_agent VARCHAR(255),
    qualify_timeout DECIMAL(3,2),
    reg_server VARCHAR(255),
    authenticate_qualify ENUM('yes','no') DEFAULT 'no',
    via_addr VARCHAR(40),
    via_port INTEGER DEFAULT 0,
    call_id VARCHAR(255),
    endpoint VARCHAR(40),
    prune_on_boot ENUM('yes','no') DEFAULT 'no'
);

-- Create users table for authentication
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    role ENUM('admin', 'customer', 'operator') NOT NULL DEFAULT 'customer',
    status ENUM('active', 'inactive', 'suspended') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Insert default admin user (password: admin123)
INSERT IGNORE INTO users (username, password, email, role, status) VALUES 
('admin', '\$2a\$10\$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin@ibilling.local', 'admin', 'active');
EOF

if [ $? -eq 0 ]; then
    print_status "✓ Database schema created successfully"
else
    print_error "Failed to create database schema"
    exit 1
fi

# Export passwords for use by other scripts
export MYSQL_ROOT_PASSWORD
export ASTERISK_DB_PASSWORD

# Run the installation script with passwords
print_status "Running main installation script..."
if [ -f "install.sh" ]; then
    chmod +x install.sh
    ./install.sh "$MYSQL_ROOT_PASSWORD" "$ASTERISK_DB_PASSWORD"
else
    print_warning "install.sh not found, continuing with manual setup..."
fi

# Run individual scripts from the scripts folder
print_status "Running additional setup scripts..."

# Run setup-database script if it exists
if [ -f "scripts/setup-database.sh" ]; then
    print_status "Running setup-database.sh..."
    chmod +x scripts/setup-database.sh
    ./scripts/setup-database.sh "$MYSQL_ROOT_PASSWORD" "$ASTERISK_DB_PASSWORD"
fi

# Run setup-odbc script if it exists
if [ -f "scripts/setup-odbc.sh" ]; then
    print_status "Running setup-odbc.sh..."
    chmod +x scripts/setup-odbc.sh
    ./scripts/setup-odbc.sh "$ASTERISK_DB_PASSWORD"
fi

# Run config-generator script to create configuration files
if [ -f "scripts/config-generator.sh" ]; then
    print_status "Running config-generator.sh..."
    chmod +x scripts/config-generator.sh
    ./scripts/config-generator.sh
    
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

# Build the project
print_status "Building the project..."
if npm run build; then
    print_status "Project built successfully"
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

# Fix realtime authentication dynamically after Asterisk installation
print_status "Fixing realtime authentication..."
if [ -f "scripts/fix-realtime-auth.sh" ]; then
    chmod +x scripts/fix-realtime-auth.sh
    if ./scripts/fix-realtime-auth.sh "$MYSQL_ROOT_PASSWORD" "$ASTERISK_DB_PASSWORD"; then
        print_status "✓ Realtime authentication fixed successfully"
        
        # Test realtime functionality
        if [ -f "scripts/test-realtime-complete.sh" ]; then
            print_status "Testing realtime functionality..."
            chmod +x scripts/test-realtime-complete.sh
            if ./scripts/test-realtime-complete.sh "$ASTERISK_DB_PASSWORD"; then
                print_status "✓ Realtime functionality test passed"
            else
                print_warning "⚠ Realtime functionality test encountered issues"
            fi
        fi
    else
        print_warning "⚠ Realtime authentication fix encountered issues"
        print_status "You can manually fix this later by running:"
        print_status "sudo ./scripts/fix-realtime-auth.sh $MYSQL_ROOT_PASSWORD $ASTERISK_DB_PASSWORD"
    fi
else
    print_warning "⚠ Realtime authentication fix script not found"
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

# Restart Asterisk to load new configurations
if command -v asterisk >/dev/null 2>&1; then
    print_status "Restarting Asterisk to load configurations..."
    sudo systemctl restart asterisk
    sleep 5
    
    # Test PJSIP endpoints after restart
    print_status "Testing PJSIP configuration..."
    sudo asterisk -rx "pjsip reload" >/dev/null 2>&1
    sleep 3
    
    endpoints_output=$(sudo asterisk -rx "pjsip show endpoints" 2>/dev/null)
    if echo "$endpoints_output" | grep -q "Endpoint:" || echo "$endpoints_output" | grep -q "No objects found"; then
        print_status "✓ PJSIP is responding (ready for endpoint creation)"
    else
        print_warning "⚠ PJSIP may have configuration issues"
    fi
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
print_status "3. Create customers and their SIP endpoints from the admin panel"
print_status "4. Check PJSIP endpoints with: sudo asterisk -rx 'pjsip show endpoints'"
print_status ""
print_status "For troubleshooting, check:"
print_status "- Backend service: sudo systemctl status ibilling-backend"
print_status "- Backend logs: sudo journalctl -u ibilling-backend -f"
print_status "- Nginx status: sudo systemctl status nginx"
print_status "- Database: mysql -u asterisk -p${ASTERISK_DB_PASSWORD} asterisk"
print_status "- Asterisk status: sudo systemctl status asterisk"
print_status ""
print_status "ODBC connection status can be checked with:"
print_status "- sudo asterisk -rx 'odbc show all'"
print_status "- isql -v asterisk-connector asterisk ${ASTERISK_DB_PASSWORD}"

print_status "Bootstrap completed successfully!"
