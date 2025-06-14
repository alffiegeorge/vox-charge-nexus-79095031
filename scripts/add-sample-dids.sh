
#!/bin/bash

# Add sample DIDs to the database
source "$(dirname "$0")/utils.sh"

add_sample_dids() {
    print_status "Adding sample DIDs to database..."
    
    # Connect to MySQL and insert sample data
    mysql -u ibilling -p"${DB_PASSWORD}" ibilling_db << 'EOF'
INSERT IGNORE INTO dids (number, customer_name, country, rate, type, status, notes) VALUES
('+1-555-0101', 'Unassigned', 'USA', 5.00, 'Local', 'Available', 'Local number for testing'),
('+1-555-0102', 'Unassigned', 'USA', 5.00, 'Local', 'Available', 'Local number for testing'),
('+1-800-555-0103', 'Unassigned', 'USA', 15.00, 'Toll-Free', 'Available', 'Toll-free number'),
('+44-20-7946-0958', 'Unassigned', 'UK', 8.00, 'Local', 'Available', 'London number'),
('+678-555-0104', 'Unassigned', 'Vanuatu', 3.00, 'Local', 'Available', 'Local Vanuatu number'),
('+678-555-0105', 'Unassigned', 'Vanuatu', 3.00, 'Local', 'Available', 'Local Vanuatu number');

INSERT IGNORE INTO trunks (name, provider, sip_server, username, max_channels, status, quality, notes) VALUES
('Primary-SIP-Trunk', 'VoIP Provider A', 'sip.provider-a.com', 'user123', 30, 'Active', 'Good', 'Primary trunk for outbound calls'),
('Backup-SIP-Trunk', 'VoIP Provider B', 'sip.provider-b.com', 'backup456', 20, 'Standby', 'Fair', 'Backup trunk for failover'),
('Local-Trunk', 'Local Telco', 'sip.local-telco.vu', 'local789', 15, 'Active', 'Excellent', 'Local carrier trunk');

INSERT IGNORE INTO routes (pattern, destination, trunk_name, priority, status, notes) VALUES
('_678XXXXXXX', 'Local', 'Local-Trunk', 1, 'Active', 'Route local Vanuatu calls to local trunk'),
('_1XXXXXXXXXX', 'USA', 'Primary-SIP-Trunk', 2, 'Active', 'Route USA calls to primary trunk'),
('_44XXXXXXXXX', 'UK', 'Primary-SIP-Trunk', 3, 'Active', 'Route UK calls to primary trunk'),
('_X.', 'International', 'Primary-SIP-Trunk', 10, 'Active', 'Default route for all other calls');
EOF

    if [ $? -eq 0 ]; then
        print_status "✓ Sample DIDs, trunks, and routes added successfully"
    else
        print_status "❌ Failed to add sample data"
        return 1
    fi
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ -z "$DB_PASSWORD" ]; then
        echo "Please set DB_PASSWORD environment variable"
        exit 1
    fi
    add_sample_dids
fi
