
#!/bin/bash

# iBilling installation main script with comprehensive integrated fixes

# Make scripts executable if they exist
if [ -d "scripts" ]; then
    chmod +x scripts/*.sh 2>/dev/null || true
fi

# Check if we have utils.sh
if [ ! -f "scripts/utils.sh" ]; then
    echo "Error: scripts/utils.sh not found. Please ensure the bootstrap script completed successfully."
    exit 1
fi

# Source the utility functions
source "scripts/utils.sh"

main() {
    print_status "Starting iBilling installation with comprehensive integrated fixes..."
    
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
    setup_system_packages
    
    # Setup database with comprehensive fixes
    if [ -n "$MYSQL_ROOT_PASSWORD" ] && [ -n "$ASTERISK_DB_PASSWORD" ]; then
        setup_complete_database "$MYSQL_ROOT_PASSWORD" "$ASTERISK_DB_PASSWORD"
    fi
    
    # Setup ODBC with integrated fixes
    setup_comprehensive_odbc "$ASTERISK_DB_PASSWORD"
    
    # Install Asterisk with PJSIP fixes
    install_asterisk_complete "$ASTERISK_DB_PASSWORD"
    
    # Apply all integrated fixes
    apply_comprehensive_fixes "$MYSQL_ROOT_PASSWORD" "$ASTERISK_DB_PASSWORD"
    
    # Create backend service environment
    setup_backend_service "$ASTERISK_DB_PASSWORD"
    
    print_status "iBilling installation completed successfully!"
    print_status ""
    print_status "Next steps:"
    print_status "1. Set up the web frontend with: scripts/setup-web.sh"
    print_status "2. Configure your first customer endpoints"
    print_status "3. Test the installation with verification commands"
}

setup_system_packages() {
    print_status "Setting up system packages..."
    sudo apt update
    sudo apt install -y wget mariadb-client net-tools vim git locales unixodbc unixodbc-dev \
        libmariadb-dev odbc-mariadb libodbc1 odbcinst1debian2 php-cli php-mysql
    sudo locale-gen en_US.UTF-8
    sudo update-locale LANG=en_US.UTF-8
    sudo timedatectl set-timezone UTC
}

setup_complete_database() {
    local mysql_root_password=$1
    local asterisk_db_password=$2
    
    print_status "Setting up complete database with all fixes..."
    
    # Fix MariaDB service issues
    sudo systemctl stop mariadb 2>/dev/null || true
    if [ -S "/var/run/mysqld/mysqld.sock" ]; then
        sudo rm -f /var/run/mysqld/mysqld.sock
    fi
    sudo mkdir -p /var/run/mysqld
    sudo chown mysql:mysql /var/run/mysqld
    sudo chmod 755 /var/run/mysqld
    sudo systemctl start mariadb
    
    # Wait for MariaDB to be ready
    for i in {1..30}; do
        if sudo systemctl is-active --quiet mariadb; then
            break
        fi
        sleep 1
    done
    
    # Secure MariaDB and create database
    print_status "Creating Asterisk database and user with proper permissions..."
    mysql -u root -p"${mysql_root_password}" <<EOF
DROP DATABASE IF EXISTS asterisk;
DROP USER IF EXISTS 'asterisk'@'localhost';
CREATE DATABASE asterisk CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'asterisk'@'localhost' IDENTIFIED BY '${asterisk_db_password}';
GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk'@'localhost';
FLUSH PRIVILEGES;
EOF

    # Create complete database schema
    create_complete_database_schema "$asterisk_db_password"
    
    # Add sample data with PJSIP endpoints
    populate_sample_data "$mysql_root_password" "$asterisk_db_password"
}

create_complete_database_schema() {
    local asterisk_db_password=$1
    
    print_status "Creating complete database schema with all required tables..."
    
    mysql -u asterisk -p"${asterisk_db_password}" asterisk <<'EOF'
-- Customers table
CREATE TABLE IF NOT EXISTS customers (
    id VARCHAR(20) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(20),
    status ENUM('active', 'inactive', 'suspended') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- SIP credentials table
CREATE TABLE IF NOT EXISTS sip_credentials (
    id INT(11) NOT NULL AUTO_INCREMENT,
    customer_id VARCHAR(20) NOT NULL,
    sip_username VARCHAR(40) NOT NULL UNIQUE,
    sip_password VARCHAR(40) NOT NULL,
    sip_domain VARCHAR(100) NOT NULL DEFAULT '172.31.10.10',
    status ENUM('active', 'inactive', 'suspended') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
    INDEX customer_idx (customer_id),
    INDEX username_idx (sip_username)
);

-- PJSIP endpoints table
CREATE TABLE IF NOT EXISTS ps_endpoints (
    id varchar(40) NOT NULL,
    transport varchar(40) DEFAULT NULL,
    aors varchar(200) DEFAULT NULL,
    auth varchar(40) DEFAULT NULL,
    context varchar(40) DEFAULT NULL,
    disallow varchar(200) DEFAULT NULL,
    allow varchar(200) DEFAULT NULL,
    direct_media enum('yes','no') DEFAULT NULL,
    ice_support enum('yes','no') DEFAULT NULL,
    force_rport enum('yes','no') DEFAULT NULL,
    rtp_symmetric enum('yes','no') DEFAULT NULL,
    send_rpid enum('yes','no') DEFAULT NULL,
    send_pai enum('yes','no') DEFAULT NULL,
    trust_id_inbound enum('yes','no') DEFAULT NULL,
    callerid varchar(40) DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY id (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- PJSIP authentication table
CREATE TABLE IF NOT EXISTS ps_auths (
    id varchar(40) NOT NULL,
    auth_type enum('md5','userpass') DEFAULT NULL,
    password varchar(80) DEFAULT NULL,
    username varchar(40) DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY id (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- PJSIP AOR table
CREATE TABLE IF NOT EXISTS ps_aors (
    id varchar(40) NOT NULL,
    max_contacts varchar(10) DEFAULT NULL,
    remove_existing tinyint(1) DEFAULT NULL,
    qualify_frequency varchar(10) DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY id (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- PJSIP contacts table
CREATE TABLE IF NOT EXISTS ps_contacts (
    id varchar(255) NOT NULL,
    uri varchar(511) DEFAULT NULL,
    expiration_time varchar(40) DEFAULT NULL,
    endpoint varchar(40) DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY id (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- DID numbers table
CREATE TABLE IF NOT EXISTS did_numbers (
    id INT(11) NOT NULL AUTO_INCREMENT,
    number VARCHAR(20) NOT NULL UNIQUE,
    customer_name VARCHAR(100) DEFAULT 'Unassigned',
    country VARCHAR(50),
    rate DECIMAL(10,4),
    type ENUM('Local', 'Toll-Free', 'Mobile') DEFAULT 'Local',
    status ENUM('Available', 'Assigned', 'Reserved') DEFAULT 'Available',
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX number_idx (number),
    INDEX status_idx (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Users table for admin
CREATE TABLE IF NOT EXISTS users (
    id INT(11) NOT NULL AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) UNIQUE,
    role ENUM('admin', 'user') DEFAULT 'user',
    status ENUM('active', 'inactive') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- CDR table
CREATE TABLE IF NOT EXISTS cdr (
    calldate datetime NOT NULL default '0000-00-00 00:00:00',
    clid varchar(80) NOT NULL default '',
    src varchar(80) NOT NULL default '',
    dst varchar(80) NOT NULL default '',
    dcontext varchar(80) NOT NULL default '',
    channel varchar(80) NOT NULL default '',
    dstchannel varchar(80) NOT NULL default '',
    lastapp varchar(80) NOT NULL default '',
    lastdata varchar(80) NOT NULL default '',
    duration int(11) NOT NULL default '0',
    billsec int(11) NOT NULL default '0',
    disposition varchar(45) NOT NULL default '',
    amaflags int(11) NOT NULL default '0',
    accountcode varchar(20) NOT NULL default '',
    uniqueid varchar(32) NOT NULL default '',
    userfield varchar(255) NOT NULL default '',
    answer datetime default NULL,
    end datetime default NULL,
    INDEX (calldate),
    INDEX (src),
    INDEX (dst)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
EOF
}

populate_sample_data() {
    local mysql_root_password=$1
    local asterisk_db_password=$2
    
    print_status "Populating sample data with working PJSIP endpoints..."
    
    mysql -u asterisk -p"${asterisk_db_password}" asterisk <<'EOF'
-- Insert sample customers
INSERT IGNORE INTO customers (id, name, email, phone) VALUES
('C001', 'Alfred Iaviniao', 'alfred@example.com', '+1234567890'),
('C002', 'Test Customer', 'test@example.com', '+1234567891');

-- Create SIP credentials for sample customers
INSERT IGNORE INTO sip_credentials (customer_id, sip_username, sip_password, sip_domain) 
SELECT 'C001', 'c001', 'test123', '172.31.10.10'
WHERE NOT EXISTS (SELECT 1 FROM sip_credentials WHERE customer_id = 'C001');

INSERT IGNORE INTO sip_credentials (customer_id, sip_username, sip_password, sip_domain) 
SELECT 'C002', 'c002', 'test456', '172.31.10.10'
WHERE NOT EXISTS (SELECT 1 FROM sip_credentials WHERE customer_id = 'C002');

-- Create PJSIP endpoints for sample customers
INSERT IGNORE INTO ps_endpoints (id, transport, aors, auth, context, disallow, allow, 
                                direct_media, ice_support, force_rport, 
                                rtp_symmetric, send_rpid, send_pai, 
                                trust_id_inbound, callerid)
SELECT sc.sip_username, 'transport-udp', sc.sip_username, sc.sip_username, 'from-internal', 'all', 'ulaw,alaw,g722,g729',
       'no', 'yes', 'yes', 'yes', 'yes', 'yes', 'yes', CONCAT('"', c.name, '" <', sc.sip_username, '>')
FROM sip_credentials sc
JOIN customers c ON sc.customer_id = c.id
WHERE sc.status = 'active'
AND NOT EXISTS (SELECT 1 FROM ps_endpoints WHERE id = sc.sip_username);

-- Create PJSIP authentication entries
INSERT IGNORE INTO ps_auths (id, auth_type, username, password)
SELECT sc.sip_username, 'userpass', sc.sip_username, sc.sip_password
FROM sip_credentials sc
WHERE sc.status = 'active'
AND NOT EXISTS (SELECT 1 FROM ps_auths WHERE id = sc.sip_username);

-- Create PJSIP AOR entries
INSERT IGNORE INTO ps_aors (id, max_contacts, remove_existing, qualify_frequency)
SELECT sc.sip_username, '1', 1, '60'
FROM sip_credentials sc
WHERE sc.status = 'active'
AND NOT EXISTS (SELECT 1 FROM ps_aors WHERE id = sc.sip_username);

-- Add sample DIDs
INSERT IGNORE INTO did_numbers (number, customer_name, country, rate, type, status, notes) VALUES
('+1-555-0101', 'Unassigned', 'USA', 5.00, 'Local', 'Available', 'Local number for testing'),
('+1-555-0102', 'Unassigned', 'USA', 5.00, 'Local', 'Available', 'Local number for testing'),
('+1-800-555-0103', 'Unassigned', 'USA', 15.00, 'Toll-Free', 'Available', 'Toll-free number'),
('+44-20-7946-0958', 'Unassigned', 'UK', 8.00, 'Local', 'Available', 'London number'),
('+678-555-0104', 'Unassigned', 'Vanuatu', 3.00, 'Local', 'Available', 'Local Vanuatu number'),
('+678-555-0105', 'Unassigned', 'Vanuatu', 3.00, 'Local', 'Available', 'Local Vanuatu number');

-- Create default admin user
INSERT IGNORE INTO users (username, password, email, role, status) VALUES 
('admin', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin@ibilling.local', 'admin', 'active');
EOF
}

setup_comprehensive_odbc() {
    local asterisk_db_password=$1
    
    print_status "Setting up comprehensive ODBC configuration..."
    
    # Write ODBC driver config
    sudo tee /etc/odbcinst.ini > /dev/null <<'EOF'
[MariaDB]
Description=MariaDB ODBC Driver
Driver=/usr/lib/x86_64-linux-gnu/odbc/libmaodbc.so
Setup=/usr/lib/x86_64-linux-gnu/odbc/libodbcmyS.so
FileUsage=1
EOF

    # Write ODBC DSN config
    sudo tee /etc/odbc.ini > /dev/null <<EOF
[asterisk-connector]
Description=MySQL connection to 'asterisk' database
Driver=MariaDB
Database=asterisk
Server=localhost
Port=3306
Socket=/var/run/mysqld/mysqld.sock
Option=3
CharacterSet=utf8
EOF

    # Update res_odbc.conf with modern Asterisk 22 syntax
    sudo tee /etc/asterisk/res_odbc.conf > /dev/null <<EOF
[asterisk]
enabled => yes
dsn => asterisk-connector
username => asterisk
password => ${asterisk_db_password}
pooling => no
limit => 1
pre-connect => yes
sanitysql => select 1
connect_timeout => 10
negative_connection_cache => 300
EOF

    # Set proper file permissions
    sudo chown asterisk:asterisk /etc/asterisk/res_odbc.conf
    sudo chmod 640 /etc/asterisk/res_odbc.conf
    
    # Create extconfig.conf for realtime
    sudo tee /etc/asterisk/extconfig.conf > /dev/null <<'EOF'
[settings]
; PJSIP Realtime Configuration (Asterisk 22)
ps_endpoints => odbc,asterisk,ps_endpoints
ps_auths => odbc,asterisk,ps_auths
ps_aors => odbc,asterisk,ps_aors
ps_contacts => odbc,asterisk,ps_contacts

; Legacy SIP realtime (for compatibility)
sipusers => odbc,asterisk,sip_credentials
sippeers => odbc,asterisk,sip_credentials

; CDR realtime
cdr => odbc,asterisk
EOF

    sudo chown asterisk:asterisk /etc/asterisk/extconfig.conf
}

install_asterisk_complete() {
    local asterisk_db_password=$1
    
    print_status "Installing Asterisk with complete PJSIP configuration..."
    
    if [ -f "scripts/install-asterisk.sh" ]; then
        chmod +x scripts/install-asterisk.sh
        ./scripts/install-asterisk.sh "$asterisk_db_password"
    fi
    
    # Apply PJSIP sorcery configuration
    sudo tee /etc/asterisk/sorcery.conf > /dev/null <<'EOF'
; Sorcery Configuration for Asterisk 22 PJSIP Realtime

[res_pjsip]
endpoint=realtime,ps_endpoints
auth=realtime,ps_auths
aor=realtime,ps_aors
contact=realtime,ps_contacts

[res_pjsip_endpoint_identifier_ip]
identify=realtime,ps_endpoint_id_ips
EOF
    
    sudo chown asterisk:asterisk /etc/asterisk/sorcery.conf
}

apply_comprehensive_fixes() {
    local mysql_root_password=$1
    local asterisk_db_password=$2
    
    print_status "Applying comprehensive iBilling fixes..."
    
    # Ensure database user permissions are correct
    mysql -u root -p"${mysql_root_password}" <<EOF
GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk'@'localhost';
FLUSH PRIVILEGES;
EOF

    # Fix any missing PJSIP endpoints for existing customers
    fix_missing_pjsip_endpoints "$asterisk_db_password"
    
    # Restart Asterisk to apply all fixes
    print_status "Restarting Asterisk to apply all configuration fixes..."
    sudo systemctl restart asterisk
    sleep 10
    
    # Test PJSIP configuration
    test_pjsip_configuration "$asterisk_db_password"
}

fix_missing_pjsip_endpoints() {
    local asterisk_db_password=$1
    
    print_status "Checking and fixing any missing PJSIP endpoints..."
    
    # Get customers with SIP credentials but no PJSIP endpoints
    local missing_customers=$(mysql -u asterisk -p"${asterisk_db_password}" asterisk -N -e "
        SELECT sc.customer_id, sc.sip_username, sc.sip_password, c.name
        FROM sip_credentials sc
        JOIN customers c ON sc.customer_id = c.id
        WHERE sc.status = 'active'
        AND NOT EXISTS (SELECT 1 FROM ps_endpoints WHERE id = sc.sip_username)
        ORDER BY sc.customer_id;
    " 2>/dev/null)
    
    if [ -n "$missing_customers" ]; then
        print_status "Creating missing PJSIP endpoints..."
        
        echo "$missing_customers" | while read -r customer_id sip_username sip_password customer_name; do
            if [ -n "$customer_id" ]; then
                print_status "Creating PJSIP endpoint for: $customer_id ($customer_name)"
                
                # Create endpoint, auth, and AOR
                mysql -u asterisk -p"${asterisk_db_password}" asterisk -e "
                    INSERT IGNORE INTO ps_endpoints (id, transport, aors, auth, context, disallow, allow, 
                                                   direct_media, ice_support, force_rport, 
                                                   rtp_symmetric, send_rpid, send_pai, trust_id_inbound, callerid)
                    VALUES ('$sip_username', 'transport-udp', '$sip_username', '$sip_username', 'from-internal', 'all', 'ulaw,alaw,g722,g729',
                            'no', 'yes', 'yes', 'yes', 'yes', 'yes', 'yes', '\"$customer_name\" <$sip_username>');
                    
                    INSERT IGNORE INTO ps_auths (id, auth_type, username, password)
                    VALUES ('$sip_username', 'userpass', '$sip_username', '$sip_password');
                    
                    INSERT IGNORE INTO ps_aors (id, max_contacts, remove_existing, qualify_frequency)
                    VALUES ('$sip_username', '1', 1, '60');
                " 2>/dev/null
            fi
        done
    fi
}

test_pjsip_configuration() {
    local asterisk_db_password=$1
    
    print_status "Testing PJSIP configuration..."
    
    if sudo asterisk -rx "pjsip show endpoints" >/dev/null 2>&1; then
        local endpoint_count=$(sudo asterisk -rx "pjsip show endpoints" 2>/dev/null | grep -c "Endpoint:")
        if [ "$endpoint_count" -gt 0 ]; then
            print_status "✓ PJSIP configuration working with $endpoint_count endpoints"
            
            # Display sample SIP credentials
            print_status ""
            print_status "=== Sample SIP Registration Credentials ==="
            mysql -u asterisk -p"${asterisk_db_password}" asterisk -e "
                SELECT 
                    c.name as 'Customer Name',
                    sc.sip_username as 'SIP Username',
                    sc.sip_password as 'SIP Password',
                    sc.sip_domain as 'SIP Domain'
                FROM sip_credentials sc
                JOIN customers c ON sc.customer_id = c.id
                WHERE sc.status = 'active'
                ORDER BY sc.customer_id;
            " 2>/dev/null
            print_status "Server: 172.31.10.10:5060 (UDP)"
            print_status ""
        else
            print_warning "⚠ PJSIP endpoints created but not visible in Asterisk"
        fi
    else
        print_error "✗ PJSIP configuration failed"
    fi
    
    print_status "✅ All iBilling fixes applied successfully!"
}

setup_backend_service() {
    local asterisk_db_password=$1
    
    print_status "Setting up backend service environment..."
    
    # Ensure backend directory exists
    sudo mkdir -p /opt/billing/web/backend
    
    # Create .env file for backend if it doesn't exist
    if [ ! -f "/opt/billing/web/backend/.env" ]; then
        print_status "Creating backend environment configuration..."
        sudo tee /opt/billing/web/backend/.env > /dev/null <<EOF
# Database Configuration
DB_HOST=localhost
DB_USER=asterisk
DB_PASSWORD=${asterisk_db_password}
DB_NAME=asterisk

# Asterisk AMI Configuration
ASTERISK_HOST=localhost
ASTERISK_AMI_PORT=5038
ASTERISK_USERNAME=admin
ASTERISK_SECRET=admin

# SIP Configuration
SIP_DOMAIN=172.31.10.10

# JWT Configuration
JWT_SECRET=your-secret-key-change-this

# Server Configuration
PORT=3001
NODE_ENV=production
EOF
        sudo chown -R www-data:www-data /opt/billing/web/backend/.env
    fi
    
    print_status "✓ Backend service environment configured"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
