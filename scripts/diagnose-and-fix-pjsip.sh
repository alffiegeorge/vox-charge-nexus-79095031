
#!/bin/bash

# Comprehensive PJSIP Endpoint Diagnostic and Fix Script
# This script diagnoses and fixes PJSIP endpoint visibility issues

source "$(dirname "$0")/utils.sh"

# Default password - can be overridden
ASTERISK_DB_PASSWORD=${1:-"fjjdal221"}
ENDPOINT_ID=${2:-"c462881"}

print_status "=================================================="
print_status "PJSIP Endpoint Diagnostic and Fix Tool"
print_status "=================================================="
print_status "Database Password: ${ASTERISK_DB_PASSWORD}"
print_status "Testing Endpoint: ${ENDPOINT_ID}"
print_status "=================================================="

# Step 1: Check if endpoint exists in database
print_status "1. Checking if endpoint exists in database..."
echo "Checking ps_endpoints table:"
mysql -u asterisk -p"${ASTERISK_DB_PASSWORD}" asterisk -e "SELECT id FROM ps_endpoints WHERE id='${ENDPOINT_ID}';" 2>/dev/null
echo ""

echo "Checking ps_auths table:"
mysql -u asterisk -p"${ASTERISK_DB_PASSWORD}" asterisk -e "SELECT id FROM ps_auths WHERE id='${ENDPOINT_ID}';" 2>/dev/null
echo ""

echo "Checking ps_aors table:"
mysql -u asterisk -p"${ASTERISK_DB_PASSWORD}" asterisk -e "SELECT id FROM ps_aors WHERE id='${ENDPOINT_ID}';" 2>/dev/null
echo ""

# Step 2: Check ODBC connection status
print_status "2. Checking ODBC connection status..."
sudo asterisk -rx 'odbc show all'
echo ""

# Step 3: Check sorcery configuration
print_status "3. Checking sorcery configuration..."
echo "Current sorcery.conf content:"
sudo cat /etc/asterisk/sorcery.conf
echo ""

# Step 4: Check PJSIP endpoints visibility (before fix)
print_status "4. Checking PJSIP endpoints visibility (before fix)..."
echo "PJSIP endpoints:"
sudo asterisk -rx 'pjsip show endpoints'
echo ""

echo "PJSIP contacts:"
sudo asterisk -rx 'pjsip show contacts'
echo ""

# Step 5: Apply the fix
print_status "5. Applying PJSIP sorcery configuration fix..."
print_status "Creating backup of sorcery.conf..."
sudo cp /etc/asterisk/sorcery.conf /etc/asterisk/sorcery.conf.backup.$(date +%Y%m%d_%H%M%S)

print_status "Uncommenting PJSIP section..."
sudo sed -i 's/^;\[res_pjsip\]/\[res_pjsip\]/' /etc/asterisk/sorcery.conf

print_status "Uncommenting endpoint mapping..."
sudo sed -i 's/^;endpoint=realtime,ps_endpoints/endpoint=realtime,ps_endpoints/' /etc/asterisk/sorcery.conf

print_status "Uncommenting auth mapping..."
sudo sed -i 's/^;auth=realtime,ps_auths/auth=realtime,ps_auths/' /etc/asterisk/sorcery.conf

print_status "Uncommenting AOR mapping..."
sudo sed -i 's/^;aor=realtime,ps_aors/aor=realtime,ps_aors/' /etc/asterisk/sorcery.conf

# Step 6: Verify configuration changes
print_status "6. Verifying configuration changes..."
echo "Updated PJSIP configuration:"
sudo grep -A 5 "\[res_pjsip\]" /etc/asterisk/sorcery.conf
echo ""

# Step 7: Reload PJSIP module
print_status "7. Reloading PJSIP module..."
sudo asterisk -rx 'module reload res_pjsip.so'
sleep 2

# Step 8: Restart Asterisk service
print_status "8. Restarting Asterisk service..."
sudo systemctl restart asterisk
print_status "Waiting for Asterisk to fully start..."
sleep 10

# Step 9: Verify the fix
print_status "9. Verifying the fix..."
print_status "Checking PJSIP endpoints (after fix):"
sudo asterisk -rx 'pjsip show endpoints'
echo ""

print_status "Checking PJSIP contacts (after fix):"
sudo asterisk -rx 'pjsip show contacts'
echo ""

# Step 10: Additional verification
print_status "10. Additional verification..."
echo "Testing realtime load for endpoint ${ENDPOINT_ID}:"
sudo asterisk -rx "realtime load ps_endpoints id ${ENDPOINT_ID}"
echo ""

echo "Checking if endpoint is now visible:"
endpoints_output=$(sudo asterisk -rx 'pjsip show endpoints' 2>/dev/null)
if echo "$endpoints_output" | grep -q "${ENDPOINT_ID}"; then
    print_status "✅ SUCCESS: Endpoint ${ENDPOINT_ID} is now visible!"
else
    print_error "❌ FAILED: Endpoint ${ENDPOINT_ID} is still not visible"
    print_status "Manual troubleshooting may be required"
fi

print_status "=================================================="
print_status "Diagnostic and Fix Completed"
print_status "=================================================="
print_status "Backup of original sorcery.conf saved as:"
ls -la /etc/asterisk/sorcery.conf.backup.* 2>/dev/null | tail -1
print_status ""
print_status "To run this script again:"
print_status "sudo ./scripts/diagnose-and-fix-pjsip.sh [db_password] [endpoint_id]"
print_status ""
print_status "Example:"
print_status "sudo ./scripts/diagnose-and-fix-pjsip.sh fjjdal221 c462881"
