
#!/bin/bash

# Setup AGI scripts for iBilling
source "$(dirname "$0")/utils.sh"

setup_agi_scripts() {
    print_status "Setting up AGI scripts for billing..."
    
    # Create AGI directory in Asterisk
    sudo mkdir -p /var/lib/asterisk/agi-bin
    
    # Copy AGI scripts
    sudo cp "$(dirname "$0")/agi/"*.php /var/lib/asterisk/agi-bin/
    
    # Make scripts executable
    sudo chmod +x /var/lib/asterisk/agi-bin/*.php
    
    # Set proper ownership
    sudo chown asterisk:asterisk /var/lib/asterisk/agi-bin/*.php
    
    # Install PHP CLI if not present
    if ! command -v php &> /dev/null; then
        print_status "Installing PHP CLI..."
        sudo apt-get update
        sudo apt-get install -y php-cli php-mysql
    fi
    
    print_status "✓ AGI scripts setup completed"
}

setup_asterisk_configs() {
    print_status "Deploying Asterisk configuration files..."
    
    # Backup existing configs
    backup_file /etc/asterisk/extensions.conf
    backup_file /etc/asterisk/extconfig.conf
    backup_file /etc/asterisk/res_odbc.conf
    
    # Copy new configurations
    sudo cp "$(dirname "$0")/../config/extensions.conf" /etc/asterisk/
    sudo cp "$(dirname "$0")/../config/extconfig.conf" /etc/asterisk/
    sudo cp "$(dirname "$0")/../config/res_odbc.conf" /etc/asterisk/
    
    # Set proper ownership
    sudo chown asterisk:asterisk /etc/asterisk/*.conf
    
    print_status "✓ Asterisk configurations deployed"
}

reload_asterisk() {
    print_status "Reloading Asterisk configuration..."
    
    # Reload dialplan
    sudo asterisk -rx "dialplan reload"
    
    # Reload modules
    sudo asterisk -rx "module reload res_odbc.so"
    sudo asterisk -rx "module reload res_config_odbc.so"
    
    print_status "✓ Asterisk configuration reloaded"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_agi_scripts
    setup_asterisk_configs
    reload_asterisk
fi
