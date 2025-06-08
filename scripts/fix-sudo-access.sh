
#!/bin/bash

# Fix sudo access script for iBilling
source "$(dirname "$0")/utils.sh"

fix_sudo_access() {
    print_status "Checking current sudo status..."
    
    # Check if user is already in sudo group
    if groups "$USER" | grep -q '\bsudo\b'; then
        print_status "✓ User $USER is in sudo group"
        
        # Test if sudo actually works
        if sudo -n true 2>/dev/null; then
            print_status "✓ Sudo access is working"
            return 0
        else
            print_warning "User is in sudo group but sudo requires password or has issues"
        fi
    else
        print_warning "User $USER is not in sudo group"
    fi
    
    print_status "Attempting to fix sudo access..."
    print_warning "You will need the root password or an existing sudo user"
    
    # Method 1: Try using su to add user to sudo group
    print_status "Method 1: Using root access to fix sudo"
    echo "Enter root password (or press Ctrl+C to try alternative method):"
    
    if su - root -c "usermod -aG sudo $USER && echo 'User $USER added to sudo group successfully'"; then
        print_status "✓ Successfully added user to sudo group using root"
        print_warning "You need to log out and log back in, or run: exec su - $USER"
        return 0
    else
        print_error "Failed to use root access"
    fi
    
    # Method 2: Instructions for manual fix
    print_status "Alternative method - Manual sudo configuration:"
    echo "1. If you have another user with sudo access, run:"
    echo "   sudo usermod -aG sudo $USER"
    echo ""
    echo "2. Or, if you can access root directly:"
    echo "   su - root"
    echo "   usermod -aG sudo $USER"
    echo "   exit"
    echo ""
    echo "3. Then log out and log back in, or run:"
    echo "   exec su - $USER"
    echo ""
    print_status "After fixing sudo access, run the install script again"
    
    return 1
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    fix_sudo_access
fi
