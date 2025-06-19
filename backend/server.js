const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const path = require('path');
require('dotenv').config();

// Import database functions
const { createDatabasePool, executeQuery } = require('./database');
// Import Asterisk integration
const asteriskManager = require('./asterisk-manager');
// Add the realtime setup import
const { setupRealtimeTables } = require('./realtime-setup');

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware - ORDER MATTERS!
app.use(cors({
  origin: '*', // Allow all origins for now
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
  credentials: false, // Don't require credentials for CORS
  optionsSuccessStatus: 200 // For legacy browser support
}));

// Handle preflight requests FIRST
app.options('*', (req, res) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With');
  res.status(200).send();
});

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Add request logging middleware
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  if (req.path.includes('/api/') || req.path.includes('/auth/')) {
    console.log('API Request:', req.method, req.path);
    console.log('Headers:', req.headers);
    if (req.body && Object.keys(req.body).length > 0) {
      console.log('Body:', req.body);
    }
  }
  next();
});

// Global database connection status
let isDatabaseConnected = false;

// Initialize database connection
async function initializeDatabase() {
  const success = await createDatabasePool();
  if (success) {
    isDatabaseConnected = true;
    console.log('✓ Database connection established successfully');
    // Create users table if it doesn't exist
    await createUsersTable();
    // Create billing core tables
    await createBillingTables();
    
    // Initialize Asterisk connection
    try {
      await asteriskManager.connect();
      console.log('✓ Asterisk Manager Interface connected');
    } catch (error) {
      console.warn('⚠ Asterisk AMI connection failed:', error.message);
      console.warn('⚠ PJSIP endpoint creation will be disabled');
    }
  } else {
    console.error('❌ Database connection failed');
    isDatabaseConnected = false;
  }
}

// Create users table
async function createUsersTable() {
  try {
    console.log('Creating/checking users table...');
    await executeQuery(`
      CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        username VARCHAR(50) NOT NULL UNIQUE,
        password VARCHAR(255) NOT NULL,
        email VARCHAR(100) NOT NULL UNIQUE,
        role ENUM('admin', 'customer', 'operator') NOT NULL DEFAULT 'customer',
        status ENUM('active', 'inactive', 'suspended') NOT NULL DEFAULT 'active',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      )
    `);
    console.log('✓ Users table created/exists');
    
    // Create customers table
    console.log('Creating/checking customers table...');
    await executeQuery(`
      CREATE TABLE IF NOT EXISTS customers (
        id VARCHAR(50) PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(100) NOT NULL UNIQUE,
        phone VARCHAR(20) NOT NULL,
        company VARCHAR(100),
        type ENUM('Prepaid', 'Postpaid') NOT NULL,
        balance DECIMAL(10,2) DEFAULT 0.00,
        credit_limit DECIMAL(10,2) DEFAULT 0.00,
        address TEXT,
        notes TEXT,
        status ENUM('Active', 'Inactive', 'Suspended') DEFAULT 'Active',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      )
    `);
    console.log('✓ Customers table created/exists');
    
    // Always recreate the admin user with a fresh hash to ensure it works
    console.log('Recreating admin user with fresh password hash...');
    
    // Delete existing admin user
    await executeQuery('DELETE FROM users WHERE username = ?', ['admin']);
    console.log('✓ Removed existing admin user');
    
    // Create new admin user with fresh bcrypt hash
    const hashedPassword = await bcrypt.hash('admin123', 10);
    console.log('✓ Generated fresh admin password hash');
    
    await executeQuery(
      'INSERT INTO users (username, password, email, role, status) VALUES (?, ?, ?, ?, ?)',
      ['admin', hashedPassword, 'admin@ibilling.local', 'admin', 'active']
    );
    console.log('✓ Admin user created with fresh hash');
    
    // Test the hash immediately
    const testValid = await bcrypt.compare('admin123', hashedPassword);
    console.log('✓ Password hash test result:', testValid);
    
    // Check if customer user exists, if not create it
    const [existingCustomer] = await executeQuery('SELECT COUNT(*) as count FROM users WHERE username = ?', ['customer']);
    console.log('Customer user check result:', existingCustomer[0]);
    
    if (existingCustomer[0].count === 0) {
      console.log('Creating default customer user...');
      const customerHashedPassword = await bcrypt.hash('customer123', 10);
      console.log('Customer password hash generated successfully');
      await executeQuery(
        'INSERT INTO users (username, password, email, role, status) VALUES (?, ?, ?, ?, ?)',
        ['customer', customerHashedPassword, 'customer@ibilling.local', 'customer', 'active']
      );
      console.log('✓ Default customer user created with password: customer123');
    } else {
      console.log('Customer user already exists');
    }
    
    // Let's also verify the users are in the database
    const [allUsers] = await executeQuery('SELECT id, username, role, status FROM users');
    console.log('All users in database:', allUsers);
    
    console.log('✓ Users table ready');
  } catch (error) {
    console.error('Error setting up users table:', error.message);
    console.error('Full error:', error);
  }
}

// Create billing core tables
async function createBillingTables() {
  try {
    console.log('Creating billing core tables...');
    
    // Create rates table for call pricing
    await executeQuery(`
      CREATE TABLE IF NOT EXISTS rates (
        id INT AUTO_INCREMENT PRIMARY KEY,
        destination VARCHAR(100) NOT NULL,
        prefix VARCHAR(20) NOT NULL,
        rate DECIMAL(10,4) NOT NULL,
        connection_fee DECIMAL(10,4) DEFAULT 0.0000,
        minimum_duration INT DEFAULT 60,
        billing_increment INT DEFAULT 60,
        description TEXT,
        effective_date DATE DEFAULT CURRENT_DATE,
        status ENUM('active', 'inactive') DEFAULT 'active',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      )
    `);
    
    // Create billing_history table for tracking charges
    await executeQuery(`
      CREATE TABLE IF NOT EXISTS billing_history (
        id INT AUTO_INCREMENT PRIMARY KEY,
        customer_id VARCHAR(50) NOT NULL,
        transaction_type ENUM('charge', 'credit', 'refund', 'adjustment') NOT NULL,
        amount DECIMAL(10,2) NOT NULL,
        description TEXT,
        call_id VARCHAR(100),
        reference_id VARCHAR(100),
        balance_before DECIMAL(10,2),
        balance_after DECIMAL(10,2),
        processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
      )
    `);
    
    // Create active_calls table for real-time billing
    await executeQuery(`
      CREATE TABLE IF NOT EXISTS active_calls (
        id INT AUTO_INCREMENT PRIMARY KEY,
        call_id VARCHAR(100) UNIQUE NOT NULL,
        customer_id VARCHAR(50),
        caller_id VARCHAR(50),
        called_number VARCHAR(50),
        destination VARCHAR(100),
        rate_id INT,
        start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        estimated_cost DECIMAL(10,4) DEFAULT 0.0000,
        status ENUM('active', 'completed', 'failed') DEFAULT 'active',
        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL,
        FOREIGN KEY (rate_id) REFERENCES rates(id) ON DELETE SET NULL
      )
    `);
    
    // Create billing_plans table
    await executeQuery(`
      CREATE TABLE IF NOT EXISTS billing_plans (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        price DECIMAL(10,2) NOT NULL,
        minutes INT NOT NULL,
        features JSON,
        status ENUM('active', 'inactive') DEFAULT 'active',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      )
    `);
    
    // Create sms_history table
    await executeQuery(`
      CREATE TABLE IF NOT EXISTS sms_history (
        id INT AUTO_INCREMENT PRIMARY KEY,
        customer_id VARCHAR(50),
        phone_number VARCHAR(20) NOT NULL,
        message TEXT NOT NULL,
        status ENUM('Sent', 'Delivered', 'Failed', 'Scheduled') DEFAULT 'Sent',
        cost DECIMAL(10,4) DEFAULT 0.0000,
        scheduled_at DATETIME NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL
      )
    `);
    
    // Create sms_templates table
    await executeQuery(`
      CREATE TABLE IF NOT EXISTS sms_templates (
        id INT AUTO_INCREMENT PRIMARY KEY,
        title VARCHAR(100) NOT NULL,
        message TEXT NOT NULL,
        category VARCHAR(50) DEFAULT 'general',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    
    // Add realtime tables setup
    await setupRealtimeTables();
    
    console.log('✓ Billing core tables created successfully');
    
    // Insert default rate if none exist
    const [rateCount] = await executeQuery('SELECT COUNT(*) as count FROM rates');
    if (rateCount[0].count === 0) {
      console.log('Inserting default rates...');
      await executeQuery(`
        INSERT INTO rates (destination, prefix, rate, connection_fee, description) VALUES
        ('Local', '678', 0.15, 0.05, 'Local Vanuatu calls'),
        ('Mobile', '7', 0.25, 0.05, 'Mobile calls'),
        ('International', '00', 0.50, 0.10, 'International calls'),
        ('Premium', '190', 1.50, 0.20, 'Premium rate services')
      `);
      console.log('✓ Default rates inserted');
    }
    
  } catch (error) {
    console.error('Error creating billing tables:', error.message);
    console.error('Full error:', error);
  }
}

// Authentication middleware
const authenticateToken = (req, res, next) => {
  console.log('Authenticating token for:', req.method, req.path);
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    console.log('❌ No token provided');
    return res.status(401).json({ error: 'Access token required' });
  }

  jwt.verify(token, process.env.JWT_SECRET || 'your-secret-key', (err, user) => {
    if (err) {
      console.log('❌ Invalid token:', err.message);
      return res.status(403).json({ error: 'Invalid token' });
    }
    console.log('✓ Token valid for user:', user.username);
    req.user = user;
    next();
  });
};

// Routes - AUTHENTICATION FIRST
app.post('/auth/login', async (req, res) => {
  console.log('\n=== LOGIN ENDPOINT HIT ===');
  console.log('Method:', req.method);
  console.log('Path:', req.path);
  console.log('Headers:', req.headers);
  console.log('Body:', req.body);
  
  // Add CORS headers explicitly for login
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  
  try {
    const { username, password } = req.body;
    
    console.log('Username:', username);
    console.log('Password provided:', password ? 'Yes' : 'No');

    // Input validation
    if (!username || !password) {
      console.log('❌ Missing username or password');
      return res.status(400).json({ error: 'Username and password required' });
    }

    // Database availability check
    if (!isDatabaseConnected) {
      console.error('❌ Database not available');
      return res.status(500).json({ error: 'Database not available' });
    }

    console.log('✓ Database is available');
    console.log('Querying database for user:', username);
    
    // Database query
    let users;
    try {
      [users] = await executeQuery(
        'SELECT id, username, password, email, role, status FROM users WHERE username = ?',
        [username]
      );
      console.log('✓ Database query successful');
      console.log('Query result count:', users.length);
    } catch (dbError) {
      console.error('❌ Database query failed:', dbError);
      return res.status(500).json({ error: 'Database query failed' });
    }

    if (users.length === 0) {
      console.log('❌ No user found with username:', username);
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const user = users[0];
    console.log('✓ User found:', user.username, 'Role:', user.role);
    
    // Status check
    if (user.status !== 'active') {
      console.log('❌ User account is not active:', user.status);
      return res.status(401).json({ error: 'Account is not active' });
    }
    
    // Password comparison
    let isValidPassword;
    try {
      isValidPassword = await bcrypt.compare(password, user.password);
      console.log('Password valid:', isValidPassword);
    } catch (bcryptError) {
      console.error('❌ Password comparison failed:', bcryptError);
      return res.status(500).json({ error: 'Password verification failed' });
    }

    if (!isValidPassword) {
      console.log('❌ Invalid credentials');
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    console.log('✅ Login successful for user:', username);

    // Token generation
    let token;
    try {
      token = jwt.sign(
        { id: user.id, username: user.username, role: user.role },
        process.env.JWT_SECRET || 'your-secret-key',
        { expiresIn: '24h' }
      );
      console.log('✓ JWT token generated successfully');
    } catch (jwtError) {
      console.error('❌ JWT token generation failed:', jwtError);
      return res.status(500).json({ error: 'Token generation failed' });
    }

    const response = {
      token,
      user: {
        id: user.id,
        username: user.username,
        role: user.role,
        email: user.email
      }
    };

    console.log('✅ Sending successful response');
    res.json(response);

  } catch (error) {
    console.error('❌ UNEXPECTED LOGIN ERROR:', error);
    res.status(500).json({ 
      error: 'Internal server error',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// Health check route
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    message: 'iBilling API Server is running',
    database: isDatabaseConnected ? 'Connected' : 'Disconnected',
    asterisk: asteriskManager.isConnected ? 'Connected' : 'Disconnected',
    environment: process.env.NODE_ENV || 'development'
  });
});

// Customer routes - Updated to handle Asterisk integration gracefully
app.get('/api/customers', authenticateToken, async (req, res) => {
  try {
    console.log('=== FETCHING CUSTOMERS START ===');
    console.log('Database connected:', isDatabaseConnected);
    
    if (!isDatabaseConnected) {
      console.error('❌ Database not available');
      return res.status(500).json({ error: 'Database not available' });
    }

    console.log('Executing query: SELECT * FROM customers ORDER BY created_at DESC');
    const [customers] = await executeQuery('SELECT * FROM customers ORDER BY created_at DESC');
    console.log('✓ Customers fetched successfully:', customers.length, 'records');
    console.log('Sample customer data:', customers[0] || 'No customers found');
    console.log('=== FETCHING CUSTOMERS END ===');
    
    res.json(customers);
  } catch (error) {
    console.error('=== FETCHING CUSTOMERS ERROR ===');
    console.error('Error fetching customers:', error);
    console.error('Error details:', error.message);
    console.error('=== FETCHING CUSTOMERS ERROR END ===');
    res.status(500).json({ error: 'Failed to fetch customers', details: error.message });
  }
});

app.post('/api/customers', authenticateToken, async (req, res) => {
  try {
    console.log('Creating customer with request body:', req.body);
    
    const { name, email, phone, company, type, balance, credit_limit, address, notes, status } = req.body;

    // Generate a unique customer ID
    const customerId = `C${Date.now().toString().slice(-6)}`;
    
    console.log('Generated customer ID:', customerId);

    // Insert customer with all fields
    const result = await executeQuery(
      `INSERT INTO customers (id, name, email, phone, company, type, balance, credit_limit, address, notes, status, created_at) 
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())`,
      [
        customerId,
        name,
        email,
        phone,
        company || null,
        type,
        balance || 0,
        credit_limit || 0,
        address || null,
        notes || null,
        status || 'Active'
      ]
    );

    console.log('Customer created successfully with ID:', customerId);

    // Prepare the response data first
    const createdCustomer = {
      id: customerId,
      name,
      email,
      phone,
      company,
      type,
      balance: balance || 0,
      credit_limit: credit_limit || 0,
      address,
      notes,
      status: status || 'Active',
      created_at: new Date().toISOString()
    };

    // Try to create PJSIP endpoint asynchronously (non-blocking)
    // This won't block the response if it fails
    setImmediate(async () => {
      try {
        const sipCredentials = await asteriskManager.createPJSIPEndpoint(customerId, { name, email, phone });
        console.log('✓ PJSIP endpoint created for customer:', customerId);
        
        // Update the customer record with SIP info if successful
        await executeQuery(
          'UPDATE customers SET notes = CONCAT(COALESCE(notes, ""), "\nSIP Username: ", ?) WHERE id = ?',
          [sipCredentials.sipUsername, customerId]
        );
      } catch (asteriskError) {
        console.warn('⚠ Failed to create PJSIP endpoint for customer', customerId, ':', asteriskError.message);
        console.warn('⚠ Customer created successfully but SIP endpoint creation failed');
      }
    });

    // Always send the response immediately
    console.log('Sending response for created customer:', customerId);
    res.status(201).json(createdCustomer);
    
  } catch (error) {
    console.error('Error creating customer:', error);
    res.status(500).json({ error: 'Failed to create customer', details: error.message });
  }
});

app.put('/api/customers/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { name, email, phone, company, type, balance, credit_limit, address, notes, status } = req.body;

    console.log('Updating customer:', id, 'with data:', req.body);

    const result = await executeQuery(
      `UPDATE customers SET 
       name = ?, email = ?, phone = ?, company = ?, type = ?, 
       balance = ?, credit_limit = ?, address = ?, notes = ?, status = ?,
       updated_at = NOW()
       WHERE id = ?`,
      [name, email, phone, company || null, type, balance || 0, credit_limit || 0, address || null, notes || null, status || 'Active', id]
    );

    if (result[0].affectedRows === 0) {
      return res.status(404).json({ error: 'Customer not found' });
    }

    console.log('Customer updated successfully:', id);

    // Return the updated customer data
    const [updatedCustomers] = await executeQuery('SELECT * FROM customers WHERE id = ?', [id]);
    res.json(updatedCustomers[0]);
  } catch (error) {
    console.error('Error updating customer:', error);
    res.status(500).json({ error: 'Failed to update customer', details: error.message });
  }
});

// New route to get SIP credentials for a customer
app.get('/api/customers/:id/sip-credentials', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    console.log('Fetching SIP credentials for customer:', id);
    
    // First try to get from sip_credentials table (created by asterisk-manager)
    try {
      const [sipCreds] = await executeQuery(
        'SELECT * FROM sip_credentials WHERE customer_id = ?',
        [id]
      );
      
      if (sipCreds.length > 0) {
        const cred = sipCreds[0];
        const sipCredentials = {
          sip_username: cred.sip_username,
          sip_password: cred.sip_password,
          sip_domain: cred.sip_domain,
          status: cred.status,
          created_at: cred.created_at
        };
        
        console.log('SIP credentials found in sip_credentials table for customer:', id);
        return res.json(sipCredentials);
      }
    } catch (error) {
      console.log('sip_credentials table not found or error, trying PJSIP tables...');
    }
    
    // Try with customer ID as-is
    let [endpoints] = await executeQuery(
      'SELECT * FROM ps_endpoints WHERE id = ?',
      [id]
    );
    
    // If not found, try with lowercase customer ID
    if (endpoints.length === 0) {
      [endpoints] = await executeQuery(
        'SELECT * FROM ps_endpoints WHERE id = ?',
        [id.toLowerCase()]
      );
    }
    
    if (endpoints.length === 0) {
      console.log('No SIP endpoint found for customer:', id);
      return res.status(404).json({ error: 'No SIP credentials found for this customer' });
    }
    
    const endpoint = endpoints[0];
    const endpointId = endpoint.id;
    
    // Query the ps_auths table for authentication details
    const [auths] = await executeQuery(
      'SELECT * FROM ps_auths WHERE id = ?',
      [endpointId]
    );
    
    if (auths.length === 0) {
      console.log('No SIP auth found for customer:', id);
      return res.status(404).json({ error: 'No SIP authentication found for this customer' });
    }
    
    const auth = auths[0];
    
    // Return the SIP credentials
    const sipCredentials = {
      sip_username: auth.username || endpointId,
      sip_password: auth.password,
      sip_domain: process.env.ASTERISK_HOST || 'localhost',
      status: 'active',
      created_at: endpoint.created_at || new Date().toISOString()
    };
    
    console.log('SIP credentials found in PJSIP tables for customer:', id);
    res.json(sipCredentials);
    
  } catch (error) {
    console.error('Error fetching SIP credentials:', error);
    res.status(500).json({ error: 'Failed to fetch SIP credentials', details: error.message });
  }
});

app.get('/api/customers/:id/sip', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const credentials = await asteriskManager.getSipCredentials(id);
    
    if (!credentials) {
      return res.status(404).json({ error: 'SIP credentials not found for this customer' });
    }
    
    res.json(credentials);
  } catch (error) {
    console.error('Error fetching SIP credentials:', error);
    res.status(500).json({ error: 'Failed to fetch SIP credentials' });
  }
});

// New route to manually create SIP endpoint for existing customer
app.post('/api/customers/:id/create-sip-endpoint', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    console.log('Manually creating SIP endpoint for customer:', id);
    
    // First check if customer exists
    const [customers] = await executeQuery(
      'SELECT * FROM customers WHERE id = ?',
      [id]
    );
    
    if (customers.length === 0) {
      return res.status(404).json({ error: 'Customer not found' });
    }
    
    const customer = customers[0];
    
    // Check if SIP credentials already exist
    const existingCredentials = await asteriskManager.getSipCredentials(id);
    if (existingCredentials) {
      return res.status(400).json({ 
        error: 'SIP endpoint already exists for this customer',
        credentials: {
          sip_username: existingCredentials.sip_username,
          sip_domain: existingCredentials.sip_domain,
          status: existingCredentials.status
        }
      });
    }
    
    // Create the SIP endpoint
    const sipCredentials = await asteriskManager.createPJSIPEndpoint(id, {
      name: customer.name,
      email: customer.email,
      phone: customer.phone
    });
    
    console.log('✓ SIP endpoint created successfully for customer:', id);
    
    res.json({
      message: 'SIP endpoint created successfully',
      credentials: sipCredentials
    });
    
  } catch (error) {
    console.error('Error creating SIP endpoint:', error);
    res.status(500).json({ 
      error: 'Failed to create SIP endpoint', 
      details: error.message 
    });
  }
});

app.get('/api/asterisk/endpoints', authenticateToken, async (req, res) => {
  try {
    const endpoints = await asteriskManager.listEndpoints();
    res.json(endpoints);
  } catch (error) {
    console.error('Error listing Asterisk endpoints:', error);
    res.status(500).json({ error: 'Failed to list Asterisk endpoints' });
  }
});

// DID Management routes
app.get('/api/dids', authenticateToken, async (req, res) => {
  try {
    console.log('=== FETCHING DIDs START ===');
    console.log('Database connected:', isDatabaseConnected);
    
    if (!isDatabaseConnected) {
      console.error('❌ Database not available');
      return res.status(500).json({ error: 'Database not available' });
    }

    // Create DIDs table if it doesn't exist
    await executeQuery(`
      CREATE TABLE IF NOT EXISTS dids (
        id INT AUTO_INCREMENT PRIMARY KEY,
        number VARCHAR(20) NOT NULL UNIQUE,
        customer_id VARCHAR(50),
        customer_name VARCHAR(100),
        country VARCHAR(50) NOT NULL,
        rate DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        status ENUM('Available', 'Active', 'Suspended') DEFAULT 'Available',
        type VARCHAR(20) DEFAULT 'Local',
        notes TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL
      )
    `);

    console.log('Executing query: SELECT * FROM dids ORDER BY created_at DESC');
    const [dids] = await executeQuery(`
      SELECT d.*, c.name as customer_name 
      FROM dids d 
      LEFT JOIN customers c ON d.customer_id = c.id 
      ORDER BY d.created_at DESC
    `);
    
    console.log('✓ DIDs fetched successfully:', dids.length, 'records');
    console.log('Sample DID data:', dids[0] || 'No DIDs found');
    console.log('=== FETCHING DIDs END ===');
    
    res.json(dids);
  } catch (error) {
    console.error('=== FETCHING DIDs ERROR ===');
    console.error('Error fetching DIDs:', error);
    console.error('Error details:', error.message);
    console.error('=== FETCHING DIDs ERROR END ===');
    res.status(500).json({ error: 'Failed to fetch DIDs', details: error.message });
  }
});

app.post('/api/dids', authenticateToken, async (req, res) => {
  try {
    console.log('Creating DID with request body:', req.body);
    
    const { number, customer, country, rate, type, status, customerId, notes } = req.body;

    // Insert DID
    const result = await executeQuery(
      `INSERT INTO dids (number, customer_id, customer_name, country, rate, type, status, notes, created_at) 
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())`,
      [
        number,
        customerId || null,
        customer || 'Unassigned',
        country,
        parseFloat(rate.replace('$', '')) || 0,
        type || 'Local',
        status || 'Available',
        notes || null
      ]
    );

    console.log('DID created successfully:', number);

    // Return the created DID data
    const createdDID = {
      number,
      customer: customer || 'Unassigned',
      country,
      rate,
      type: type || 'Local',
      status: status || 'Available',
      customerId,
      notes,
      created_at: new Date().toISOString()
    };

    res.status(201).json(createdDID);
  } catch (error) {
    console.error('Error creating DID:', error);
    res.status(500).json({ error: 'Failed to create DID', details: error.message });
  }
});

app.put('/api/dids/:number', authenticateToken, async (req, res) => {
  try {
    const { number } = req.params;
    const { customer, country, rate, type, status, customerId, notes } = req.body;

    console.log('Updating DID:', number, 'with data:', req.body);

    const result = await executeQuery(
      `UPDATE dids SET 
       customer_id = ?, customer_name = ?, country = ?, rate = ?, 
       type = ?, status = ?, notes = ?, updated_at = NOW()
       WHERE number = ?`,
      [
        customerId || null,
        customer || 'Unassigned',
        country,
        parseFloat(rate.replace('$', '')) || 0,
        type || 'Local',
        status || 'Available',
        notes || null,
        number
      ]
    );

    if (result[0].affectedRows === 0) {
      return res.status(404).json({ error: 'DID not found' });
    }

    console.log('DID updated successfully:', number);

    // Return the updated DID data
    const [updatedDIDs] = await executeQuery(`
      SELECT d.*, c.name as customer_name 
      FROM dids d 
      LEFT JOIN customers c ON d.customer_id = c.id 
      WHERE d.number = ?
    `, [number]);
    
    res.json(updatedDIDs[0]);
  } catch (error) {
    console.error('Error updating DID:', error);
    res.status(500).json({ error: 'Failed to update DID', details: error.message });
  }
});

// Trunk Management routes
app.get('/api/trunks', authenticateToken, async (req, res) => {
  try {
    console.log('=== FETCHING TRUNKS START ===');
    
    // Create trunks table if it doesn't exist
    await executeQuery(`
      CREATE TABLE IF NOT EXISTS trunks (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL UNIQUE,
        provider VARCHAR(100) NOT NULL,
        sip_server VARCHAR(255) NOT NULL,
        port VARCHAR(10) DEFAULT '5060',
        username VARCHAR(100),
        password VARCHAR(255),
        max_channels INT DEFAULT 30,
        status ENUM('Active', 'Standby', 'Inactive') DEFAULT 'Active',
        quality ENUM('Excellent', 'Good', 'Fair', 'Poor') DEFAULT 'Good',
        notes TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      )
    `);

    const [trunks] = await executeQuery('SELECT * FROM trunks ORDER BY created_at DESC');
    console.log('✓ Trunks fetched successfully:', trunks.length, 'records');
    
    res.json(trunks);
  } catch (error) {
    console.error('Error fetching trunks:', error);
    res.status(500).json({ error: 'Failed to fetch trunks', details: error.message });
  }
});

app.post('/api/trunks', authenticateToken, async (req, res) => {
  try {
    const { name, provider, sipServer, port, username, password, maxChannels, status, quality, notes } = req.body;

    const result = await executeQuery(
      `INSERT INTO trunks (name, provider, sip_server, port, username, password, max_channels, status, quality, notes) 
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [name, provider, sipServer, port || '5060', username, password, maxChannels, status, quality, notes]
    );

    console.log('Trunk created successfully:', name);
    res.status(201).json({ name, provider, sipServer, port, maxChannels, status, quality });
  } catch (error) {
    console.error('Error creating trunk:', error);
    res.status(500).json({ error: 'Failed to create trunk', details: error.message });
  }
});

app.put('/api/trunks/:name', authenticateToken, async (req, res) => {
  try {
    const { name } = req.params;
    const { provider, sipServer, port, username, password, maxChannels, status, quality, notes } = req.body;

    const result = await executeQuery(
      `UPDATE trunks SET provider = ?, sip_server = ?, port = ?, username = ?, 
       password = ?, max_channels = ?, status = ?, quality = ?, notes = ?, updated_at = NOW()
       WHERE name = ?`,
      [provider, sipServer, port, username, password, maxChannels, status, quality, notes, name]
    );

    if (result[0].affectedRows === 0) {
      return res.status(404).json({ error: 'Trunk not found' });
    }

    res.json({ name, provider, sipServer, port, maxChannels, status, quality });
  } catch (error) {
    console.error('Error updating trunk:', error);
    res.status(500).json({ error: 'Failed to update trunk', details: error.message });
  }
});

// Routes Management
app.get('/api/routes', authenticateToken, async (req, res) => {
  try {
    // Create routes table if it doesn't exist
    await executeQuery(`
      CREATE TABLE IF NOT EXISTS routes (
        id INT AUTO_INCREMENT PRIMARY KEY,
        pattern VARCHAR(50) NOT NULL,
        destination VARCHAR(255) NOT NULL,
        trunk_name VARCHAR(100),
        priority INT DEFAULT 1,
        status ENUM('Active', 'Inactive') DEFAULT 'Active',
        notes TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (trunk_name) REFERENCES trunks(name) ON DELETE SET NULL
      )
    `);

    const [routes] = await executeQuery(`
      SELECT r.*, t.provider as trunk_provider 
      FROM routes r 
      LEFT JOIN trunks t ON r.trunk_name = t.name 
      ORDER BY r.priority ASC, r.created_at DESC
    `);
    
    res.json(routes);
  } catch (error) {
    console.error('Error fetching routes:', error);
    res.status(500).json({ error: 'Failed to fetch routes', details: error.message });
  }
});

app.post('/api/routes', authenticateToken, async (req, res) => {
  try {
    const { pattern, destination, trunkName, priority, status, notes } = req.body;

    const result = await executeQuery(
      `INSERT INTO routes (pattern, destination, trunk_name, priority, status, notes) 
       VALUES (?, ?, ?, ?, ?, ?)`,
      [pattern, destination, trunkName, priority || 1, status || 'Active', notes]
    );

    const routeId = result[0].insertId;
    res.status(201).json({ id: routeId, pattern, destination, trunkName, priority, status });
  } catch (error) {
    console.error('Error creating route:', error);
    res.status(500).json({ error: 'Failed to create route', details: error.message });
  }
});

app.put('/api/routes/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { pattern, destination, trunkName, priority, status, notes } = req.body;

    const result = await executeQuery(
      `UPDATE routes SET pattern = ?, destination = ?, trunk_name = ?, 
       priority = ?, status = ?, notes = ?, updated_at = NOW()
       WHERE id = ?`,
      [pattern, destination, trunkName, priority, status, notes, id]
    );

    if (result[0].affectedRows === 0) {
      return res.status(404).json({ error: 'Route not found' });
    }

    res.json({ id, pattern, destination, trunkName, priority, status });
  } catch (error) {
    console.error('Error updating route:', error);
    res.status(500).json({ error: 'Failed to update route', details: error.message });
  }
});

// Start server
async function startServer() {
  console.log('Starting iBilling API Server...');
  console.log('Environment:', process.env.NODE_ENV || 'development');
  console.log('Port:', PORT);
  
  await initializeDatabase();
  
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 iBilling API Server running on port ${PORT}`);
    console.log(`📊 Health check: http://localhost:${PORT}/health`);
    console.log('Available API routes:');
    console.log('  GET /health');
    console.log('  POST /auth/login');
    console.log('  GET /api/customers');
    console.log('  POST /api/customers');
    console.log('  PUT /api/customers/:id');
    console.log('  GET /api/customers/:id/sip-credentials');
    console.log('  GET /api/customers/:id/sip');
    console.log('  GET /api/asterisk/endpoints');
    console.log('  GET /api/dids');
    console.log('  POST /api/dids');
    console.log('  PUT /api/dids/:number');
    console.log('  GET /api/trunks');
    console.log('  POST /api/trunks');
    console.log('  PUT /api/trunks/:name');
    console.log('  GET /api/routes');
    console.log('  POST /api/routes');
    console.log('  PUT /api/routes/:id');
    console.log('Server is ready to accept connections');
  });
}

// Handle graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  process.exit(0);
});

startServer().catch(console.error);
