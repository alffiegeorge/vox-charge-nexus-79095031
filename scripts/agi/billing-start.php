
#!/usr/bin/php
<?php
// AGI script to start billing for a call

require_once('phpagi.php');

$db_host = 'localhost';
$db_user = 'asterisk';
$db_pass = getenv('DB_PASSWORD') ?: '';
$db_name = 'asterisk';

$agi = new AGI();

$customer_id = $argv[1];
$destination = $argv[2];
$rate_info = $argv[3]; // rate,connection_fee,minimum_duration,billing_increment

try {
    $pdo = new PDO("mysql:host=$db_host;dbname=$db_name", $db_user, $db_pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Parse rate info
    list($rate, $connection_fee, $minimum_duration, $billing_increment) = explode(',', $rate_info);
    
    // Get rate ID
    $stmt = $pdo->prepare("
        SELECT id FROM rates 
        WHERE ? LIKE CONCAT(prefix, '%') 
        AND status = 'active'
        ORDER BY LENGTH(prefix) DESC 
        LIMIT 1
    ");
    $stmt->execute([$destination]);
    $rate_row = $stmt->fetch(PDO::FETCH_ASSOC);
    $rate_id = $rate_row['id'];
    
    // Generate unique call ID
    $call_id = uniqid('call_', true);
    $agi->set_variable('UNIQUE_CALL_ID', $call_id);
    
    // Insert active call record
    $stmt = $pdo->prepare("
        INSERT INTO active_calls 
        (call_id, customer_id, caller_id, called_number, rate_id, start_time, status) 
        VALUES (?, ?, ?, ?, ?, NOW(), 'active')
    ");
    $stmt->execute([
        $call_id, 
        $customer_id, 
        $agi->get_variable('CALLERID(num)'), 
        $destination, 
        $rate_id
    ]);
    
    // Charge connection fee immediately for prepaid
    $stmt = $pdo->prepare("SELECT type FROM customers WHERE id = ?");
    $stmt->execute([$customer_id]);
    $customer_type = $stmt->fetchColumn();
    
    if ($customer_type === 'Prepaid' && $connection_fee > 0) {
        // Deduct connection fee
        $stmt = $pdo->prepare("
            UPDATE customers 
            SET balance = balance - ? 
            WHERE id = ?
        ");
        $stmt->execute([$connection_fee, $customer_id]);
        
        // Log billing transaction
        $stmt = $pdo->prepare("
            INSERT INTO billing_history 
            (customer_id, transaction_type, amount, description, call_id, processed_at) 
            VALUES (?, 'charge', ?, 'Connection fee', ?, NOW())
        ");
        $stmt->execute([$customer_id, $connection_fee, $call_id]);
    }
    
    $agi->verbose("Call billing started for customer $customer_id, call ID: $call_id");
    
} catch (Exception $e) {
    $agi->verbose("Billing start error: " . $e->getMessage());
    exit(1);
}
?>
