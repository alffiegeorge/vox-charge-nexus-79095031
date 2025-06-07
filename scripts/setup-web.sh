
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
    
    # Copy Nginx configuration
    sudo cp "$(dirname "$0")/../config/nginx-ibilling.conf" /etc/nginx/sites-available/ibilling

    # Enable the site
    sudo ln -sf /etc/nginx/sites-available/ibilling /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default

    # Test and restart Nginx
    sudo nginx -t
    sudo systemctl enable nginx
    sudo systemctl restart nginx
}

setup_web_stack() {
    setup_nodejs
    setup_frontend
    setup_nginx
    print_status "Web stack setup completed successfully"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_web_stack
fi
