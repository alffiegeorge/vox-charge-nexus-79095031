
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
    
    # Create web directory if it doesn't exist
    sudo mkdir -p /opt/billing/web
    cd /opt/billing/web

    # Remove existing files if any
    sudo rm -rf ./* 2>/dev/null || true
    sudo rm -rf ./.* 2>/dev/null || true

    # Clone the repository
    print_status "Cloning repository..."
    if sudo git clone https://github.com/alffiegeorge/vox-charge-nexus-79095031.git .; then
        print_status "Repository cloned successfully"
    else
        print_error "Failed to clone repository"
        return 1
    fi

    # Set permissions for the current user
    current_user=$(whoami)
    sudo chown -R "$current_user:$current_user" /opt/billing/web

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
    
    setup_nginx
    if [ $? -ne 0 ]; then
        print_error "Nginx setup failed"
        return 1
    fi
    
    setup_backend_service
    
    print_status "Web stack setup completed successfully"
    print_status "You can now access the application at http://your-server-ip"
}

# Execute if run directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    setup_web_stack
fi
