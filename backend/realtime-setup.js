
const { createDatabasePool, executeQuery } = require('./database');

async function setupRealtimeTables() {
  try {
    console.log('Setting up Asterisk realtime tables...');
    
    // Initialize database connection first
    const dbConnected = await createDatabasePool();
    if (!dbConnected) {
      throw new Error('Failed to connect to database');
    }
    
    // Create PJSIP endpoints table
    await executeQuery(`
      CREATE TABLE IF NOT EXISTS ps_endpoints (
        id VARCHAR(40) NOT NULL PRIMARY KEY,
        transport VARCHAR(40),
        aors VARCHAR(200),
        auth VARCHAR(40),
        context VARCHAR(40) DEFAULT 'from-internal',
        disallow VARCHAR(200) DEFAULT 'all',
        allow VARCHAR(200) DEFAULT 'ulaw,alaw,g722',
        direct_media ENUM('yes','no') DEFAULT 'no',
        connected_line_method ENUM('invite','update') DEFAULT 'invite',
        direct_media_method ENUM('invite','update') DEFAULT 'invite',
        direct_media_glare_mitigation ENUM('none','outgoing','incoming') DEFAULT 'none',
        disable_direct_media_on_nat ENUM('yes','no') DEFAULT 'no',
        dtmf_mode ENUM('rfc4733','inband','info','auto','auto_info') DEFAULT 'rfc4733',
        ice_support ENUM('yes','no') DEFAULT 'yes',
        force_rport ENUM('yes','no') DEFAULT 'yes',
        rewrite_contact ENUM('yes','no') DEFAULT 'yes',
        rtp_symmetric ENUM('yes','no') DEFAULT 'yes',
        send_rpid ENUM('yes','no') DEFAULT 'yes',
        send_pai ENUM('yes','no') DEFAULT 'yes',
        trust_id_inbound ENUM('yes','no') DEFAULT 'yes',
        callerid VARCHAR(40)
      )
    `);
    
    // Create PJSIP auths table
    await executeQuery(`
      CREATE TABLE IF NOT EXISTS ps_auths (
        id VARCHAR(40) NOT NULL PRIMARY KEY,
        auth_type ENUM('userpass','md5') DEFAULT 'userpass',
        password VARCHAR(80),
        username VARCHAR(40),
        realm VARCHAR(40)
      )
    `);
    
    // Create PJSIP aors table
    await executeQuery(`
      CREATE TABLE IF NOT EXISTS ps_aors (
        id VARCHAR(40) NOT NULL PRIMARY KEY,
        contact VARCHAR(255),
        default_expiration INT DEFAULT 3600,
        mailboxes VARCHAR(80),
        max_contacts INT DEFAULT 1,
        minimum_expiration INT DEFAULT 60,
        remove_existing ENUM('yes','no') DEFAULT 'yes',
        qualify_frequency INT DEFAULT 0,
        authenticate_qualify ENUM('yes','no') DEFAULT 'no'
      )
    `);
    
    // Create PJSIP contacts table
    await executeQuery(`
      CREATE TABLE IF NOT EXISTS ps_contacts (
        id VARCHAR(40) NOT NULL PRIMARY KEY,
        uri VARCHAR(511),
        expiration_time BIGINT,
        qualify_frequency INT DEFAULT 0,
        outbound_proxy VARCHAR(40),
        path TEXT,
        user_agent VARCHAR(255),
        qualify_timeout DECIMAL(3,1),
        reg_server VARCHAR(20),
        authenticate_qualify ENUM('yes','no') DEFAULT 'no',
        via_addr VARCHAR(40),
        via_port INT DEFAULT 0,
        call_id VARCHAR(255),
        endpoint VARCHAR(40),
        prune_on_boot ENUM('yes','no') DEFAULT 'no'
      )
    `);
    
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
