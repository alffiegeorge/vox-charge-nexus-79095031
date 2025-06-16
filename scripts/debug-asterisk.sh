
#!/bin/bash

# Debug script for Asterisk PJSIP and realtime issues
source "$(dirname "$0")/utils.sh"

debug_asterisk() {
    print_status "Debugging Asterisk PJSIP and realtime configuration..."
    
    # Check Asterisk service status
    print_status "=== Asterisk Service Status ==="
    sudo systemctl status asterisk --no-pager
    echo ""
    
    # Check loaded modules
    print_status "=== Loaded ODBC Modules ==="
    sudo asterisk -rx "module show like odbc" 2>/dev/null || print_error "Failed to check ODBC modules"
    echo ""
    
    print_status "=== Loaded PJSIP Modules ==="
    sudo asterisk -rx "module show like pjsip" 2>/dev/null || print_error "Failed to check PJSIP modules"
    echo ""
    
    # Check ODBC connections
    print_status "=== ODBC Connections ==="
    sudo asterisk -rx "odbc show all" 2>/dev/null || print_error "Failed to check ODBC connections"
    echo ""
    
    # Check PJSIP configuration
    print_status "=== PJSIP Endpoints ==="
    sudo asterisk -rx "pjsip show endpoints" 2>/dev/null || print_error "Failed to check PJSIP endpoints"
    echo ""
    
    print_status "=== PJSIP Transports ==="
    sudo asterisk -rx "pjsip show transports" 2>/dev/null || print_error "Failed to check PJSIP transports"
    echo ""
    
    # Check realtime configuration
    print_status "=== Realtime Configuration Test ==="
    sudo asterisk -rx "realtime load ps_endpoints id" 2>/dev/null || print_error "Failed to test realtime"
    echo ""
    
    # Check configuration files
    print_status "=== Configuration Files ==="
    print_status "res_odbc.conf:"
    if [ -f /etc/asterisk/res_odbc.conf ]; then
        sudo cat /etc/asterisk/res_odbc.conf
    else
        print_error "res_odbc.conf not found"
    fi
    echo ""
    
    print_status "extconfig.conf:"
    if [ -f /etc/asterisk/extconfig.conf ]; then
        sudo cat /etc/asterisk/extconfig.conf
    else
        print_error "extconfig.conf not found"
    fi
    echo ""
    
    # Check ODBC system configuration
    print_status "=== System ODBC Configuration ==="
    print_status "ODBC drivers:"
    if [ -f /etc/odbcinst.ini ]; then
        sudo cat /etc/odbcinst.ini
    else
        print_error "odbcinst.ini not found"
    fi
    echo ""
    
    print_status "ODBC DSNs:"
    if [ -f /etc/odbc.ini ]; then
        sudo cat /etc/odbc.ini
    else
        print_error "odbc.ini not found"
    fi
    echo ""
    
    # Check recent Asterisk logs
    print_status "=== Recent Asterisk Logs ==="
    sudo journalctl -u asterisk --since "5 minutes ago" --no-pager | tail -20
    echo ""
    
    print_status "Debug information collected. Check the output above for issues."
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    debug_asterisk
fi
