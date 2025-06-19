
#!/bin/bash

# Make all scripts executable
chmod +x scripts/*.sh
chmod +x install.sh

# Make sure the realtime fix scripts are executable
chmod +x scripts/fix-realtime-auth.sh 2>/dev/null || true
chmod +x scripts/test-realtime-complete.sh 2>/dev/null || true

echo "All scripts are now executable"
echo ""
echo "Realtime authentication scripts:"
echo "- scripts/fix-realtime-auth.sh"
echo "- scripts/test-realtime-complete.sh"
