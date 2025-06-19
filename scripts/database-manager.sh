
#!/bin/bash

# Database management module
source "$(dirname "$0")/utils.sh"

check_mysql_access() {
    local mysql_root_password=$1
    
    # Test if MySQL is accessible without password
    if mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
        print_status "MySQL root access available without password"
        return 0
    fi
    
    # Test if MySQL is accessible with provided password
    if [ -n "$mysql_root_password" ] && mysql -u root -p"${mysql_root_password}" -e "SELECT 1;" >/dev/null 2>&1; then
        print_status "MySQL root access available with provided password"
        return 0
    fi
    
    return 1
}

secure_mysql() {
    local mysql_root_password=$1
    
    print_status "Securing MariaDB installation..."
    
    # Check if we can access MySQL without password first
    if mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
        print_status "Setting up MySQL root password and security..."
        mysql -u root <<EOF
UPDATE mysql.user SET Password=PASSWORD('${mysql_root_password}') WHERE User='root';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
        if [ $? -eq 0 ]; then
            print_status "✓ MySQL secured successfully"
            return 0
        else
            print_error "✗ Failed to secure MySQL"
            return 1
        fi
    else
        print_status "MySQL appears to already be secured"
        return 0
    fi
}

reset_database() {
    local mysql_root_password=$1
    local asterisk_db_password=$2
    
    print_status "Resetting database - dropping and recreating..."
    
    # Stop any existing connections
    sudo systemctl stop asterisk 2>/dev/null || true
    
    # Try to determine the correct way to connect to MySQL
    local mysql_connect=""
    if mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
        mysql_connect="mysql -u root"
    elif [ -n "$mysql_root_password" ] && mysql -u root -p"${mysql_root_password}" -e "SELECT 1;" >/dev/null 2>&1; then
        mysql_connect="mysql -u root -p${mysql_root_password}"
    else
        print_error "Cannot connect to MySQL. Please check your MySQL installation and root password."
        reset_mysql_password "$mysql_root_password"
        mysql_connect="mysql -u root -p${mysql_root_password}"
    fi

    # Drop and recreate database
    $mysql_connect <<EOF
DROP DATABASE IF EXISTS asterisk;
CREATE DATABASE asterisk CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
DROP USER IF EXISTS 'asterisk'@'localhost';
CREATE USER 'asterisk'@'localhost' IDENTIFIED BY '${asterisk_db_password}';
GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk'@'localhost';
FLUSH PRIVILEGES;
EOF

    if [ $? -eq 0 ]; then
        print_status "✓ Database reset completed successfully"
    else
        print_error "✗ Database reset failed"
        exit 1
    fi
}

reset_mysql_password() {
    local mysql_root_password=$1
    
    print_status "Trying to reset MySQL root password..."
    
    # Stop MySQL
    sudo systemctl stop mariadb
    
    # Start MySQL in safe mode
    sudo mysqld_safe --skip-grant-tables --skip-networking &
    sleep 5
    
    # Reset root password
    mysql -u root <<EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysql_root_password}';
FLUSH PRIVILEGES;
EOF
    
    # Stop safe mode MySQL
    sudo pkill mysqld_safe
    sudo pkill mysqld
    sleep 3
    
    # Start MySQL normally
    sudo systemctl start mariadb
    sleep 5
    
    # Test connection
    if ! mysql -u root -p"${mysql_root_password}" -e "SELECT 1;" >/dev/null 2>&1; then
        print_error "Still cannot connect to MySQL after reset attempt"
        exit 1
    fi
    
    print_status "✓ MySQL root password reset successfully"
}

setup_database() {
    local mysql_root_password=$1
    local asterisk_db_password=$2
    
    print_status "Configuring MariaDB..."
    sudo systemctl start mariadb
    sudo systemctl enable mariadb

    # Check MySQL access and secure if needed
    if ! check_mysql_access "$mysql_root_password"; then
        secure_mysql "$mysql_root_password"
    fi

    # Reset database completely
    reset_database "$mysql_root_password" "$asterisk_db_password"

    # Create database tables using the schema file
    create_database_tables "$mysql_root_password"
    
    print_status "Database setup completed successfully"
}

create_database_tables() {
    local mysql_root_password=$1
    
    print_status "Creating database tables..."
    if [ -f "config/database-schema.sql" ]; then
        if mysql -u root -p"${mysql_root_password}" asterisk < "config/database-schema.sql"; then
            print_status "✓ Database schema applied successfully"
        else
            print_error "✗ Failed to apply database schema"
            exit 1
        fi
    else
        print_warning "Database schema file not found at config/database-schema.sql"
        create_basic_tables "$mysql_root_password"
    fi
}

create_basic_tables() {
    local mysql_root_password=$1
    
    print_status "Creating basic tables manually..."
    mysql -u root -p"${mysql_root_password}" asterisk <<EOF
-- Basic CDR table
CREATE TABLE IF NOT EXISTS cdr (
    id INT(11) NOT NULL AUTO_INCREMENT,
    calldate DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
    clid VARCHAR(80) NOT NULL DEFAULT '',
    src VARCHAR(80) NOT NULL DEFAULT '',
    dst VARCHAR(80) NOT NULL DEFAULT '',
    dcontext VARCHAR(80) NOT NULL DEFAULT '',
    channel VARCHAR(80) NOT NULL DEFAULT '',
    dstchannel VARCHAR(80) NOT NULL DEFAULT '',
    lastapp VARCHAR(80) NOT NULL DEFAULT '',
    lastdata VARCHAR(80) NOT NULL DEFAULT '',
    duration INT(11) NOT NULL DEFAULT '0',
    billsec INT(11) NOT NULL DEFAULT '0',
    disposition VARCHAR(45) NOT NULL DEFAULT '',
    amaflags INT(11) NOT NULL DEFAULT '0',
    accountcode VARCHAR(20) NOT NULL DEFAULT '',
    uniqueid VARCHAR(32) NOT NULL DEFAULT '',
    userfield VARCHAR(255) NOT NULL DEFAULT '',
    PRIMARY KEY (id),
    INDEX calldate_idx (calldate),
    INDEX accountcode_idx (accountcode)
);

-- PJSIP realtime tables
CREATE TABLE IF NOT EXISTS ps_endpoints (
    id VARCHAR(40) NOT NULL PRIMARY KEY,
    transport VARCHAR(40),
    aors VARCHAR(200),
    auth VARCHAR(40),
    context VARCHAR(40) DEFAULT 'from-internal',
    disallow VARCHAR(200) DEFAULT 'all',
    allow VARCHAR(200) DEFAULT 'ulaw,alaw',
    direct_media ENUM('yes','no') DEFAULT 'no'
);

CREATE TABLE IF NOT EXISTS ps_auths (
    id VARCHAR(40) NOT NULL PRIMARY KEY,
    auth_type ENUM('userpass','md5') DEFAULT 'userpass',
    password VARCHAR(80),
    username VARCHAR(40)
);

CREATE TABLE IF NOT EXISTS ps_aors (
    id VARCHAR(40) NOT NULL PRIMARY KEY,
    max_contacts INT DEFAULT 1,
    remove_existing ENUM('yes','no') DEFAULT 'yes'
);

-- Basic customers table
CREATE TABLE IF NOT EXISTS customers (
    id VARCHAR(20) NOT NULL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    balance DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    status ENUM('Active', 'Suspended', 'Closed') NOT NULL DEFAULT 'Active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF
}
