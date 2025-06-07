
#!/bin/bash

# System checks script for iBilling
source "$(dirname "$0")/utils.sh"

perform_system_checks() {
    print_status "Performing final system checks..."

    local all_good=true

    # Check MariaDB
    if ! check_service mariadb; then
        all_good=false
    fi

    # Check Asterisk
    if ! check_service asterisk; then
        all_good=false
    fi

    # Check Nginx
    if ! check_service nginx; then
        all_good=false
    fi

    return $all_good
}

display_installation_summary() {
    local mysql_root_password=$1
    local asterisk_db_password=$2
    
    print_status "============================================="
    print_status "iBilling - Professional Voice Billing System Installation Complete!"
    print_status "============================================="
    echo ""
    print_status "System Information:"
    echo "• Frontend URL: http://localhost (or your server IP)"
    echo "• Database: MariaDB on localhost:3306"
    echo "• Database Name: asterisk"
    echo "• Database User: asterisk"
    echo "• Environment File: /opt/billing/.env"
    echo ""
    print_status "Credentials (SAVE THESE SECURELY):"
    echo "• MySQL Root Password: ${mysql_root_password}"
    echo "• Asterisk DB Password: ${asterisk_db_password}"
    echo ""
    print_status "Next Steps:"
    echo "1. Configure your domain name in Nginx if needed"
    echo "2. Set up SSL certificates with: sudo certbot --nginx"
    echo "3. Configure firewall rules for ports 80, 443, 5060-5061 (SIP)"
    echo "4. Review Asterisk configuration in /etc/asterisk/"
    echo "5. Test the web interface at http://your-server-ip"
    echo ""
    print_warning "Remember to:"
    echo "• Change default passwords"
    echo "• Configure backup procedures"
    echo "• Set up monitoring"
    echo "• Review security settings"

    print_status "Installation completed successfully!"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -ne 2 ]; then
        echo "Usage: $0 <mysql_root_password> <asterisk_db_password>"
        exit 1
    fi
    perform_system_checks
    display_installation_summary "$1" "$2"
fi
