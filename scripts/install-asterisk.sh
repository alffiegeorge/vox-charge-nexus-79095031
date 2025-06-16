
#!/bin/bash

# Asterisk installation script for iBilling
source "$(dirname "$0")/utils.sh"

install_asterisk() {
    local asterisk_db_password=$1
    
    print_status "Installing Asterisk 22 with ODBC support..."
    cd /usr/src
    
    # Download Asterisk 22
    sudo wget -O asterisk-22-current.tar.gz "https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-22-current.tar.gz"
    sudo tar xzf asterisk-22-current.tar.gz
    cd asterisk-22*/

    # Install additional dependencies for Asterisk 22
    print_status "Installing Asterisk 22 dependencies..."
    sudo apt update
    sudo apt install -y libcurl4-openssl-dev libxml2-dev libxslt1-dev \
        libedit-dev libjansson-dev uuid-dev libsqlite3-dev libssl-dev \
        libncurses5-dev libsrtp2-dev libspandsp-dev libtiff-dev \
        libfftw3-dev libvorbis-dev libspeex-dev libopus-dev libgsm1-dev \
        libneon27-dev libgmime-3.0-dev liburiparser-dev libical-dev \
        libjack-dev liblua5.2-dev libsnmp-dev libcorosync-common-dev \
        libradcli-dev python3-dev libpopt-dev libnewt-dev \
        unixodbc unixodbc-dev libmariadb-dev odbc-mariadb

    # Configure Asterisk build with ODBC support
    sudo contrib/scripts/get_mp3_source.sh
    sudo ./configure --with-odbc --with-crypto --with-ssl --with-srtp --with-unixodbc

    # Verify ODBC is properly detected
    print_status "Verifying ODBC configuration..."
    if ! grep -q "ODBC" config.log; then
        print_error "ODBC support not detected. Installing additional ODBC packages..."
        sudo apt install -y libodbc1 odbcinst1debian2 unixodbc-dev
        sudo ./configure --with-odbc --with-crypto --with-ssl --with-srtp --with-unixodbc
    fi

    # Enable required modules in menuselect
    sudo make menuselect.makeopts

    # Enable ODBC and realtime modules
    print_status "Enabling ODBC and realtime modules..."
    sudo menuselect/menuselect --enable res_odbc --enable cdr_adaptive_odbc --enable res_config_odbc menuselect.makeopts
    sudo menuselect/menuselect --enable res_realtime menuselect.makeopts
    sudo menuselect/menuselect --enable func_odbc menuselect.makeopts

    # Verify modules are enabled
    if ! grep -q "res_odbc" menuselect.makeopts; then
        print_warning "ODBC modules may not be available in this build"
    fi

    # Build and install
    print_status "Building Asterisk 22 (this may take 15-30 minutes)..."
    sudo make -j$(nproc)
    if [ $? -ne 0 ]; then
        print_error "Asterisk build failed"
        exit 1
    fi

    sudo make install
    sudo make samples
    sudo make config
    sudo ldconfig

    # Configure Asterisk for ODBC and realtime
    configure_asterisk "$asterisk_db_password"
}

configure_asterisk() {
    local asterisk_db_password=$1
    
    print_status "Configuring Asterisk for ODBC and realtime..."

    # Create asterisk user if it doesn't exist
    if ! id asterisk >/dev/null 2>&1; then
        print_status "Creating asterisk user and group..."
        sudo groupadd -r asterisk
        sudo useradd -r -d /var/lib/asterisk -g asterisk asterisk
        sudo usermod -aG audio,dialout asterisk
    fi

    # Set proper ownership
    sudo chown -R asterisk:asterisk /var/lib/asterisk
    sudo chown -R asterisk:asterisk /var/log/asterisk
    sudo chown -R asterisk:asterisk /var/spool/asterisk
    sudo chown -R asterisk:asterisk /etc/asterisk

    # Backup original configs
    backup_file /etc/asterisk/res_odbc.conf
    backup_file /etc/asterisk/extconfig.conf
    backup_file /etc/asterisk/modules.conf

    # Copy configuration templates
    sudo cp "$(dirname "$0")/../config/res_odbc.conf" /etc/asterisk/
    sudo cp "$(dirname "$0")/../config/cdr_adaptive_odbc.conf" /etc/asterisk/
    sudo cp "$(dirname "$0")/../config/extconfig.conf" /etc/asterisk/
    sudo cp "$(dirname "$0")/../config/extensions.conf" /etc/asterisk/
    sudo cp "$(dirname "$0")/../config/pjsip.conf" /etc/asterisk/

    # Replace password placeholder in configuration files
    sudo sed -i "s/ASTERISK_DB_PASSWORD_PLACEHOLDER/${asterisk_db_password}/g" /etc/asterisk/res_odbc.conf

    # Configure modules.conf to load ODBC and realtime modules
    print_status "Configuring modules.conf for ODBC and realtime..."
    
    # Remove any existing ODBC module entries
    sudo sed -i '/^load => res_odbc.so/d' /etc/asterisk/modules.conf
    sudo sed -i '/^load => cdr_adaptive_odbc.so/d' /etc/asterisk/modules.conf
    sudo sed -i '/^load => res_config_odbc.so/d' /etc/asterisk/modules.conf
    sudo sed -i '/^load => res_realtime.so/d' /etc/asterisk/modules.conf
    sudo sed -i '/^load => func_odbc.so/d' /etc/asterisk/modules.conf

    # Add ODBC and realtime modules
    cat << EOF | sudo tee -a /etc/asterisk/modules.conf

; ODBC and Realtime modules for iBilling
load => res_odbc.so
load => cdr_adaptive_odbc.so
load => res_config_odbc.so
load => res_realtime.so
load => func_odbc.so
EOF

    # Test ODBC connectivity before starting Asterisk
    print_status "Testing ODBC connectivity..."
    if command -v isql >/dev/null 2>&1; then
        if echo "SELECT 1;" | isql -v asterisk-connector asterisk "${asterisk_db_password}" >/dev/null 2>&1; then
            print_status "✓ ODBC connection test successful"
        else
            print_warning "⚠ ODBC connection test failed - check configuration"
        fi
    else
        print_warning "⚠ isql command not available for ODBC testing"
    fi

    # Start and enable Asterisk
    print_status "Starting Asterisk service..."
    sudo systemctl enable asterisk
    sudo systemctl start asterisk

    # Wait for Asterisk to start and verify ODBC modules are loaded
    sleep 10
    print_status "Verifying ODBC modules are loaded..."
    
    if sudo asterisk -rx "module show like odbc" | grep -q "res_odbc.so"; then
        print_status "✓ ODBC modules loaded successfully"
    else
        print_warning "⚠ ODBC modules may not be loaded - check Asterisk logs"
    fi

    # Test realtime configuration
    if sudo asterisk -rx "realtime load sippeers name" >/dev/null 2>&1; then
        print_status "✓ Realtime configuration is working"
    else
        print_warning "⚠ Realtime configuration may need adjustment"
    fi

    print_status "Asterisk 22 installation and ODBC/realtime configuration completed"
    print_status "Check logs with: sudo journalctl -u asterisk -f"
    print_status "Verify ODBC: sudo asterisk -rx 'odbc show all'"
    print_status "Check realtime: sudo asterisk -rx 'realtime load sippeers name'"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -ne 1 ]; then
        echo "Usage: $0 <asterisk_db_password>"
        exit 1
    fi
    install_asterisk "$1"
fi
