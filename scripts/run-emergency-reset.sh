
#!/bin/bash

# Run the emergency MariaDB reset and then bootstrap
source "$(dirname "$0")/utils.sh"

print_status "Running emergency MariaDB reset..."

# Make sure the emergency reset script is executable
chmod +x scripts/emergency-mariadb-reset.sh

# Run the emergency reset
if ./scripts/emergency-mariadb-reset.sh; then
    print_status "✓ Emergency MariaDB reset completed successfully"
    
    # Wait a moment for services to stabilize
    sleep 5
    
    print_status "Now running the bootstrap script..."
    # Run bootstrap with the passwords from the reset
    ./bootstrap.sh
else
    print_error "Emergency MariaDB reset failed"
    print_status "Manual intervention required"
    exit 1
fi
