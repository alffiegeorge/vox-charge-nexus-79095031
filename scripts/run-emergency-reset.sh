
#!/bin/bash

# Enhanced emergency reset script that tries password reset first
source "$(dirname "$0")/utils.sh"

main() {
    print_status "=== ENHANCED EMERGENCY DATABASE RESET ==="
    
    # Parse arguments
    local mysql_root_password=${1:-"admin123"}
    local asterisk_db_password=${2:-"asterisk123"}
    
    print_status "Attempting emergency database recovery..."
    print_status "MySQL root password: $mysql_root_password"
    print_status "Asterisk DB password: $asterisk_db_password"
    
    # Step 1: Try simple password reset first
    print_status "Step 1: Attempting MariaDB password reset..."
    if [ -f "$(dirname "$0")/reset-mariadb-password.sh" ]; then
        chmod +x "$(dirname "$0")/reset-mariadb-password.sh"
        if "$(dirname "$0")/reset-mariadb-password.sh" "$mysql_root_password"; then
            print_status "✓ MariaDB password reset successful!"
            
            # Create asterisk database and user
            print_status "Creating asterisk database and user..."
            mysql -u root -p"$mysql_root_password" <<EOF
CREATE DATABASE IF NOT EXISTS asterisk CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'asterisk'@'localhost' IDENTIFIED BY '$asterisk_db_password';
GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk'@'localhost';
FLUSH PRIVILEGES;
EOF
            
            if [ $? -eq 0 ]; then
                print_status "✓ Asterisk database and user created successfully"
                print_status "Database recovery completed! You can now run your installation."
                return 0
            else
                print_warning "Failed to create asterisk database, proceeding with emergency reset..."
            fi
        else
            print_warning "Password reset failed, proceeding with emergency reset..."
        fi
    else
        print_warning "Password reset script not found, proceeding with emergency reset..."
    fi
    
    # Step 2: Try emergency reset if password reset failed
    print_status "Step 2: Attempting emergency MariaDB reset..."
    if [ -f "$(dirname "$0")/emergency-mariadb-reset.sh" ]; then
        chmod +x "$(dirname "$0")/emergency-mariadb-reset.sh"
        if "$(dirname "$0")/emergency-mariadb-reset.sh" "$mysql_root_password" "$asterisk_db_password"; then
            print_status "✓ Emergency reset successful! MariaDB is working."
            return 0
        else
            print_warning "Emergency reset failed, proceeding with complete reinstall..."
        fi
    else
        print_warning "Emergency reset script not found, proceeding with complete reinstall..."
    fi
    
    # Step 3: Complete MariaDB reinstall if everything else failed
    print_status "Step 3: Performing complete MariaDB reinstall..."
    if [ -f "$(dirname "$0")/complete-mariadb-reinstall.sh" ]; then
        chmod +x "$(dirname "$0")/complete-mariadb-reinstall.sh"
        if "$(dirname "$0")/complete-mariadb-reinstall.sh" "$mysql_root_password" "$asterisk_db_password"; then
            print_status "✓ Complete reinstall successful!"
            return 0
        else
            print_error "Complete reinstall failed"
            return 1
        fi
    else
        print_error "Complete reinstall script not found"
        return 1
    fi
}

# Show usage information
show_usage() {
    echo "Usage: $0 [mysql_root_password] [asterisk_db_password]"
    echo "   or: $0 [asterisk_db_password] (uses default root password)"
    echo "   or: $0 (uses default passwords)"
    echo ""
    echo "This script will attempt to recover MariaDB access using multiple methods:"
    echo "1. Password reset (safest, preserves data)"
    echo "2. Emergency reset (rebuilds authentication)"
    echo "3. Complete reinstall (nuclear option)"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Check for help
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        show_usage
        exit 0
    fi
    
    # Parse arguments
    if [ $# -eq 0 ]; then
        main "admin123" "asterisk123"
    elif [ $# -eq 1 ]; then
        main "admin123" "$1"
    elif [ $# -eq 2 ]; then
        main "$1" "$2"
    else
        show_usage
        exit 1
    fi
fi
