
#!/bin/bash

# Comprehensive ODBC debugging script
source "$(dirname "$0")/utils.sh"

debug_odbc_comprehensive() {
    print_status "=== Comprehensive ODBC Debug Report ==="
    echo ""
    
    # System information
    print_status "=== System Information ==="
    echo "OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')"
    echo "Architecture: $(uname -m)"
    echo "Kernel: $(uname -r)"
    echo ""
    
    # Check ODBC packages
    print_status "=== Installed ODBC Packages ==="
    dpkg -l | grep -E "(odbc|mariadb)" | grep -v "^rc" || echo "No ODBC packages found"
    echo ""
    
    # Check ODBC drivers
    print_status "=== ODBC Driver Information ==="
    if [ -f /etc/odbcinst.ini ]; then
        echo "odbcinst.ini contents:"
        cat /etc/odbcinst.ini
        echo ""
        echo "Available drivers:"
        odbcinst -q -d 2>/dev/null || echo "No drivers found"
    else
        echo "odbcinst.ini not found"
    fi
    echo ""
    
    # Check DSNs
    print_status "=== ODBC DSN Information ==="
    if [ -f /etc/odbc.ini ]; then
        echo "odbc.ini contents:"
        cat /etc/odbc.ini
        echo ""
        echo "Available DSNs:"
        odbcinst -q -s 2>/dev/null || echo "No DSNs found"
    else
        echo "odbc.ini not found"
    fi
    echo ""
    
    # Check MariaDB/MySQL status
    print_status "=== MariaDB/MySQL Status ==="
    if sudo systemctl is-active --quiet mariadb; then
        echo "✓ MariaDB service is running"
        echo "MySQL version: $(mysql --version 2>/dev/null || echo 'Not accessible')"
        echo "MySQL socket locations:"
        find /var/run /tmp /var/lib -name "*.sock" 2>/dev/null | grep -i mysql || echo "No MySQL sockets found"
        echo "MySQL process:"
        ps aux | grep -E "(mysql|mariadb)" | grep -v grep || echo "No MySQL processes found"
    else
        echo "✗ MariaDB service is not running"
    fi
    echo ""
    
    # Check Asterisk configuration
    print_status "=== Asterisk ODBC Configuration ==="
    if [ -f /etc/asterisk/res_odbc.conf ]; then
        echo "res_odbc.conf contents:"
        cat /etc/asterisk/res_odbc.conf
    else
        echo "res_odbc.conf not found"
    fi
    echo ""
    
    # Check Asterisk status
    print_status "=== Asterisk Status ==="
    if sudo systemctl is-active --quiet asterisk; then
        echo "✓ Asterisk service is running"
        echo "Asterisk version: $(sudo asterisk -V 2>/dev/null || echo 'Not accessible')"
        echo ""
        echo "Loaded ODBC modules:"
        sudo asterisk -rx "module show like odbc" 2>/dev/null || echo "Cannot access Asterisk CLI"
        echo ""
        echo "ODBC connections:"
        sudo asterisk -rx "odbc show all" 2>/dev/null || echo "Cannot access Asterisk CLI"
    else
        echo "✗ Asterisk service is not running"
    fi
    echo ""
    
    # Check file permissions
    print_status "=== File Permissions ==="
    echo "ODBC configuration files:"
    ls -la /etc/odbc* 2>/dev/null || echo "ODBC config files not found"
    echo ""
    echo "Asterisk ODBC configuration:"
    ls -la /etc/asterisk/res_odbc.conf 2>/dev/null || echo "Asterisk ODBC config not found"
    echo ""
    
    # Check logs
    print_status "=== Recent Logs ==="
    echo "Recent Asterisk logs (last 20 lines):"
    sudo journalctl -u asterisk --since "10 minutes ago" -n 20 --no-pager 2>/dev/null || echo "Cannot access Asterisk logs"
    echo ""
    
    # Test connectivity
    print_status "=== Connectivity Tests ==="
    echo "Testing database connectivity:"
    if mysql -u asterisk -p"${1:-}" -e "SELECT 1;" asterisk >/dev/null 2>&1; then
        echo "✓ Direct MySQL connection works"
    else
        echo "✗ Direct MySQL connection failed"
    fi
    
    if command -v isql >/dev/null 2>&1 && [ -n "${1:-}" ]; then
        echo "Testing ODBC connectivity:"
        if echo "SELECT 1;" | timeout 5 isql asterisk-connector asterisk "${1}" >/dev/null 2>&1; then
            echo "✓ ODBC connection works"
        else
            echo "✗ ODBC connection failed"
        fi
    else
        echo "Cannot test ODBC (isql not available or no password provided)"
    fi
    
    print_status "=== Debug Report Complete ==="
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    debug_odbc_comprehensive "$1"
fi
