const AsteriskManager = require('asterisk-manager');
const { executeQuery } = require('./database');

class AsteriskIntegration {
  constructor() {
    this.ami = null;
    this.isConnected = false;
    this.config = {
      port: process.env.ASTERISK_AMI_PORT || 5038,
      host: process.env.ASTERISK_HOST || 'localhost',
      username: process.env.ASTERISK_USERNAME || 'admin',
      password: process.env.ASTERISK_SECRET || 'admin'
    };
  }

  async connect() {
    try {
      console.log('Connecting to Asterisk AMI...');
      console.log(`Host: ${this.config.host}:${this.config.port}`);
      console.log(`Username: ${this.config.username}`);
      
      this.ami = new AsteriskManager(
        this.config.port,
        this.config.host,
        this.config.username,
        this.config.password,
        true // Enable events
      );

      return new Promise((resolve, reject) => {
        this.ami.on('connect', () => {
          console.log('✓ Connected to Asterisk AMI');
          this.isConnected = true;
          resolve(true);
        });

        this.ami.on('error', (error) => {
          console.error('❌ Asterisk AMI connection error:', error);
          this.isConnected = false;
          reject(error);
        });

        this.ami.on('close', () => {
          console.log('Asterisk AMI connection closed');
          this.isConnected = false;
        });

        // Set connection timeout
        setTimeout(() => {
          if (!this.isConnected) {
            reject(new Error('AMI connection timeout'));
          }
        }, 10000);
      });
    } catch (error) {
      console.error('Failed to connect to Asterisk AMI:', error);
      throw error;
    }
  }

  async ensureConnection() {
    if (!this.isConnected || !this.ami) {
      await this.connect();
    }
  }

  async createPJSIPEndpoint(customerId, customerData) {
    try {
      await this.ensureConnection();
      
      console.log(`Creating PJSIP endpoint for customer ${customerId}...`);
      
      // Generate SIP credentials
      const sipUsername = customerId.toLowerCase();
      const sipPassword = this.generateSipPassword();
      const sipDomain = process.env.SIP_DOMAIN || 'localhost';
      
      // Store SIP credentials in database
      await this.storeSipCredentials(customerId, sipUsername, sipPassword, sipDomain);
      
      // Create PJSIP endpoint in realtime table
      await executeQuery(`
        INSERT INTO ps_endpoints (id, transport, aors, auth, context, disallow, allow, 
                                 direct_media, ice_support, force_rport, rewrite_contact, 
                                 rtp_symmetric, send_rpid, send_pai, trust_id_inbound, callerid)
        VALUES (?, 'transport-udp', ?, ?, 'from-internal', 'all', 'ulaw,alaw,g722,g729',
                'no', 'yes', 'yes', 'yes', 'yes', 'yes', 'yes', 'yes', ?)
        ON DUPLICATE KEY UPDATE
        aors = VALUES(aors), auth = VALUES(auth), callerid = VALUES(callerid)
      `, [sipUsername, sipUsername, sipUsername, `"${customerData.name}" <${sipUsername}>`]);

      // Create PJSIP auth in realtime table
      await executeQuery(`
        INSERT INTO ps_auths (id, auth_type, username, password)
        VALUES (?, 'userpass', ?, ?)
        ON DUPLICATE KEY UPDATE
        username = VALUES(username), password = VALUES(password)
      `, [sipUsername, sipUsername, sipPassword]);

      // Create PJSIP AOR in realtime table
      await executeQuery(`
        INSERT INTO ps_aors (id, max_contacts, remove_existing, qualify_frequency)
        VALUES (?, 1, 'yes', 60)
        ON DUPLICATE KEY UPDATE
        max_contacts = VALUES(max_contacts), remove_existing = VALUES(remove_existing)
      `, [sipUsername]);
      
      // Reload PJSIP configuration
      await this.reloadPJSIP();
      
      console.log(`✓ PJSIP endpoint created for customer ${customerId}`);
      console.log(`SIP Username: ${sipUsername}`);
      console.log(`SIP Domain: ${sipDomain}`);
      
      return {
        sipUsername,
        sipPassword,
        sipDomain,
        endpoint: sipUsername
      };
      
    } catch (error) {
      console.error(`Failed to create PJSIP endpoint for customer ${customerId}:`, error);
      throw error;
    }
  }

  generateSipPassword() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let password = '';
    for (let i = 0; i < 12; i++) {
      password += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return password;
  }

  async storeSipCredentials(customerId, username, password, domain) {
    try {
      // Create sip_credentials table if it doesn't exist
      await executeQuery(`
        CREATE TABLE IF NOT EXISTS sip_credentials (
          id INT AUTO_INCREMENT PRIMARY KEY,
          customer_id VARCHAR(50) NOT NULL UNIQUE,
          sip_username VARCHAR(50) NOT NULL UNIQUE,
          sip_password VARCHAR(100) NOT NULL,
          sip_domain VARCHAR(100) NOT NULL,
          status ENUM('active', 'inactive', 'suspended') DEFAULT 'active',
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
        )
      `);

      // Insert SIP credentials
      await executeQuery(
        'INSERT INTO sip_credentials (customer_id, sip_username, sip_password, sip_domain) VALUES (?, ?, ?, ?)',
        [customerId, username, password, domain]
      );

      console.log(`✓ SIP credentials stored for customer ${customerId}`);
    } catch (error) {
      console.error('Failed to store SIP credentials:', error);
      throw error;
    }
  }

  async reloadPJSIP() {
    try {
      if (!this.isConnected || !this.ami) {
        console.log('⚠ AMI not connected, skipping PJSIP reload');
        return;
      }

      console.log('Reloading PJSIP configuration...');
      
      return new Promise((resolve, reject) => {
        this.ami.action('Command', {
          Command: 'pjsip reload'
        }, (error, response) => {
          if (error) {
            console.error('Failed to reload PJSIP:', error);
            reject(error);
          } else {
            console.log('✓ PJSIP configuration reloaded');
            resolve(response);
          }
        });
      });
    } catch (error) {
      console.error('Failed to reload PJSIP:', error);
      throw error;
    }
  }

  async getSipCredentials(customerId) {
    try {
      const [credentials] = await executeQuery(
        'SELECT * FROM sip_credentials WHERE customer_id = ?',
        [customerId]
      );
      
      return credentials[0] || null;
    } catch (error) {
      console.error('Failed to get SIP credentials:', error);
      throw error;
    }
  }

  async listEndpoints() {
    try {
      await this.ensureConnection();
      
      return new Promise((resolve, reject) => {
        this.ami.action('Command', {
          Command: 'pjsip show endpoints'
        }, (error, response) => {
          if (error) {
            reject(error);
          } else {
            resolve(response);
          }
        });
      });
    } catch (error) {
      console.error('Failed to list endpoints:', error);
      throw error;
    }
  }

  async deleteEndpoint(customerId) {
    try {
      const credentials = await this.getSipCredentials(customerId);
      if (!credentials) {
        console.log(`No SIP credentials found for customer ${customerId}`);
        return;
      }

      const username = credentials.sip_username;
      
      // Delete from PJSIP realtime tables
      await executeQuery('DELETE FROM ps_endpoints WHERE id = ?', [username]);
      await executeQuery('DELETE FROM ps_auths WHERE id = ?', [username]);
      await executeQuery('DELETE FROM ps_aors WHERE id = ?', [username]);
      await executeQuery('DELETE FROM ps_contacts WHERE endpoint = ?', [username]);

      // Delete SIP credentials
      await executeQuery('DELETE FROM sip_credentials WHERE customer_id = ?', [customerId]);

      // Reload PJSIP
      await this.reloadPJSIP();
      
      console.log(`✓ Deleted PJSIP endpoint for customer ${customerId}`);
    } catch (error) {
      console.error(`Failed to delete endpoint for customer ${customerId}:`, error);
      throw error;
    }
  }
}

module.exports = new AsteriskIntegration();
