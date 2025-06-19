
#!/bin/bash

# Configuration file generator module
source "$(dirname "$0")/utils.sh"

create_config_files() {
    print_status "Creating configuration files..."
    sudo mkdir -p /tmp/ibilling-config
    
    # ODBC resource configuration
    sudo tee /tmp/ibilling-config/res_odbc.conf > /dev/null <<'EOF'
[asterisk]
enabled => yes
dsn => asterisk-connector
username => asterisk
password => ASTERISK_DB_PASSWORD_PLACEHOLDER
pooling => no
limit => 1
pre-connect => yes
sanitysql => select 1
connect_timeout => 10
negative_connection_cache => 300
EOF

    # CDR ODBC configuration
    sudo tee /tmp/ibilling-config/cdr_adaptive_odbc.conf > /dev/null <<'EOF'
[asterisk]
connection=asterisk
table=cdr
EOF

    # Asterisk realtime configuration
    sudo tee /tmp/ibilling-config/extconfig.conf > /dev/null <<'EOF'
[settings]
; Map Asterisk objects to database tables for realtime

; PJSIP Realtime Configuration (Asterisk 22)
ps_endpoints => odbc,asterisk,ps_endpoints
ps_auths => odbc,asterisk,ps_auths
ps_aors => odbc,asterisk,ps_aors
ps_contacts => odbc,asterisk,ps_contacts

; Legacy SIP realtime (for compatibility)
sipusers => odbc,asterisk,sip_credentials
sippeers => odbc,asterisk,sip_credentials

; Voicemail realtime
voicemail => odbc,asterisk,voicemail_users

; Extension realtime (optional - use with caution)
extensions => odbc,asterisk,extensions

; CDR realtime (handled by cdr_adaptive_odbc.conf)
; cdr => odbc,asterisk,cdr

; Queue realtime
; queues => odbc,asterisk,queues
; queue_members => odbc,asterisk,queue_members

; Parking realtime
; parkinglots => odbc,asterisk,parkinglots
EOF

    # ODBC driver configuration
    sudo tee /tmp/ibilling-config/odbcinst.ini > /dev/null <<'EOF'
[MariaDB]
Description = MariaDB ODBC driver
Driver      = /usr/lib/x86_64-linux-gnu/odbc/libmaodbc.so
Threading   = 1
EOF

    # ODBC DSN configuration template
    sudo tee /tmp/ibilling-config/odbc.ini.template > /dev/null <<'EOF'
[asterisk-connector]
Description = MariaDB connection to 'asterisk' database
Driver      = MariaDB
Server      = 127.0.0.1
Database    = asterisk
User        = asterisk
Password    = ASTERISK_DB_PASSWORD_PLACEHOLDER
Port        = 3306
Socket      = /var/run/mysqld/mysqld.sock
Option      = 3
EOF

    # Basic extensions.conf for testing
    sudo tee /tmp/ibilling-config/extensions.conf > /dev/null <<'EOF'
; Extensions Configuration for iBilling
; This file is managed by the iBilling system

[general]
static=yes
writeprotect=no
clearglobalvars=no

[globals]
; Global variables go here

[from-internal]
; Internal extension context
; Test extension for PJSIP endpoints
exten => 100,1,Dial(PJSIP/100)
exten => 101,1,Dial(PJSIP/101)

; Echo test
exten => 600,1,Answer()
exten => 600,n,Echo()
exten => 600,n,Hangup()

; Voicemail test
exten => *97,1,VoiceMailMain()

[from-external]
; External/trunk context
; DID routing will be added here by the system

include => from-internal
EOF

    # Enhanced PJSIP configuration with debugging
    sudo tee /tmp/ibilling-config/pjsip.conf > /dev/null <<'EOF'
; PJSIP Configuration for iBilling
; This file is managed by the iBilling system

[global]
type=global
endpoint_identifier_order=username,ip
debug=yes

[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060

[transport-tcp]
type=transport
protocol=tcp
bind=0.0.0.0:5060

; Template for customer endpoints
[customer-template](!)
type=endpoint
context=from-internal
disallow=all
allow=ulaw,alaw,g722,g729
direct_media=no
ice_support=yes
force_rport=yes
rewrite_contact=yes
rtp_symmetric=yes
send_rpid=yes
send_pai=yes
trust_id_inbound=yes

; Template for auth objects
[auth-template](!)
type=auth
auth_type=userpass

; Template for AOR objects  
[aor-template](!)
type=aor
max_contacts=1
remove_existing=yes
qualify_frequency=60

; Sample endpoint for testing (will be replaced by realtime)
[100]
type=endpoint
context=from-internal
disallow=all
allow=ulaw,alaw
aors=100
auth=100

[100]
type=auth
auth_type=userpass
username=100
password=test123

[100]
type=aor
max_contacts=1

; Trunk configurations will be added here by the system
; Customer configurations will be added here by the system
EOF

    print_status "Configuration files created in /tmp/ibilling-config/"
}
