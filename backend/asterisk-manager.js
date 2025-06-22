
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
      console.log(`Creating PJSIP endpoint for customer ${customerId}...`);
      
      // Generate SIP credentials
      const sipUsername = customerId.toLowerCase();
      const sipPassword = this.generateSipPassword();
      const sipDomain = process.env.SIP_DOMAIN || 'localhost';
      
      console.log(`Generated SIP credentials - Username: ${sipUsername}, Domain: ${sipDomain}`);
      
      // First, ensure the realtime tables exist
      await this.ensureRealtimeTables();
      
      // Store SIP credentials in database first
      await this.storeSipCredentials(customerId, sipUsername, sipPassword, sipDomain);
      
      // Create PJSIP endpoint in realtime table with correct schema
      await executeQuery(`
        INSERT INTO ps_endpoints (id, transport, aors, auth, context, disallow, allow, 
                                 direct_media, ice_support, force_rport, 
                                 rtp_symmetric, send_rpid, send_pai, trust_id_inbound, callerid)
        VALUES (?, 'transport-udp', ?, ?, 'from-internal', 'all', 'ulaw,alaw,g722,g729',
                'no', 'yes', 'yes', 'yes', 'yes', 'yes', 'yes', ?)
        ON DUPLICATE KEY UPDATE
        aors = VALUES(aors), auth = VALUES(auth), callerid = VALUES(callerid)
      `, [sipUsername, sipUsername, sipUsername, `"${customerData.name}" <${sipUsername}>`]);

      console.log('✓ PJSIP endpoint created in ps_endpoints table');

      // Create PJSIP auth in realtime table
      await executeQuery(`
        INSERT INTO ps_auths (id, auth_type, username, password)
        VALUES (?, 'userpass', ?, ?)
        ON DUPLICATE KEY UPDATE
        username = VALUES(username), password = VALUES(password)
      `, [sipUsername, sipUsername, sipPassword]);

      console.log('✓ PJSIP auth created in ps_auths table');

      // Create PJSIP AOR in realtime table with correct data types
      await executeQuery(`
        INSERT INTO ps_aors (id, max_contacts, remove_existing, qualify_frequency)
        VALUES (?, 1, 1, 60)
        ON DUPLICATE KEY UPDATE
        max_contacts = VALUES(max_contacts), remove_existing = VALUES(remove_existing)
      `, [sipUsername]);

      console.log('✓ PJSIP AOR created in ps_aors table');
      
      // Try to reload PJSIP configuration (non-blocking)
      try {
        await this.ensureConnection();
        await this.reloadPJSIP();
      } catch (reloadError) {
        console.warn('⚠ PJSIP reload failed (non-critical):', reloadError.message);
      }
      
      console.log(`✓ PJSIP endpoint creation completed for customer ${customerId}`);
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

  async ensureRealtimeTables() {
    try {
      console.log('Ensuring PJSIP realtime tables exist...');
      
      // Create ps_endpoints table
      await executeQuery(`
        CREATE TABLE IF NOT EXISTS ps_endpoints (
          id varchar(40) NOT NULL,
          transport varchar(40) DEFAULT NULL,
          aors varchar(200) DEFAULT NULL,
          auth varchar(40) DEFAULT NULL,
          context varchar(40) DEFAULT NULL,
          disallow varchar(200) DEFAULT NULL,
          allow varchar(200) DEFAULT NULL,
          direct_media enum('yes','no') DEFAULT NULL,
          connected_line_method enum('invite','reinvite','update') DEFAULT NULL,
          direct_media_method enum('invite','reinvite','update') DEFAULT NULL,
          direct_media_glare_mitigation enum('none','outgoing','incoming') DEFAULT NULL,
          disable_direct_media_on_nat enum('yes','no') DEFAULT NULL,
          dtmf_mode enum('rfc4733','inband','info','auto','auto_info') DEFAULT NULL,
          external_media_address varchar(40) DEFAULT NULL,
          force_rport enum('yes','no') DEFAULT NULL,
          ice_support enum('yes','no') DEFAULT NULL,
          identify_by enum('username','auth_username','endpoint') DEFAULT NULL,
          mailboxes varchar(40) DEFAULT NULL,
          moh_suggest varchar(40) DEFAULT NULL,
          outbound_auth varchar(40) DEFAULT NULL,
          outbound_proxy varchar(40) DEFAULT NULL,
          rewrite_contact enum('yes','no') DEFAULT NULL,
          rtp_ipv6 enum('yes','no') DEFAULT NULL,
          rtp_symmetric enum('yes','no') DEFAULT NULL,
          send_diversion enum('yes','no') DEFAULT NULL,
          send_pai enum('yes','no') DEFAULT NULL,
          send_rpid enum('yes','no') DEFAULT NULL,
          timers_min_se int(10) unsigned DEFAULT NULL,
          timers enum('forced','no','required','yes') DEFAULT NULL,
          timers_sess_expires int(10) unsigned DEFAULT NULL,
          callerid varchar(40) DEFAULT NULL,
          callerid_privacy enum('allowed_not_screened','allowed_passed_screened','allowed_failed_screened','allowed','prohib_not_screened','prohib_passed_screened','prohib_failed_screened','prohib','unavailable') DEFAULT NULL,
          callerid_tag varchar(40) DEFAULT NULL,
          100rel enum('no','required','yes') DEFAULT NULL,
          aggregate_mwi enum('yes','no') DEFAULT NULL,
          trust_id_inbound enum('yes','no') DEFAULT NULL,
          trust_id_outbound enum('yes','no') DEFAULT NULL,
          use_ptime enum('yes','no') DEFAULT NULL,
          use_avpf enum('yes','no') DEFAULT NULL,
          media_encryption enum('no','sdes','dtls') DEFAULT NULL,
          inband_progress enum('yes','no') DEFAULT NULL,
          call_group varchar(40) DEFAULT NULL,
          pickup_group varchar(40) DEFAULT NULL,
          named_call_group varchar(40) DEFAULT NULL,
          named_pickup_group varchar(40) DEFAULT NULL,
          device_state_busy_at int(10) unsigned DEFAULT NULL,
          fax_detect enum('yes','no') DEFAULT NULL,
          t38_udptl enum('yes','no') DEFAULT NULL,
          t38_udptl_ec enum('none','fec','redundancy') DEFAULT NULL,
          t38_udptl_maxdatagram int(10) unsigned DEFAULT NULL,
          t38_udptl_nat enum('yes','no') DEFAULT NULL,
          t38_udptl_ipv6 enum('yes','no') DEFAULT NULL,
          tone_zone varchar(40) DEFAULT NULL,
          language varchar(40) DEFAULT NULL,
          one_touch_recording enum('yes','no') DEFAULT NULL,
          record_on_feature varchar(40) DEFAULT NULL,
          record_off_feature varchar(40) DEFAULT NULL,
          rtp_engine varchar(40) DEFAULT NULL,
          allow_transfer enum('yes','no') DEFAULT NULL,
          allow_subscribe enum('yes','no') DEFAULT NULL,
          sdp_owner varchar(40) DEFAULT NULL,
          sdp_session varchar(40) DEFAULT NULL,
          tos_audio varchar(10) DEFAULT NULL,
          tos_video varchar(10) DEFAULT NULL,
          sub_min_expiry int(10) unsigned DEFAULT NULL,
          from_domain varchar(40) DEFAULT NULL,
          from_user varchar(40) DEFAULT NULL,
          mwi_fromuser varchar(40) DEFAULT NULL,
          dtls_verify varchar(40) DEFAULT NULL,
          dtls_rekey varchar(40) DEFAULT NULL,
          dtls_cert_file varchar(200) DEFAULT NULL,
          dtls_private_key varchar(200) DEFAULT NULL,
          dtls_cipher varchar(200) DEFAULT NULL,
          dtls_ca_file varchar(200) DEFAULT NULL,
          dtls_ca_path varchar(200) DEFAULT NULL,
          dtls_setup enum('active','passive','actpass') DEFAULT NULL,
          srtp_tag_32 enum('yes','no') DEFAULT NULL,
          media_address varchar(40) DEFAULT NULL,
          redirect_method enum('user','uri_core','uri_pjsip') DEFAULT NULL,
          set_var text,
          cos_audio varchar(10) DEFAULT NULL,
          cos_video varchar(10) DEFAULT NULL,
          message_context varchar(40) DEFAULT NULL,
          force_avp enum('yes','no') DEFAULT NULL,
          media_use_received_transport enum('yes','no') DEFAULT NULL,
          accountcode varchar(40) DEFAULT NULL,
          user_eq_phone enum('yes','no') DEFAULT NULL,
          moh_passthrough enum('yes','no') DEFAULT NULL,
          media_encryption_optimistic enum('yes','no') DEFAULT NULL,
          rpid_immediate enum('yes','no') DEFAULT NULL,
          g726_non_standard enum('yes','no') DEFAULT NULL,
          rtp_keepalive varchar(10) DEFAULT NULL,
          rtp_timeout varchar(10) DEFAULT NULL,
          rtp_timeout_hold varchar(10) DEFAULT NULL,
          bind_rtp_to_media_address enum('yes','no') DEFAULT NULL,
          voicemail_extension varchar(40) DEFAULT NULL,
          mwi_subscribe_replaces_unsolicited enum('yes','no') DEFAULT NULL,
          deny varchar(95) DEFAULT NULL,
          permit varchar(95) DEFAULT NULL,
          acl varchar(40) DEFAULT NULL,
          contact_deny varchar(95) DEFAULT NULL,
          contact_permit varchar(95) DEFAULT NULL,
          contact_acl varchar(40) DEFAULT NULL,
          subscribe_context varchar(40) DEFAULT NULL,
          fax_detect_timeout varchar(10) DEFAULT NULL,
          contact_user varchar(40) DEFAULT NULL,
          preferred_codec_only enum('yes','no') DEFAULT NULL,
          asymmetric_rtp_codec enum('yes','no') DEFAULT NULL,
          rtcp_mux enum('yes','no') DEFAULT NULL,
          allow_overlap enum('yes','no') DEFAULT NULL,
          refer_blind_progress enum('yes','no') DEFAULT NULL,
          notify_early_inuse_ringing enum('yes','no') DEFAULT NULL,
          max_audio_streams varchar(10) DEFAULT NULL,
          max_video_streams varchar(10) DEFAULT NULL,
          webrtc enum('yes','no') DEFAULT NULL,
          dtls_fingerprint enum('SHA-256','SHA-1') DEFAULT NULL,
          incoming_mwi_mailbox varchar(40) DEFAULT NULL,
          bundle enum('yes','no') DEFAULT NULL,
          dtls_auto_generate_cert enum('yes','no') DEFAULT NULL,
          follow_early_media_fork enum('yes','no') DEFAULT NULL,
          accept_multiple_sdp_answers enum('yes','no') DEFAULT NULL,
          suppress_q850_reason_headers enum('yes','no') DEFAULT NULL,
          trust_connected_line enum('yes','no') DEFAULT NULL,
          send_connected_line enum('yes','no') DEFAULT NULL,
          ignore_183_without_sdp enum('yes','no') DEFAULT NULL,
          stir_shaken enum('yes','no','attest','verify') DEFAULT NULL,
          send_history_info enum('yes','no') DEFAULT NULL,
          allow_unauthenticated_options enum('yes','no') DEFAULT NULL,
          t38_bind_udptl_to_media_address enum('yes','no') DEFAULT NULL,
          geoloc_incoming_call_profile varchar(40) DEFAULT NULL,
          geoloc_outgoing_call_profile varchar(40) DEFAULT NULL,
          incoming_call_offer_pref enum('local','local_first','remote','remote_first') DEFAULT NULL,
          outgoing_call_offer_pref enum('local','local_first','remote','remote_first') DEFAULT NULL,
          codec_prefs_incoming_offer varchar(128) DEFAULT NULL,
          codec_prefs_outgoing_offer varchar(128) DEFAULT NULL,
          codec_prefs_incoming_answer varchar(128) DEFAULT NULL,
          codec_prefs_outgoing_answer varchar(128) DEFAULT NULL,
          stir_shaken_profile varchar(40) DEFAULT NULL,
          security_negotiation enum('no','mediasec') DEFAULT NULL,
          security_mechanisms varchar(512) DEFAULT NULL,
          send_aoc enum('yes','no') DEFAULT NULL,
          overlap_context varchar(40) DEFAULT NULL,
          PRIMARY KEY (id),
          UNIQUE KEY id (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
      `);

      // Create ps_auths table
      await executeQuery(`
        CREATE TABLE IF NOT EXISTS ps_auths (
          id varchar(40) NOT NULL,
          auth_type enum('md5','userpass') DEFAULT NULL,
          nonce_lifetime varchar(10) DEFAULT NULL,
          md5_cred varchar(40) DEFAULT NULL,
          password varchar(80) DEFAULT NULL,
          realm varchar(40) DEFAULT NULL,
          username varchar(40) DEFAULT NULL,
          PRIMARY KEY (id),
          UNIQUE KEY id (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
      `);

      // Create ps_aors table
      await executeQuery(`
        CREATE TABLE IF NOT EXISTS ps_aors (
          id varchar(40) NOT NULL,
          contact varchar(255) DEFAULT NULL,
          default_expiration varchar(10) DEFAULT NULL,
          mailboxes varchar(80) DEFAULT NULL,
          max_contacts varchar(10) DEFAULT NULL,
          minimum_expiration varchar(10) DEFAULT NULL,
          remove_existing enum('yes','no') DEFAULT NULL,
          qualify_frequency varchar(10) DEFAULT NULL,
          authenticate_qualify enum('yes','no') DEFAULT NULL,
          maximum_expiration varchar(10) DEFAULT NULL,
          outbound_proxy varchar(40) DEFAULT NULL,
          support_path enum('yes','no') DEFAULT NULL,
          qualify_timeout varchar(10) DEFAULT NULL,
          voicemail_extension varchar(40) DEFAULT NULL,
          PRIMARY KEY (id),
          UNIQUE KEY id (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
      `);

      // Create ps_contacts table
      await executeQuery(`
        CREATE TABLE IF NOT EXISTS ps_contacts (
          id varchar(255) NOT NULL,
          uri varchar(511) DEFAULT NULL,
          expiration_time varchar(40) DEFAULT NULL,
          qualify_frequency varchar(10) DEFAULT NULL,
          outbound_proxy varchar(40) DEFAULT NULL,
          path text,
          user_agent varchar(255) DEFAULT NULL,
          qualify_timeout varchar(10) DEFAULT NULL,
          reg_server varchar(255) DEFAULT NULL,
          authenticate_qualify enum('yes','no') DEFAULT NULL,
          via_addr varchar(40) DEFAULT NULL,
          via_port varchar(10) DEFAULT NULL,
          call_id varchar(255) DEFAULT NULL,
          endpoint varchar(40) DEFAULT NULL,
          prune_on_boot enum('yes','no') DEFAULT NULL,
          PRIMARY KEY (id),
          UNIQUE KEY id (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
      `);

      console.log('✓ PJSIP realtime tables ensured');
    } catch (error) {
      console.error('Error ensuring realtime tables:', error);
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
        `INSERT INTO sip_credentials (customer_id, sip_username, sip_password, sip_domain) 
         VALUES (?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE
         sip_password = VALUES(sip_password), sip_domain = VALUES(sip_domain), updated_at = NOW()`,
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
      try {
        await this.reloadPJSIP();
      } catch (reloadError) {
        console.warn('⚠ PJSIP reload failed (non-critical):', reloadError.message);
      }
      
      console.log(`✓ Deleted PJSIP endpoint for customer ${customerId}`);
    } catch (error) {
      console.error(`Failed to delete endpoint for customer ${customerId}:`, error);
      throw error;
    }
  }
}

module.exports = new AsteriskIntegration();
