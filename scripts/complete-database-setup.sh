
#!/bin/bash

# Complete database setup script for iBilling
# Run this after MariaDB is accessible

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if MariaDB is accessible
check_mariadb() {
    print_status "Checking MariaDB connection..."
    if sudo mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
        print_status "✓ MariaDB is accessible with socket authentication"
        return 0
    else
        print_error "✗ Cannot connect to MariaDB"
        print_status "Please ensure MariaDB is running: sudo systemctl start mariadb"
        return 1
    fi
}

# Generate password if not provided
generate_password() {
    openssl rand -base64 32
}

setup_database_complete() {
    local mysql_root_password=${1:-$(generate_password)}
    local asterisk_db_password=${2:-$(generate_password)}
    
    print_status "Setting up iBilling database with root password..."
    
    # Set root password and secure installation
    sudo mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysql_root_password}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

    print_status "Creating Asterisk database and user..."
    mysql -u root -p"${mysql_root_password}" <<EOF
DROP USER IF EXISTS 'asterisk'@'localhost';
CREATE DATABASE IF NOT EXISTS asterisk CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'asterisk'@'localhost' IDENTIFIED BY '${asterisk_db_password}';
GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk'@'localhost';
FLUSH PRIVILEGES;
EOF

    # Test connection
    print_status "Testing asterisk user connection..."
    if mysql -u asterisk -p"${asterisk_db_password}" -e "USE asterisk; SELECT 1;" >/dev/null 2>&1; then
        print_status "✓ Asterisk database user created successfully"
    else
        print_error "✗ Failed to create asterisk user properly"
        return 1
    fi

    # Create tables from schema
    print_status "Creating database schema..."
    if [ -f "/tmp/ibilling-config/database-schema.sql" ]; then
        mysql -u root -p"${mysql_root_password}" asterisk < /tmp/ibilling-config/database-schema.sql
    elif [ -f "config/database-schema.sql" ]; then
        mysql -u root -p"${mysql_root_password}" asterisk < config/database-schema.sql
    else
        print_error "Database schema file not found"
        return 1
    fi

    # Create default admin user
    print_status "Creating default admin user..."
    ADMIN_HASH='$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi'
    mysql -u root -p"${mysql_root_password}" asterisk <<EOF
INSERT IGNORE INTO users (username, password, email, role, status) VALUES 
('admin', '${ADMIN_HASH}', 'admin@ibilling.local', 'admin', 'active');
EOF

    # Update backend .env file
    print_status "Updating backend configuration..."
    if [ -f "/opt/billing/web/backend/.env" ]; then
        sudo sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=${asterisk_db_password}/" /opt/billing/web/backend/.env
        sudo sed -i "s/JWT_SECRET=.*/JWT_SECRET=$(openssl rand -base64 32)/" /opt/billing/web/backend/.env
    fi

    print_status "Database setup completed successfully!"
    echo "MySQL Root Password: ${mysql_root_password}"
    echo "Asterisk DB Password: ${asterisk_db_password}"
    echo ""
    print_status "Save these passwords securely!"
    
    return 0
}

check_services() {
    print_status "Checking system services..."
    
    services=("mariadb" "nginx")
    for service in "${services[@]}"; do
        if sudo systemctl is-active --quiet "$service"; then
            print_status "✓ $service is running"
        else
            print_warning "⚠ $service is not running, attempting to start..."
            sudo systemctl start "$service"
            if sudo systemctl is-active --quiet "$service"; then
                print_status "✓ $service started successfully"
            else
                print_error "✗ Failed to start $service"
            fi
        fi
    done
}

check_backend() {
    print_status "Checking backend API..."
    
    if sudo systemctl is-active --quiet "ibilling-backend"; then
        print_status "✓ Backend service is running"
    else
        print_status "Starting backend service..."
        sudo systemctl start ibilling-backend
        sleep 3
    fi
    
    if curl -s http://localhost:3001/health > /dev/null; then
        print_status "✓ Backend API is responding"
    else
        print_warning "⚠ Backend API not responding, checking logs..."
        sudo journalctl -u ibilling-backend --no-pager -n 10
    fi
}

main() {
    print_status "iBilling Database Setup and Service Check"
    echo "=========================================="
    
    if ! check_mariadb; then
        exit 1
    fi
    
    # Get passwords from user or generate them
    echo "Enter MySQL root password (or press Enter to generate): "
    read -s mysql_root_password
    if [ -z "$mysql_root_password" ]; then
        mysql_root_password=$(generate_password)
    fi
    
    echo "Enter Asterisk DB password (or press Enter to generate): "
    read -s asterisk_db_password
    if [ -z "$asterisk_db_password" ]; then
        asterisk_db_password=$(generate_password)
    fi
    
    if setup_database_complete "$mysql_root_password" "$asterisk_db_password"; then
        check_services
        check_backend
        
        print_status "Setup completed! You can now:"
        echo "1. Access the web interface at http://localhost"
        echo "2. Login with admin/admin123"
        echo "3. Check backend API at http://localhost:3001/health"
    else
        print_error "Database setup failed"
        exit 1
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
EOF

<lov-write file_path="scripts/fix-mariadb-service.sh">
#!/bin/bash

# MariaDB service fix script for iBilling
source "$(dirname "$0")/utils.sh"

fix_mariadb_service() {
    print_status "Fixing MariaDB service issues..."
    
    # Stop MariaDB if running
    sudo systemctl stop mariadb 2>/dev/null || true
    
    # Check for existing socket files
    if [ -S "/var/run/mysqld/mysqld.sock" ]; then
        print_status "Removing existing socket file..."
        sudo rm -f /var/run/mysqld/mysqld.sock
    fi
    
    # Ensure proper permissions
    sudo mkdir -p /var/run/mysqld
    sudo chown mysql:mysql /var/run/mysqld
    sudo chmod 755 /var/run/mysqld
    
    # Check disk space
    available_space=$(df /var/lib/mysql | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 1000000 ]; then
        print_warning "Low disk space in /var/lib/mysql"
    fi
    
    # Start MariaDB
    print_status "Starting MariaDB..."
    sudo systemctl start mariadb
    
    # Wait for service to be ready
    for i in {1..30}; do
        if sudo systemctl is-active --quiet mariadb; then
            print_status "✓ MariaDB service is running"
            break
        fi
        sleep 1
    done
    
    # Test connection
    if sudo mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
        print_status "✓ MariaDB is accessible"
        return 0
    else
        print_error "✗ MariaDB is not accessible"
        print_status "Checking service status..."
        sudo systemctl status mariadb --no-pager -l
        return 1
    fi
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    fix_mariadb_service
fi
EOF

Make scripts executable:
chmod +x scripts/complete-database-setup.sh
chmod +x scripts/fix-mariadb-service.sh
