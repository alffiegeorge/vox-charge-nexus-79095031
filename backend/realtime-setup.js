
const { createDatabasePool, executeQuery } = require('./database');

async function setupRealtimeTables() {
  try {
    console.log('Setting up Asterisk realtime tables...');
    
    // Initialize database connection first
    const dbConnected = await createDatabasePool();
    if (!dbConnected) {
      throw new Error('Failed to connect to database');
    }
    
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
    
    // Add columns to sip_credentials table if they don't exist
    const columnsToAdd = [
      { name: 'name', definition: "VARCHAR(50) NOT NULL DEFAULT ''" },
      { name: 'type', definition: "ENUM('friend', 'user', 'peer') DEFAULT 'friend'" },
      { name: 'host', definition: "VARCHAR(50) DEFAULT 'dynamic'" },
      { name: 'context', definition: "VARCHAR(50) DEFAULT 'from-internal'" },
      { name: 'disallow', definition: "VARCHAR(100) DEFAULT 'all'" },
      { name: 'allow', definition: "VARCHAR(100) DEFAULT 'ulaw,alaw,g722'" },
      { name: 'secret', definition: "VARCHAR(100)" }
    ];

    for (const column of columnsToAdd) {
      try {
        await executeQuery(`
          ALTER TABLE sip_credentials 
          ADD COLUMN IF NOT EXISTS ${column.name} ${column.definition}
        `);
      } catch (error) {
        if (error.code !== 'ER_DUP_FIELDNAME') {
          throw error;
        }
        // Column already exists, continue
      }
    }

    // Add indexes if they don't exist
    const indexesToAdd = [
      { name: 'idx_name', column: 'name' },
      { name: 'idx_sip_username', column: 'sip_username' }
    ];

    for (const index of indexesToAdd) {
      try {
        // Check if index exists
        const [rows] = await executeQuery(`
          SELECT COUNT(*) as count 
          FROM information_schema.statistics 
          WHERE table_schema = DATABASE() 
          AND table_name = 'sip_credentials' 
          AND index_name = ?
        `, [index.name]);

        if (rows[0].count === 0) {
          await executeQuery(`
            ALTER TABLE sip_credentials 
            ADD INDEX ${index.name} (${index.column})
          `);
        }
      } catch (error) {
        if (error.code !== 'ER_DUP_KEYNAME') {
          throw error;
        }
        // Index already exists, continue
      }
    }
    
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

// Allow this script to be run standalone
if (require.main === module) {
  setupRealtimeTables()
    .then(() => {
      console.log('Realtime tables setup completed');
      process.exit(0);
    })
    .catch((error) => {
      console.error('Failed to setup realtime tables:', error);
      process.exit(1);
    });
}

module.exports = { setupRealtimeTables };
