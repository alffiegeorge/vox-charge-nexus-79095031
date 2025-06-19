
#!/bin/bash

# Asterisk installation and configuration module
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
    
    print_status "Configuring Asterisk 22 for ODBC and realtime..."

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
    backup_file /etc/asterisk/pjsip.conf
    backup_file /etc/asterisk/extensions.conf

    # Copy configuration templates from /tmp/ibilling-config/
    sudo cp /tmp/ibilling-config/res_odbc.conf /etc/asterisk/
    sudo cp /tmp/ibilling-config/cdr_adaptive_odbc.conf /etc/asterisk/
    sudo cp /tmp/ibilling-config/extconfig.conf /etc/asterisk/
    sudo cp /tmp/ibilling-config/extensions.conf /etc/asterisk/
    sudo cp /tmp/ibilling-config/pjsip.conf /etc/asterisk/

    # Replace password placeholder in configuration files
    sudo sed -i "s/ASTERISK_DB_PASSWORD_PLACEHOLDER/${asterisk_db_password}/g" /etc/asterisk/res_odbc.conf

    # Setup ODBC system configuration
    print_status "Setting up ODBC system configuration..."
    sudo cp /tmp/ibilling-config/odbcinst.ini /etc/odbcinst.ini
    sudo cp /tmp/ibilling-config/odbc.ini.template /etc/odbc.ini
    sudo sed -i "s/ASTERISK_DB_PASSWORD_PLACEHOLDER/${asterisk_db_password}/g" /etc/odbc.ini

    # Configure modules.conf to load ODBC and realtime modules
    print_status "Configuring modules.conf for ODBC and realtime..."
    
    # Create a clean modules.conf with required modules
    sudo tee /etc/asterisk/modules.conf > /dev/null <<EOF
[modules]
autoload=yes

; Explicitly load ODBC and realtime modules
load => res_odbc.so
load => cdr_adaptive_odbc.so
load => res_config_odbc.so
load => res_realtime.so
load => func_odbc.so

; Load PJSIP modules
load => res_pjsip.so
load => res_pjsip_session.so
load => res_pjsip_registrar.so
load => res_pjsip_authenticator_digest.so
load => res_pjsip_endpoint_identifier_user.so
load => res_pjsip_endpoint_identifier_ip.so
load => res_pjsip_transport_udp.so
load => res_pjsip_transport_tcp.so

; Core modules
load => chan_pjsip.so
load => app_dial.so
load => app_echo.so
load => app_voicemail.so
load => pbx_config.so

; Disable chan_sip to avoid conflicts
noload => chan_sip.so
EOF

    # Set proper permissions
    sudo chown asterisk:asterisk /etc/asterisk/*

    # Test ODBC connectivity before starting Asterisk
    print_status "Testing ODBC connectivity..."
    if command -v isql >/dev/null 2>&1; then
        if echo "SELECT 1;" | isql -v asterisk-connector asterisk "${asterisk_db_password}" >/dev/null 2>&1; then
            print_status "✓ ODBC connection test successful"
        else
            print_warning "⚠ ODBC connection test failed - will retry after Asterisk restart"
        fi
    else
        print_warning "⚠ isql command not available for ODBC testing"
    fi

    # Stop any existing Asterisk
    sudo systemctl stop asterisk 2>/dev/null || true
    sudo pkill -f asterisk 2>/dev/null || true
    sleep 3

    # Start and enable Asterisk
    print_status "Starting Asterisk service..."
    sudo systemctl enable asterisk
    sudo systemctl start asterisk

    # Wait for Asterisk to start and verify modules are loaded
    sleep 15
    verify_asterisk_installation

    # Clean up temporary files
    sudo rm -rf /tmp/ibilling-config

    print_status "Asterisk 22 installation and ODBC/realtime configuration completed"
}

verify_asterisk_installation() {
    print_status "Verifying Asterisk modules and configuration..."
    
    # Check if Asterisk is running
    if sudo systemctl is-active --quiet asterisk; then
        print_status "✓ Asterisk service is running"
        
        # Check ODBC modules
        if sudo asterisk -rx "module show like odbc" 2>/dev/null | grep -q "res_odbc.so"; then
            print_status "✓ ODBC modules loaded successfully"
        else
            print_warning "⚠ ODBC modules may not be loaded - check Asterisk logs"
        fi
        
        # Check PJSIP modules
        if sudo asterisk -rx "module show like pjsip" 2>/dev/null | grep -q "res_pjsip.so"; then
            print_status "✓ PJSIP modules loaded successfully"
        else
            print_warning "⚠ PJSIP modules may not be loaded"
        fi
        
        # Test ODBC connection from Asterisk
        print_status "Testing ODBC connection from Asterisk..."
        if sudo asterisk -rx "odbc show all" 2>/dev/null | grep -q "asterisk.*Connected"; then
            print_status "✓ ODBC connection active in Asterisk"
        else
            print_warning "⚠ ODBC connection not active in Asterisk - restarting Asterisk"
            sudo systemctl restart asterisk
            sleep 10
            if sudo asterisk -rx "odbc show all" 2>/dev/null | grep -q "asterisk.*Connected"; then
                print_status "✓ ODBC connection active after restart"
            else
                print_error "✗ ODBC connection still not working"
            fi
        fi
        
        # Check realtime configuration
        if sudo asterisk -rx "realtime load ps_endpoints id" 2>/dev/null >/dev/null; then
            print_status "✓ Realtime configuration is working"
        else
            print_warning "⚠ Realtime configuration may need adjustment"
        fi
        
    else
        print_error "✗ Asterisk service failed to start"
        print_status "Check logs with: sudo journalctl -u asterisk -f"
    fi

    print_status ""
    print_status "Verification commands:"
    print_status "- Check Asterisk status: sudo systemctl status asterisk"
    print_status "- Check ODBC: sudo asterisk -rx 'odbc show all'"
    print_status "- Check PJSIP endpoints: sudo asterisk -rx 'pjsip show endpoints'"
    print_status "- Check realtime: sudo asterisk -rx 'realtime load ps_endpoints id'"
    print_status "- View logs: sudo journalctl -u asterisk -f"
    print_status ""
    print_status "Note: No endpoints will show until they are created in the database"
}
