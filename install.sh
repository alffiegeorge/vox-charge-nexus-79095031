
#!/bin/bash

# iBilling installation main script

# Make scripts executable if they exist
if [ -f "scripts/utils.sh" ]; then
    chmod +x scripts/*.sh
fi

# Check if script files exist before sourcing
if [ ! -f "scripts/utils.sh" ] || [ ! -f "scripts/database-manager.sh" ] || [ ! -f "scripts/config-generator.sh" ] || [ ! -f "scripts/asterisk-setup.sh" ] || [ ! -f "scripts/service-manager.sh" ]; then
    echo "Error: Required script files are missing. Please ensure all script files are present in the scripts/ directory."
    echo "Required files:"
    echo "  - scripts/utils.sh"
    echo "  - scripts/database-manager.sh" 
    echo "  - scripts/config-generator.sh"
    echo "  - scripts/asterisk-setup.sh"
    echo "  - scripts/service-manager.sh"
    exit 1
fi

source "scripts/utils.sh"
source "scripts/database-manager.sh"
source "scripts/config-generator.sh"
source "scripts/asterisk-setup.sh"
source "scripts/service-manager.sh"

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
    
    # Run installation steps
    setup_system
    
    if [ -n "$MYSQL_ROOT_PASSWORD" ] && [ -n "$ASTERISK_DB_PASSWORD" ]; then
        setup_database "$MYSQL_ROOT_PASSWORD" "$ASTERISK_DB_PASSWORD"
    fi
    
    create_config_files
    install_asterisk "$ASTERISK_DB_PASSWORD"
    manage_backend_service "$ASTERISK_DB_PASSWORD"
    
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
