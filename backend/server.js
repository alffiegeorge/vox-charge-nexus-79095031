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

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Global database connection status
let isDatabaseConnected = false;

async function initializeDatabase() {
  const success = await createDatabasePool();
  if (success) {
    isDatabaseConnected = true;
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
  }
}

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
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  jwt.verify(token, process.env.JWT_SECRET || 'your-secret-key', (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid token' });
    }
    req.user = user;
    next();
  });
};

// Routes
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    message: 'iBilling API Server is running',
    database: isDatabaseConnected ? 'Connected' : 'Disconnected',
    asterisk: asteriskManager.isConnected ? 'Connected' : 'Disconnected',
    environment: process.env.NODE_ENV || 'development'
  });
});

// Authentication routes
app.post('/auth/login', async (req, res) => {
  console.log('\n=== LOGIN ATTEMPT START ===');
  console.log('Request headers:', req.headers);
  console.log('Request body:', req.body);
  
  try {
    const { username, password } = req.body;
    
    console.log('Username:', username);
    console.log('Password provided:', password ? 'Yes' : 'No');
    console.log('Password length:', password ? password.length : 0);

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
    
    // Database query with proper error handling
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
    console.log('✓ User found:');
    console.log('- ID:', user.id);
    console.log('- Username:', user.username);
    console.log('- Role:', user.role);
    console.log('- Status:', user.status);
    console.log('- Email:', user.email);
    
    // Status check
    if (user.status !== 'active') {
      console.log('❌ User account is not active:', user.status);
      return res.status(401).json({ error: 'Account is not active' });
    }
    
    console.log('✓ User account is active');
    console.log('Comparing passwords...');
    console.log('Input password:', password);
    console.log('Stored hash exists:', user.password ? 'Yes' : 'No');
    console.log('Stored hash length:', user.password ? user.password.length : 0);
    
    // Password comparison with error handling
    let isValidPassword;
    try {
      isValidPassword = await bcrypt.compare(password, user.password);
      console.log('✓ Password comparison completed');
      console.log('Password valid:', isValidPassword);
    } catch (bcryptError) {
      console.error('❌ Password comparison failed:', bcryptError);
      return res.status(500).json({ error: 'Password verification failed' });
    }

    if (!isValidPassword) {
      console.log('❌ Password comparison failed - invalid credentials');
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    console.log('✅ Login successful for user:', username);

    // Token generation with error handling
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
    console.log('=== LOGIN ATTEMPT END ===\n');
    
    res.json(response);

  } catch (error) {
    console.error('\n❌ UNEXPECTED LOGIN ERROR:');
    console.error('Error message:', error.message);
    console.error('Error stack:', error.stack);
    console.error('=== LOGIN ATTEMPT END (ERROR) ===\n');
    
    res.status(500).json({ 
      error: 'Internal server error',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// Customer routes - Updated to include Asterisk integration
app.get('/api/customers', authenticateToken, async (req, res) => {
  try {
    console.log('Fetching customers from database...');
    
    if (!isDatabaseConnected) {
      console.error('❌ Database not available');
      return res.status(500).json({ error: 'Database not available' });
    }

    const [customers] = await executeQuery('SELECT * FROM customers ORDER BY created_at DESC');
    console.log('✓ Customers fetched successfully:', customers.length, 'records');
    
    res.json(customers);
  } catch (error) {
    console.error('Error fetching customers:', error);
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

    // Create PJSIP endpoint for the customer
    let sipCredentials = null;
    try {
      sipCredentials = await asteriskManager.createPJSIPEndpoint(customerId, { name, email, phone });
      console.log('✓ PJSIP endpoint created for customer:', customerId);
    } catch (asteriskError) {
      console.warn('⚠ Failed to create PJSIP endpoint:', asteriskError.message);
      console.warn('⚠ Customer created but SIP endpoint creation failed');
    }

    // Return the created customer data with SIP info
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
      created_at: new Date().toISOString(),
      sip_credentials: sipCredentials
    };

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

// New route to list Asterisk endpoints
app.get('/api/asterisk/endpoints', authenticateToken, async (req, res) => {
  try {
    const endpoints = await asteriskManager.listEndpoints();
    res.json(endpoints);
  } catch (error) {
    console.error('Error listing Asterisk endpoints:', error);
    res.status(500).json({ error: 'Failed to list Asterisk endpoints' });
  }
});

// Start server
async function startServer() {
  console.log('Starting iBilling API Server...');
  console.log('Environment:', process.env.NODE_ENV || 'development');
  console.log('Port:', PORT);
  
  await initializeDatabase();
  
  app.listen(PORT, () => {
    console.log(`🚀 iBilling API Server running on port ${PORT}`);
    console.log(`📊 Health check: http://localhost:${PORT}/health`);
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
