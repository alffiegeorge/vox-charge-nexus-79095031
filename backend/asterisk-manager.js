
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
      
      // Create PJSIP endpoint configuration
      const endpointConfig = {
        type: 'endpoint',
        context: 'from-internal',
        disallow: 'all',
        allow: 'ulaw,alaw,g722,g729',
        auth: sipUsername,
        aors: sipUsername,
        direct_media: 'no',
        ice_support: 'yes',
        force_rport: 'yes',
        rewrite_contact: 'yes',
        rtp_symmetric: 'yes',
        send_rpid: 'yes',
        send_pai: 'yes',
        trust_id_inbound: 'yes',
        callerid: `"${customerData.name}" <${sipUsername}>`
      };

      // Create AUTH configuration
      const authConfig = {
        type: 'auth',
        auth_type: 'userpass',
        username: sipUsername,
        password: sipPassword
      };

      // Create AOR configuration
      const aorConfig = {
        type: 'aor',
        max_contacts: '1',
        remove_existing: 'yes',
        qualify_frequency: '60'
      };

      // Store SIP credentials in database
      await this.storeSipCredentials(customerId, sipUsername, sipPassword, sipDomain);
      
      // Write configurations to Asterisk
      await this.writePJSIPConfig(sipUsername, endpointConfig, authConfig, aorConfig);
      
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

  async writePJSIPConfig(username, endpointConfig, authConfig, aorConfig) {
    try {
      // In a real implementation, you would write to Asterisk configuration files
      // For now, we'll use AMI commands to add the configuration dynamically
      
      // Note: Dynamic PJSIP configuration requires Asterisk realtime
      // This is a simplified version - in production you'd want to write to
      // pjsip.conf or use Asterisk realtime with database backend
      
      console.log(`Writing PJSIP configuration for ${username}...`);
      console.log('Endpoint config:', endpointConfig);
      console.log('Auth config:', authConfig);
      console.log('AOR config:', aorConfig);
      
      // For demonstration, we'll store in our database which can be read by Asterisk realtime
      await this.storeAsteriskConfig(username, 'endpoint', endpointConfig);
      await this.storeAsteriskConfig(username, 'auth', authConfig);
      await this.storeAsteriskConfig(username, 'aor', aorConfig);
      
    } catch (error) {
      console.error('Failed to write PJSIP configuration:', error);
      throw error;
    }
  }

  async storeAsteriskConfig(objectName, objectType, config) {
    try {
      // Create asterisk_config table for realtime configuration
      await executeQuery(`
        CREATE TABLE IF NOT EXISTS asterisk_config (
          id INT AUTO_INCREMENT PRIMARY KEY,
          object_name VARCHAR(50) NOT NULL,
          object_type VARCHAR(20) NOT NULL,
          config_key VARCHAR(50) NOT NULL,
          config_value VARCHAR(255) NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          INDEX idx_object (object_name, object_type),
          UNIQUE KEY unique_config (object_name, object_type, config_key)
        )
      `);

      // Delete existing config for this object
      await executeQuery(
        'DELETE FROM asterisk_config WHERE object_name = ? AND object_type = ?',
        [objectName, objectType]
      );

      // Insert new configuration
      for (const [key, value] of Object.entries(config)) {
        await executeQuery(
          'INSERT INTO asterisk_config (object_name, object_type, config_key, config_value) VALUES (?, ?, ?, ?)',
          [objectName, objectType, key, value]
        );
      }

      console.log(`✓ Stored ${objectType} configuration for ${objectName}`);
    } catch (error) {
      console.error('Failed to store Asterisk configuration:', error);
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
      
      // Delete from asterisk_config table
      await executeQuery(
        'DELETE FROM asterisk_config WHERE object_name = ?',
        [username]
      );

      // Delete SIP credentials
      await executeQuery(
        'DELETE FROM sip_credentials WHERE customer_id = ?',
        [customerId]
      );

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
