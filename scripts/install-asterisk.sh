
#!/bin/bash

# Asterisk installation script for iBilling
source "$(dirname "$0")/utils.sh"

install_asterisk() {
    local asterisk_db_password=$1
    
    print_status "Installing Asterisk with ODBC support..."
    cd /usr/src
    sudo wget -O asterisk-20-current.tar.gz "http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-20-current.tar.gz"
    sudo tar xzf asterisk-20-current.tar.gz
    cd asterisk-20*/

    # Configure Asterisk build
    sudo contrib/scripts/get_mp3_source.sh
    sudo ./configure --with-odbc --with-crypto --with-ssl --with-srtp

    # Enable required modules in menuselect
    sudo make menuselect.makeopts

    # Enable ODBC modules
    sudo menuselect/menuselect --enable res_odbc --enable cdr_adaptive_odbc --enable res_config_odbc menuselect.makeopts

    # Build and install
    sudo make -j$(nproc)
    sudo make install
    sudo make samples
    sudo make config
    sudo ldconfig

    # Configure Asterisk for ODBC
    configure_asterisk "$asterisk_db_password"
}

configure_asterisk() {
    local asterisk_db_password=$1
    
    print_status "Configuring Asterisk..."

    # Backup original configs
    backup_file /etc/asterisk/res_odbc.conf

    # Copy configuration templates
    sudo cp "$(dirname "$0")/../config/res_odbc.conf" /etc/asterisk/
    sudo cp "$(dirname "$0")/../config/cdr_adaptive_odbc.conf" /etc/asterisk/
    sudo cp "$(dirname "$0")/../config/extconfig.conf" /etc/asterisk/

    # Replace password placeholder in configuration files
    sudo sed -i "s/ASTERISK_DB_PASSWORD_PLACEHOLDER/${asterisk_db_password}/g" /etc/asterisk/res_odbc.conf

    # Configure modules.conf to load ODBC modules
    sudo sed -i '/^load => res_odbc.so/d' /etc/asterisk/modules.conf
    sudo sed -i '/^load => cdr_adaptive_odbc.so/d' /etc/asterisk/modules.conf
    sudo sed -i '/^load => res_config_odbc.so/d' /etc/asterisk/modules.conf

    echo "load => res_odbc.so" | sudo tee -a /etc/asterisk/modules.conf
    echo "load => cdr_adaptive_odbc.so" | sudo tee -a /etc/asterisk/modules.conf
    echo "load => res_config_odbc.so" | sudo tee -a /etc/asterisk/modules.conf

    # Start and enable Asterisk
    sudo systemctl enable asterisk
    sudo systemctl start asterisk

    print_status "Asterisk installation and configuration completed"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -ne 1 ]; then
        echo "Usage: $0 <asterisk_db_password>"
        exit 1
    fi
    install_asterisk "$1"
fi
