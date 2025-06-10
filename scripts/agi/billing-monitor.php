
#!/usr/bin/php
<?php
// AGI script to monitor ongoing calls and update charges

require_once('phpagi.php');

$db_host = 'localhost';
$db_user = 'asterisk';
$db_pass = getenv('DB_PASSWORD') ?: '';
$db_name = 'asterisk';

$agi = new AGI();
$call_id = $argv[1];

try {
    $pdo = new PDO("mysql:host=$db_host;dbname=$db_name", $db_user, $db_pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    while (true) {
        // Get call info
        $stmt = $pdo->prepare("
            SELECT ac.*, c.type, c.balance, r.rate, r.billing_increment 
            FROM active_calls ac 
            JOIN customers c ON ac.customer_id = c.id 
            JOIN rates r ON ac.rate_id = r.id 
            WHERE ac.call_id = ? AND ac.status = 'active'
        ");
        $stmt->execute([$call_id]);
        $call = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$call) {
            break; // Call ended or not found
        }
        
        // Calculate call duration
        $duration = time() - strtotime($call['start_time']);
        
        // Calculate current cost (in billing increments)
        $billing_seconds = ceil($duration / $call['billing_increment']) * $call['billing_increment'];
        $current_cost = ($billing_seconds / 60) * $call['rate'];
        
        // Update estimated cost
        $stmt = $pdo->prepare("
            UPDATE active_calls 
            SET estimated_cost = ? 
            WHERE call_id = ?
        ");
        $stmt->execute([$current_cost, $call_id]);
        
        // For prepaid customers, check if they still have balance
        if ($call['type'] === 'Prepaid') {
            $total_charged = $current_cost;
            if ($call['balance'] < $total_charged) {
                // Insufficient funds - hang up the call
                $agi->verbose("Insufficient funds for call $call_id, hanging up");
                $agi->hangup();
                break;
            }
        }
        
        // Sleep for billing increment
        sleep($call['billing_increment']);
    }
    
} catch (Exception $e) {
    $agi->verbose("Billing monitor error: " . $e->getMessage());
}
?>
