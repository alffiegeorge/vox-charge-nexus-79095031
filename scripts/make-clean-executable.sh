
#!/bin/bash

# Make the clean database script executable
chmod +x scripts/clean-database.sh

echo "✓ Clean database script is now executable"
echo ""
echo "To completely clean the database, run:"
echo "  ./scripts/clean-database.sh"
echo ""
echo "This will:"
echo "- Drop the asterisk database completely"
echo "- Remove all asterisk users"
echo "- Reset root user authentication"
echo "- Clear backend environment database password"
