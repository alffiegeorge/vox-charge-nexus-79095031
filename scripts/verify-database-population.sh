
#!/bin/bash

# Verify database population script
source "$(dirname "$0")/utils.sh"

verify_population() {
    local mysql_root_password=$1
    
    if [ -z "$mysql_root_password" ]; then
        echo "Enter MySQL root password:"
        read -s mysql_root_password
    fi
    
    print_status "Verifying database population..."
    
    # Test database connection
    if ! mysql -u root -p"${mysql_root_password}" -e "USE asterisk; SELECT 1;" >/dev/null 2>&1; then
        print_error "Cannot connect to asterisk database"
        return 1
    fi
    
    print_status "✓ Database connection successful"
    
    # Check each table has data
    local tables=(
        "customers:8"
        "rates:20"
        "did_numbers:10"
        "admin_users:3"
        "trunks:4"
        "routes:5"
        "sipusers:4"
        "voicemail:4"
        "cdr:10"
        "invoices:6"
        "invoice_items:12"
        "payments:5"
        "sms_messages:6"
        "sms_templates:7"
        "support_tickets:5"
        "audit_logs:5"
        "system_settings:12"
    )
    
    local all_good=true
    
    for table_info in "${tables[@]}"; do
        IFS=':' read -r table expected_min <<< "$table_info"
        
        count=$(mysql -u root -p"${mysql_root_password}" asterisk -sN -e "SELECT COUNT(*) FROM $table;")
        
        if [ "$count" -ge "$expected_min" ]; then
            print_status "✓ $table: $count records (expected minimum: $expected_min)"
        else
            print_error "✗ $table: $count records (expected minimum: $expected_min)"
            all_good=false
        fi
    done
    
    if [ "$all_good" = true ]; then
        print_status "✅ All tables properly populated!"
        
        # Show sample customer data
        print_status "Sample customer data:"
        mysql -u root -p"${mysql_root_password}" asterisk -e "
            SELECT id, name, email, type, balance, status 
            FROM customers 
            ORDER BY id 
            LIMIT 5;
        "
        
        # Show sample CDR data
        print_status "Sample CDR data:"
        mysql -u root -p"${mysql_root_password}" asterisk -e "
            SELECT calldate, src, dst, duration, billsec, disposition, accountcode 
            FROM cdr 
            ORDER BY calldate DESC 
            LIMIT 5;
        "
        
        return 0
    else
        print_error "Some tables are not properly populated!"
        return 1
    fi
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    verify_population "$1"
fi
