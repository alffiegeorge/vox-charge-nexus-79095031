
#!/bin/bash

# Web setup script for iBilling
source "$(dirname "$0")/utils.sh"

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
    cd /opt/billing/web

    # Remove existing files if any
    sudo rm -rf ./*

    # Clone the repository
    sudo git clone https://github.com/alffiegeorge/vox-charge-nexus-79095031 .

    # Set permissions for the current user
    sudo chown -R $USER:$USER /opt/billing/web

    # Install npm dependencies
    npm install

    # Build the project
    npm run build
}

setup_nginx() {
    print_status "Configuring Nginx..."
    
    # Clean existing Nginx configurations
    print_status "Cleaning existing Nginx configurations..."
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo rm -f /etc/nginx/sites-enabled/ibilling
    sudo rm -f /etc/nginx/sites-available/ibilling
    
    # Copy Nginx configuration
    sudo cp "$(dirname "$0")/../config/nginx-ibilling.conf" /etc/nginx/sites-available/ibilling

    # Enable the site
    sudo ln -sf /etc/nginx/sites-available/ibilling /etc/nginx/sites-enabled/

    # Test and reload Nginx
    sudo nginx -t
    if [ $? -eq 0 ]; then
        print_status "Nginx configuration test passed"
        sudo systemctl enable nginx
        sudo systemctl reload nginx
        print_status "Nginx reloaded successfully"
    else
        print_status "Nginx configuration test failed"
        exit 1
    fi
}

restart_backend_service() {
    print_status "Restarting backend service..."
    
    # Restart the backend service
    sudo systemctl restart ibilling-backend
    
    # Wait a moment for the service to start
    sleep 3
    
    # Check and display service status
    print_status "Checking backend service status..."
    sudo systemctl status ibilling-backend --no-pager -l
    
    # Verify if service is active
    if sudo systemctl is-active --quiet ibilling-backend; then
        print_status "✓ Backend service is running"
    else
        print_status "✗ Backend service failed to start"
        exit 1
    fi
}

setup_web_stack() {
    setup_nodejs
    setup_frontend
    setup_nginx
    restart_backend_service
    print_status "Web stack setup completed successfully"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_web_stack
fi
