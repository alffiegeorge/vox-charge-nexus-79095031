
#!/bin/bash

# Make all scripts executable
echo "Making all scripts executable..."

# Make the main installation script executable
chmod +x install.sh

# Make all scripts in the scripts directory executable
chmod +x scripts/*.sh

echo "✓ All scripts are now executable"
echo ""
echo "Available scripts:"
ls -la scripts/*.sh
echo ""
echo "To fix realtime authentication issues, run:"
echo "  ./scripts/fix-realtime-auth.sh <mysql_root_password> <asterisk_db_password>"
echo ""
echo "To test realtime functionality, run:"
echo "  ./scripts/test-realtime-complete.sh <asterisk_db_password>"
echo ""
echo "Main installation script:"
ls -la install.sh
