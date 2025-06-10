
#!/usr/bin/php
<?php
// AGI script to finalize billing when call ends

require_once('phpagi.php');

$db_host = 'localhost';
$db_user = 'asterisk';
$db_pass = getenv('DB_PASSWORD') ?: '';
$db_name = 'asterisk';

$agi = new AGI();

$customer_id = $argv[1];
$dial_status = $argv[2];
$billable_seconds = $argv[3];

try {
    $pdo = new PDO("mysql:host=$db_host;dbname=$db_name", $db_user, $db_pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Get the call ID from channel variable
    $call_id = $agi->get_variable('UNIQUE_CALL_ID');
    
    // Get call and rate information
    $stmt = $pdo->prepare("
        SELECT ac.*, r.rate, r.connection_fee, r.minimum_duration, r.billing_increment, c.type 
        FROM active_calls ac 
        JOIN rates r ON ac.rate_id = r.id 
        JOIN customers c ON ac.customer_id = c.id 
        WHERE ac.call_id = ?
    ");
    $stmt->execute([$call_id]);
    $call = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$call) {
        $agi->verbose("Call record not found for call ID: $call_id");
        exit(1);
    }
    
    // Calculate final cost
    $duration = max($billable_seconds, $call['minimum_duration']);
    $billing_seconds = ceil($duration / $call['billing_increment']) * $call['billing_increment'];
    $call_cost = ($billing_seconds / 60) * $call['rate'];
    
    // Total cost includes connection fee (already charged for prepaid)
    $total_cost = $call_cost;
    if ($call['type'] === 'Postpaid') {
        $total_cost += $call['connection_fee'];
    }
    
    // Update customer balance
    if ($call['type'] === 'Prepaid') {
        // Deduct call cost (connection fee already deducted)
        $stmt = $pdo->prepare("
            UPDATE customers 
            SET balance = balance - ? 
            WHERE id = ?
        ");
        $stmt->execute([$call_cost, $customer_id]);
    } else {
        // Postpaid - add to negative balance
        $stmt = $pdo->prepare("
            UPDATE customers 
            SET balance = balance - ? 
            WHERE id = ?
        ");
        $stmt->execute([$total_cost, $customer_id]);
    }
    
    // Log billing transaction
    $stmt = $pdo->prepare("
        INSERT INTO billing_history 
        (customer_id, transaction_type, amount, description, call_id, processed_at) 
        VALUES (?, 'charge', ?, ?, ?, NOW())
    ");
    $stmt->execute([
        $customer_id, 
        $call_cost, 
        "Call charges - {$duration}s @ {$call['rate']}/min", 
        $call_id
    ]);
    
    // Update active call status
    $stmt = $pdo->prepare("
        UPDATE active_calls 
        SET status = 'completed', estimated_cost = ? 
        WHERE call_id = ?
    ");
    $stmt->execute([$total_cost, $call_id]);
    
    $agi->verbose("Call billing completed for customer $customer_id, total cost: $total_cost");
    
} catch (Exception $e) {
    $agi->verbose("Billing end error: " . $e->getMessage());
    exit(1);
}
?>
