
#!/bin/bash

# Fix PJSIP Realtime Configuration Script
# This script fixes the issue where PJSIP endpoints are not visible in Asterisk
# despite existing in the database

source "$(dirname "$0")/utils.sh"

fix_pjsip_sorcery() {
    print_status "=================================================="
    print_status "PJSIP Realtime Configuration Fix"
    print_status "=================================================="

    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        print_error "Error: This script must be run as root (use sudo)"
        return 1
    fi

    # Backup original configuration
    print_status "1. Backing up original sorcery.conf..."
    sudo cp /etc/asterisk/sorcery.conf /etc/asterisk/sorcery.conf.backup.$(date +%Y%m%d_%H%M%S)
    if [ $? -eq 0 ]; then
        print_status "✓ Backup created successfully"
    else
        print_error "✗ Failed to create backup"
        return 1
    fi

    # Fix sorcery.conf configuration
    print_status "2. Fixing sorcery.conf configuration..."

    # Uncomment PJSIP section and mappings
    sudo sed -i 's/^;\[res_pjsip\]/\[res_pjsip\]/' /etc/asterisk/sorcery.conf
    sudo sed -i 's/^;endpoint=realtime,ps_endpoints/endpoint=realtime,ps_endpoints/' /etc/asterisk/sorcery.conf
    sudo sed -i 's/^;auth=realtime,ps_auths/auth=realtime,ps_auths/' /etc/asterisk/sorcery.conf
    sudo sed -i 's/^;aor=realtime,ps_aors/aor=realtime,ps_aors/' /etc/asterisk/sorcery.conf
    sudo sed -i 's/^;contact=realtime,ps_contacts/contact=realtime,ps_contacts/' /etc/asterisk/sorcery.conf

    # Also uncomment endpoint identifier section
    sudo sed -i 's/^;\[res_pjsip_endpoint_identifier_ip\]/\[res_pjsip_endpoint_identifier_ip\]/' /etc/asterisk/sorcery.conf
    sudo sed -i 's/^;identify=realtime,ps_endpoint_id_ips/identify=realtime,ps_endpoint_id_ips/' /etc/asterisk/sorcery.conf

    print_status "✓ Configuration changes applied"

    # Verify changes
    print_status "3. Verifying configuration changes..."
    print_status "Current PJSIP configuration:"
    sudo grep -A 10 "\[res_pjsip\]" /etc/asterisk/sorcery.conf

    # Check if Asterisk is running
    if ! sudo systemctl is-active --quiet asterisk; then
        print_error "Error: Asterisk is not running. Please start Asterisk first."
        return 1
    fi

    # Reload PJSIP module
    print_status "4. Reloading PJSIP module..."
    sudo asterisk -rx 'module reload res_pjsip.so' >/dev/null 2>&1
    sleep 3

    # Restart Asterisk completely
    print_status "5. Restarting Asterisk service..."
    sudo systemctl restart asterisk

    # Wait for Asterisk to fully start
    print_status "6. Waiting for Asterisk to start..."
    sleep 10

    # Check if Asterisk started successfully
    if ! sudo systemctl is-active --quiet asterisk; then
        print_error "✗ Asterisk failed to start after configuration changes"
        return 1
    fi

    # Verify endpoints are visible
    print_status "7. Verifying PJSIP endpoints visibility..."
    local endpoints_output=$(sudo asterisk -rx 'pjsip show endpoints' 2>/dev/null)
    
    if echo "$endpoints_output" | grep -q "c[0-9]"; then
        print_status "✅ Success! PJSIP endpoints are now visible:"
        echo "$endpoints_output"
    else
        print_warning "⚠ Endpoints may not be visible yet. Output:"
        echo "$endpoints_output"
        
        # Try one more reload
        print_status "Attempting additional reload..."
        sudo asterisk -rx 'pjsip reload' >/dev/null 2>&1
        sleep 5
        
        local retry_output=$(sudo asterisk -rx 'pjsip show endpoints' 2>/dev/null)
        if echo "$retry_output" | grep -q "c[0-9]"; then
            print_status "✅ Success after reload! PJSIP endpoints are now visible:"
            echo "$retry_output"
        else
            print_error "❌ Endpoints still not visible. Check Asterisk logs for errors."
            return 1
        fi
    fi

    print_status "=================================================="
    print_status "✅ Fix completed successfully!"
    print_status "=================================================="
    print_status "Endpoints are now visible and ready for SIP client registration."
    print_status "Backup of original configuration saved as sorcery.conf.backup.*"
    
    return 0
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    fix_pjsip_sorcery
fi
