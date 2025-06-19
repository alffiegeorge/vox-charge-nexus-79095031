
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
echo "Main installation script:"
ls -la install.sh
