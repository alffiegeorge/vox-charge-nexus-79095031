
const { executeQuery } = require('../database');

async function setupDIDTables() {
  try {
    console.log('Setting up DID tables...');

    // Create DID routes table for storing routing information
    await executeQuery(`
      CREATE TABLE IF NOT EXISTS did_routes (
        id INT(11) NOT NULL AUTO_INCREMENT,
        did_number VARCHAR(20) NOT NULL,
        destination_type ENUM('sip', 'queue', 'ivr', 'voicemail') DEFAULT 'sip',
        destination_value VARCHAR(100) NOT NULL,
        priority INT(11) DEFAULT 1,
        active TINYINT(1) DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY unique_did_route (did_number),
        INDEX did_number_idx (did_number),
        INDEX destination_idx (destination_type, destination_value)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8
    `);

    console.log('✓ DID routes table created');

    // Ensure did_numbers table has all required columns
    await executeQuery(`
      ALTER TABLE did_numbers 
      ADD COLUMN IF NOT EXISTS customer_id VARCHAR(20) DEFAULT NULL,
      ADD INDEX IF NOT EXISTS customer_idx (customer_id)
    `);

    console.log('✓ DID numbers table updated');

    // Create sample DIDs if none exist
    const existingDids = await executeQuery('SELECT COUNT(*) as count FROM did_numbers');
    
    if (existingDids[0].count === 0) {
      console.log('Creating sample DIDs...');
      
      const sampleDids = [
        ['+1-555-0101', 'Unassigned', 'USA', '5.00', 'Local', 'Available', null, 'Local number for testing'],
        ['+1-555-0102', 'Unassigned', 'USA', '5.00', 'Local', 'Available', null, 'Local number for testing'],
        ['+1-800-555-0103', 'Unassigned', 'USA', '15.00', 'Toll-Free', 'Available', null, 'Toll-free number'],
        ['+44-20-7946-0958', 'Unassigned', 'UK', '8.00', 'Local', 'Available', null, 'London number'],
        ['+678-555-0104', 'Unassigned', 'Vanuatu', '3.00', 'Local', 'Available', null, 'Local Vanuatu number'],
        ['+678-555-0105', 'Unassigned', 'Vanuatu', '3.00', 'Local', 'Available', null, 'Local Vanuatu number']
      ];

      for (const did of sampleDids) {
        await executeQuery(`
          INSERT IGNORE INTO did_numbers (number, customer_name, country, rate, type, status, customer_id, notes, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
        `, did);
      }

      console.log('✓ Sample DIDs created');
    }

    console.log('DID tables setup completed');
    
  } catch (error) {
    console.error('Error setting up DID tables:', error);
    throw error;
  }
}

module.exports = { setupDIDTables };
