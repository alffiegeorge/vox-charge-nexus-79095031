
#!/bin/bash

# Web setup script for iBilling
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/utils.sh"

setup_nodejs() {
    print_status "Installing Node.js and npm..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt install -y nodejs

    # Verify Node.js installation
    node_version=$(node --version)
    npm_version=$(npm --version)
    print_status "Node.js version: $node_version"
    print_status "npm version: $npm_version"
}

setup_frontend() {
    print_status "Setting up iBilling frontend..."
    
    # Check if we're already in the correct directory
    if [ "$(pwd)" = "/opt/billing/web" ] && [ -f "package.json" ]; then
        print_status "Already in correct directory with package.json"
        current_user=$(whoami)
        sudo chown -R "$current_user:$current_user" /opt/billing/web
    else
        print_error "Not in correct directory or package.json missing"
        return 1
    fi

    # Install npm dependencies
    print_status "Installing npm dependencies..."
    if npm install; then
        print_status "Dependencies installed successfully"
    else
        print_error "Failed to install dependencies"
        return 1
    fi

    # Build the project
    print_status "Building the project..."
    if npm run build; then
        print_status "Project built successfully"
    else
        print_error "Failed to build project"
        return 1
    fi
}

setup_backend_dependencies() {
    print_status "Setting up backend dependencies..."
    
    if [ -d "/opt/billing/web/backend" ] && [ -f "/opt/billing/web/backend/package.json" ]; then
        cd /opt/billing/web/backend
        print_status "Installing backend dependencies..."
        if npm install; then
            print_status "Backend dependencies installed successfully"
        else
            print_error "Failed to install backend dependencies"
            return 1
        fi
        cd /opt/billing/web
    else
        print_warning "Backend directory or package.json not found, skipping backend dependencies"
    fi
}

setup_nginx() {
    print_status "Configuring Nginx..."
    
    # Install Nginx if not present
    sudo apt update
    sudo apt install -y nginx
    
    # Clean existing Nginx configurations
    print_status "Cleaning existing Nginx configurations..."
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo rm -f /etc/nginx/sites-enabled/ibilling
    sudo rm -f /etc/nginx/sites-available/ibilling
    
    # Copy Nginx configuration
    config_file="$SCRIPT_DIR/../config/nginx-ibilling.conf"
    if [ -f "$config_file" ]; then
        sudo cp "$config_file" /etc/nginx/sites-available/ibilling
        print_status "Nginx configuration copied"
    else
        print_error "Nginx configuration file not found at $config_file"
        return 1
    fi

    # Enable the site
    sudo ln -sf /etc/nginx/sites-available/ibilling /etc/nginx/sites-enabled/

    # Test and reload Nginx
    if sudo nginx -t; then
        print_status "Nginx configuration test passed"
        sudo systemctl enable nginx
        sudo systemctl reload nginx
        print_status "Nginx reloaded successfully"
    else
        print_error "Nginx configuration test failed"
        return 1
    fi
}

setup_backend_service() {
    print_status "Setting up backend service..."
    
    # Check if backend service exists
    if sudo systemctl list-unit-files | grep -q ibilling-backend; then
        print_status "Restarting backend service..."
        sudo systemctl restart ibilling-backend
        
        # Wait a moment for the service to start
        sleep 3
        
        # Check service status
        if sudo systemctl is-active --quiet ibilling-backend; then
            print_status "✓ Backend service is running"
        else
            print_warning "⚠ Backend service failed to start, but continuing..."
        fi
    else
        print_warning "⚠ Backend service not found, skipping..."
    fi
}

fix_realtime_after_web_setup() {
    print_status "Applying final realtime authentication fixes..."
    
    # Get passwords from environment or prompt
    local mysql_root_password=${MYSQL_ROOT_PASSWORD:-""}
    local asterisk_db_password=${ASTERISK_DB_PASSWORD:-""}
    
    if [ -z "$mysql_root_password" ] || [ -z "$asterisk_db_password" ]; then
        print_warning "Database passwords not found in environment"
        print_status "Please run the realtime fix manually:"
        print_status "sudo ./scripts/fix-realtime-auth.sh <mysql_root_password> <asterisk_db_password>"
        return 0
    fi
    
    if [ -f "scripts/fix-realtime-auth.sh" ]; then
        chmod +x scripts/fix-realtime-auth.sh
        ./scripts/fix-realtime-auth.sh "$mysql_root_password" "$asterisk_db_password"
        
        # Test the fix
        if [ -f "scripts/test-realtime-complete.sh" ]; then
            chmod +x scripts/test-realtime-complete.sh
            ./scripts/test-realtime-complete.sh "$asterisk_db_password"
        fi
    fi
}

setup_web_stack() {
    print_status "Starting web stack setup..."
    
    setup_nodejs
    if [ $? -ne 0 ]; then
        print_error "Node.js setup failed"
        return 1
    fi
    
    setup_frontend
    if [ $? -ne 0 ]; then
        print_error "Frontend setup failed"
        return 1
    fi
    
    setup_backend_dependencies
    if [ $? -ne 0 ]; then
        print_error "Backend dependencies setup failed"
        return 1
    fi
    
    setup_nginx
    if [ $? -ne 0 ]; then
        print_error "Nginx setup failed"
        return 1
    fi
    
    setup_backend_service
    
    # Apply realtime fixes at the end
    fix_realtime_after_web_setup
    
    print_status "Web stack setup completed successfully"
    print_status "You can now access the application at http://your-server-ip"
    print_status ""
    print_status "If you encounter ODBC/realtime issues, run:"
    print_status "sudo ./scripts/fix-realtime-auth.sh <mysql_root_password> <asterisk_db_password>"
}

# Execute if run directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    setup_web_stack
fi
