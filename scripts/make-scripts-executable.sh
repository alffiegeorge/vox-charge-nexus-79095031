
#!/bin/bash

# Make all scripts executable
# This script ensures all shell scripts in the scripts directory have execute permissions

echo "Making scripts executable..."

# Core scripts
chmod +x scripts/*.sh 2>/dev/null || true

# Specific scripts that must be executable
chmod +x scripts/add-sample-dids.sh 2>/dev/null || true
chmod +x scripts/add-test-endpoint.sh 2>/dev/null || true
chmod +x scripts/asterisk-setup.sh 2>/dev/null || true
chmod +x scripts/clean-database.sh 2>/dev/null || true
chmod +x scripts/complete-database-setup.sh 2>/dev/null || true
chmod +x scripts/complete-mariadb-reinstall.sh 2>/dev/null || true
chmod +x scripts/config-generator.sh 2>/dev/null || true
chmod +x scripts/database-manager.sh 2>/dev/null || true
chmod +x scripts/debug-asterisk.sh 2>/dev/null || true
chmod +x scripts/debug-odbc.sh 2>/dev/null || true
chmod +x scripts/diagnose-endpoint-lookup.sh 2>/dev/null || true
chmod +x scripts/diagnose-pjsip-realtime.sh 2>/dev/null || true
chmod +x scripts/diagnose-registration-failure.sh 2>/dev/null || true
chmod +x scripts/diagnose-and-fix-pjsip.sh 2>/dev/null || true
chmod +x scripts/emergency-mariadb-reset.sh 2>/dev/null || true
chmod +x scripts/fix-asterisk22-schema.sh 2>/dev/null || true
chmod +x scripts/fix-database-auth.sh 2>/dev/null || true
chmod +x scripts/fix-database-schema.sh 2>/dev/null || true
chmod +x scripts/fix-endpoint-discovery.sh 2>/dev/null || true
chmod +x scripts/fix-odbc.sh 2>/dev/null || true
chmod +x scripts/fix-pjsip-realtime.sh 2>/dev/null || true
chmod +x scripts/fix-pjsip-sorcery.sh 2>/dev/null || true
chmod +x scripts/fix-realtime-auth.sh 2>/dev/null || true
chmod +x scripts/install-asterisk.sh 2>/dev/null || true
chmod +x scripts/make-all-executable.sh 2>/dev/null || true
chmod +x scripts/make-clean-executable.sh 2>/dev/null || true
chmod +x scripts/make-executable.sh 2>/dev/null || true
chmod +x scripts/make-odbc-scripts-executable.sh 2>/dev/null || true
chmod +x scripts/make-scripts-executable.sh 2>/dev/null || true
chmod +x scripts/populate-missing-data.sh 2>/dev/null || true
chmod +x scripts/populate-sample-data.sh 2>/dev/null || true
chmod +x scripts/reload-pjsip-realtime.sh 2>/dev/null || true
chmod +x scripts/remove-test-endpoint.sh 2>/dev/null || true
chmod +x scripts/reset-mariadb-password.sh 2>/dev/null || true
chmod +x scripts/run-emergency-reset.sh 2>/dev/null || true
chmod +x scripts/service-manager.sh 2>/dev/null || true
chmod +x scripts/setup-agi.sh 2>/dev/null || true
chmod +x scripts/setup-backend.sh 2>/dev/null || true
chmod +x scripts/setup-database.sh 2>/dev/null || true
chmod +x scripts/setup-odbc.sh 2>/dev/null || true
chmod +x scripts/setup-web.sh 2>/dev/null || true
chmod +x scripts/system-checks.sh 2>/dev/null || true
chmod +x scripts/test-realtime-complete.sh 2>/dev/null || true
chmod +x scripts/test-realtime.sh 2>/dev/null || true
chmod +x scripts/update-database-schema.sh 2>/dev/null || true
chmod +x scripts/utils.sh 2>/dev/null || true
chmod +x scripts/verify-database-population.sh 2>/dev/null || true

# AGI scripts
chmod +x scripts/agi/*.php 2>/dev/null || true

echo "✓ All scripts are now executable"
echo "✓ New diagnostic script added: diagnose-and-fix-pjsip.sh"
echo ""
echo "Usage: sudo ./scripts/diagnose-and-fix-pjsip.sh [db_password] [endpoint_id]"
echo "Example: sudo ./scripts/diagnose-and-fix-pjsip.sh fjjdal221 c462881"
