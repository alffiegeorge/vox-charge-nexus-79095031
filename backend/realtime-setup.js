
const { executeQuery } = require('./database');

async function setupRealtimeTables() {
  try {
    console.log('Setting up Asterisk realtime tables...');
    
    // Create extensions table for dynamic dialplan
    await executeQuery(`
      CREATE TABLE IF NOT EXISTS extensions (
        id INT AUTO_INCREMENT PRIMARY KEY,
        context VARCHAR(40) NOT NULL DEFAULT '',
        exten VARCHAR(40) NOT NULL DEFAULT '',
        priority INT NOT NULL DEFAULT 0,
        app VARCHAR(40) NOT NULL DEFAULT '',
        appdata VARCHAR(256) NOT NULL DEFAULT '',
        UNIQUE KEY context_exten_priority (context, exten, priority)
      )
    `);
    
    // Create voicemail_users table
    await executeQuery(`
      CREATE TABLE IF NOT EXISTS voicemail_users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        customer_id VARCHAR(50) NOT NULL,
        context VARCHAR(50) NOT NULL DEFAULT 'default',
        mailbox VARCHAR(50) NOT NULL,
        password VARCHAR(20) NOT NULL,
        fullname VARCHAR(50) NOT NULL,
        email VARCHAR(100),
        pager VARCHAR(100),
        options VARCHAR(100),
        stamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY mailbox_context (mailbox, context),
        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
      )
    `);
    
    // Create DIDs table
    await executeQuery(`
      CREATE TABLE IF NOT EXISTS dids (
        id INT AUTO_INCREMENT PRIMARY KEY,
        number VARCHAR(20) NOT NULL UNIQUE,
        customer_id VARCHAR(50) NOT NULL,
        description VARCHAR(100),
        monthly_cost DECIMAL(10,2) DEFAULT 0.00,
        status ENUM('active', 'inactive') DEFAULT 'active',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
      )
    `);
    
    // Update sip_credentials table to work with Asterisk realtime
    await executeQuery(`
      ALTER TABLE sip_credentials 
      ADD COLUMN IF NOT EXISTS name VARCHAR(50) NOT NULL DEFAULT '',
      ADD COLUMN IF NOT EXISTS type ENUM('friend', 'user', 'peer') DEFAULT 'friend',
      ADD COLUMN IF NOT EXISTS host VARCHAR(50) DEFAULT 'dynamic',
      ADD COLUMN IF NOT EXISTS context VARCHAR(50) DEFAULT 'from-internal',
      ADD COLUMN IF NOT EXISTS disallow VARCHAR(100) DEFAULT 'all',
      ADD COLUMN IF NOT EXISTS allow VARCHAR(100) DEFAULT 'ulaw,alaw,g722',
      ADD COLUMN IF NOT EXISTS secret VARCHAR(100),
      ADD INDEX idx_name (name),
      ADD INDEX idx_sip_username (sip_username)
    `);
    
    // Set name field to sip_username for existing records
    await executeQuery(`
      UPDATE sip_credentials 
      SET name = sip_username, secret = sip_password 
      WHERE name = '' OR name IS NULL
    `);
    
    console.log('✓ Asterisk realtime tables created successfully');
    
  } catch (error) {
    console.error('Error setting up realtime tables:', error);
    throw error;
  }
}

module.exports = { setupRealtimeTables };
