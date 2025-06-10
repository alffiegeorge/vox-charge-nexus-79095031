
#!/usr/bin/php
<?php
// AGI script to check if customer has sufficient balance for the call

// Include AGI library
require_once('phpagi.php');

// Database configuration
$db_host = 'localhost';
$db_user = 'asterisk';
$db_pass = getenv('DB_PASSWORD') ?: '';
$db_name = 'asterisk';

// Create AGI instance
$agi = new AGI();

// Get parameters
$customer_id = $argv[1];
$destination = $argv[2];

try {
    // Connect to database
    $pdo = new PDO("mysql:host=$db_host;dbname=$db_name", $db_user, $db_pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Get customer info
    $stmt = $pdo->prepare("SELECT balance, type, credit_limit FROM customers WHERE id = ?");
    $stmt->execute([$customer_id]);
    $customer = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$customer) {
        $agi->set_variable('BILLINGRESULT', 'CUSTOMER_NOT_FOUND');
        exit(1);
    }
    
    // Get rate for destination
    $stmt = $pdo->prepare("
        SELECT rate, connection_fee, minimum_duration 
        FROM rates 
        WHERE ? LIKE CONCAT(prefix, '%') 
        AND status = 'active'
        ORDER BY LENGTH(prefix) DESC 
        LIMIT 1
    ");
    $stmt->execute([$destination]);
    $rate = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$rate) {
        $agi->set_variable('BILLINGRESULT', 'NO_RATE_FOUND');
        exit(1);
    }
    
    // Calculate minimum cost (connection fee + minimum duration)
    $min_cost = $rate['connection_fee'] + (($rate['minimum_duration'] / 60) * $rate['rate']);
    
    // Check balance for prepaid customers
    if ($customer['type'] === 'Prepaid') {
        if ($customer['balance'] < $min_cost) {
            $agi->set_variable('BILLINGRESULT', 'INSUFFICIENT_FUNDS');
            exit(1);
        }
    } else {
        // Postpaid - check credit limit
        $current_usage = $customer['balance'] * -1; // Negative balance for postpaid
        if (($current_usage + $min_cost) > $customer['credit_limit']) {
            $agi->set_variable('BILLINGRESULT', 'CREDIT_LIMIT_EXCEEDED');
            exit(1);
        }
    }
    
    $agi->set_variable('BILLINGRESULT', 'AUTHORIZED');
    
} catch (Exception $e) {
    $agi->verbose("Billing check error: " . $e->getMessage());
    $agi->set_variable('BILLINGRESULT', 'SYSTEM_ERROR');
    exit(1);
}
?>
