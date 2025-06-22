
#!/bin/bash

# Add sample DIDs to the database
source "$(dirname "$0")/utils.sh"

add_sample_dids() {
    local mysql_root_password=${MYSQL_ROOT_PASSWORD:-""}
    local asterisk_db_password=${DB_PASSWORD:-""}
    
    if [ -z "$asterisk_db_password" ]; then
        print_error "DB_PASSWORD environment variable not set"
        return 1
    fi
    
    print_status "Adding sample DIDs to database..."
    
    # Connect to MySQL using asterisk user and insert sample data
    mysql -u asterisk -p"${asterisk_db_password}" asterisk << 'EOF'
INSERT IGNORE INTO did_numbers (number, customer_name, country, rate, type, status, notes) VALUES
('+1-555-0101', 'Unassigned', 'USA', 5.00, 'Local', 'Available', 'Local number for testing'),
('+1-555-0102', 'Unassigned', 'USA', 5.00, 'Local', 'Available', 'Local number for testing'),
('+1-800-555-0103', 'Unassigned', 'USA', 15.00, 'Toll-Free', 'Available', 'Toll-free number'),
('+44-20-7946-0958', 'Unassigned', 'UK', 8.00, 'Local', 'Available', 'London number'),
('+678-555-0104', 'Unassigned', 'Vanuatu', 3.00, 'Local', 'Available', 'Local Vanuatu number'),
('+678-555-0105', 'Unassigned', 'Vanuatu', 3.00, 'Local', 'Available', 'Local Vanuatu number');
EOF

    if [ $? -eq 0 ]; then
        print_status "✓ Sample DIDs added successfully"
    else
        print_status "❌ Failed to add sample DIDs"
        return 1
    fi
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    add_sample_dids
fi
