
const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const path = require('path');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Database connection with enhanced configuration
const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 3306,
  user: process.env.DB_USER || 'asterisk',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'asterisk',
  connectionLimit: 10,
  acquireTimeout: 60000,
  timeout: 60000,
  reconnect: true,
  idleTimeout: 300000,
  maxIdle: 10,
  enableKeepAlive: true,
  keepAliveInitialDelay: 0
};

let db;

async function createDatabasePool() {
  try {
    console.log('Creating database connection pool...');
    console.log(`Host: ${dbConfig.host}:${dbConfig.port}`);
    console.log(`Database: ${dbConfig.database}`);
    console.log(`User: ${dbConfig.user}`);
    
    db = mysql.createPool(dbConfig);
    
    // Test the connection
    const connection = await db.getConnection();
    await connection.ping();
    connection.release();
    console.log('✓ Database pool created and tested successfully');
    
    // Handle pool events
    db.pool.on('connection', function (connection) {
      console.log('New database connection established as id ' + connection.threadId);
    });

    db.pool.on('error', function(err) {
      console.error('Database pool error:', err);
      if(err.code === 'PROTOCOL_CONNECTION_LOST') {
        console.log('Attempting to reconnect to database...');
        setTimeout(createDatabasePool, 2000);
      }
    });
    
    return true;
  } catch (error) {
    console.error('✗ Database pool creation failed:', error.message);
    console.error('Please check your database configuration and ensure MySQL is running');
    return false;
  }
}

async function initializeDatabase() {
  const success = await createDatabasePool();
  if (success) {
    // Create users table if it doesn't exist
    await createUsersTable();
  }
}

async function executeQuery(query, params = []) {
  let connection;
  try {
    if (!db) {
      throw new Error('Database pool not available');
    }
    
    connection = await db.getConnection();
    const result = await connection.execute(query, params);
    connection.release();
    return result;
  } catch (error) {
    if (connection) connection.release();
    
    // Handle connection errors
    if (error.code === 'ECONNRESET' || error.code === 'PROTOCOL_CONNECTION_LOST' || error.code === 'ER_ACCESS_DENIED_ERROR') {
      console.error('Database connection error:', error.message);
      console.log('Attempting to recreate database pool...');
      await createDatabasePool();
      throw new Error('Database connection failed. Please try again.');
    }
    
    throw error;
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
    database: db ? 'Connected' : 'Disconnected',
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
    if (!db) {
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

// Customer routes
app.get('/customers', authenticateToken, async (req, res) => {
  try {
    if (!db) {
      return res.status(500).json({ error: 'Database not available' });
    }

    const [customers] = await executeQuery('SELECT * FROM customers ORDER BY created_at DESC');
    res.json(customers);
  } catch (error) {
    console.error('Error fetching customers:', error);
    res.status(500).json({ error: 'Failed to fetch customers' });
  }
});

app.post('/customers', authenticateToken, async (req, res) => {
  try {
    if (!db) {
      return res.status(500).json({ error: 'Database not available' });
    }

    const { id, name, email, phone, company, type, balance, credit_limit, status } = req.body;

    await executeQuery(
      'INSERT INTO customers (id, name, email, phone, company, type, balance, credit_limit, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [id, name, email, phone, company, type, balance || 0, credit_limit, status || 'Active']
    );

    res.status(201).json({ message: 'Customer created successfully' });
  } catch (error) {
    console.error('Error creating customer:', error);
    res.status(500).json({ error: 'Failed to create customer' });
  }
});

// CDR routes
app.get('/cdr', authenticateToken, async (req, res) => {
  try {
    if (!db) {
      return res.status(500).json({ error: 'Database not available' });
    }

    const { page = 1, limit = 50, accountcode } = req.query;
    const offset = (page - 1) * limit;

    let query = 'SELECT * FROM cdr';
    let params = [];

    if (accountcode) {
      query += ' WHERE accountcode = ?';
      params.push(accountcode);
    }

    query += ' ORDER BY calldate DESC LIMIT ? OFFSET ?';
    params.push(parseInt(limit), offset);

    const [records] = await db.execute(query, params);
    
    // Get total count
    let countQuery = 'SELECT COUNT(*) as total FROM cdr';
    let countParams = [];
    
    if (accountcode) {
      countQuery += ' WHERE accountcode = ?';
      countParams.push(accountcode);
    }
    
    const [countResult] = await db.execute(countQuery, countParams);
    const total = countResult[0].total;

    res.json({
      records,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / limit)
      }
    });

  } catch (error) {
    console.error('Error fetching CDR:', error);
    res.status(500).json({ error: 'Failed to fetch CDR records' });
  }
});

// Dashboard stats
app.get('/dashboard/stats', authenticateToken, async (req, res) => {
  try {
    if (!db) {
      return res.status(500).json({ error: 'Database not available' });
    }

    // Total customers
    const [customerCount] = await db.execute('SELECT COUNT(*) as count FROM customers');
    
    // Active calls (last 24 hours)
    const [activeCallsCount] = await db.execute(
      'SELECT COUNT(*) as count FROM cdr WHERE calldate >= DATE_SUB(NOW(), INTERVAL 24 HOUR)'
    );
    
    // Total revenue (sum of billsec for answered calls)
    const [revenueResult] = await db.execute(
      'SELECT SUM(billsec) as total_seconds FROM cdr WHERE disposition = "ANSWERED"'
    );
    
    // Recent calls
    const [recentCalls] = await db.execute(
      'SELECT * FROM cdr ORDER BY calldate DESC LIMIT 10'
    );

    res.json({
      totalCustomers: customerCount[0].count,
      activeCalls: activeCallsCount[0].count,
      totalRevenue: Math.round((revenueResult[0].total_seconds || 0) * 0.01), // Assuming $0.01 per second
      recentCalls
    });

  } catch (error) {
    console.error('Error fetching dashboard stats:', error);
    res.status(500).json({ error: 'Failed to fetch dashboard statistics' });
  }
});

// Rate Management routes
app.get('/rates', authenticateToken, async (req, res) => {
  try {
    if (!db) {
      return res.status(500).json({ error: 'Database not available' });
    }

    const [rates] = await db.execute('SELECT * FROM rates ORDER BY created_at DESC');
    res.json(rates);
  } catch (error) {
    console.error('Error fetching rates:', error);
    res.status(500).json({ error: 'Failed to fetch rates' });
  }
});

app.post('/rates', authenticateToken, async (req, res) => {
  try {
    if (!db) {
      return res.status(500).json({ error: 'Database not available' });
    }

    const { destination, prefix, rate, connection, description } = req.body;

    await db.execute(
      'INSERT INTO rates (destination, prefix, rate, connection_fee, description) VALUES (?, ?, ?, ?, ?)',
      [destination, prefix, rate, connection, description]
    );

    res.status(201).json({ message: 'Rate created successfully' });
  } catch (error) {
    console.error('Error creating rate:', error);
    res.status(500).json({ error: 'Failed to create rate' });
  }
});

app.put('/rates/:id', authenticateToken, async (req, res) => {
  try {
    if (!db) {
      return res.status(500).json({ error: 'Database not available' });
    }

    const { id } = req.params;
    const { destination, prefix, rate, connection, description } = req.body;

    await db.execute(
      'UPDATE rates SET destination = ?, prefix = ?, rate = ?, connection_fee = ?, description = ? WHERE id = ?',
      [destination, prefix, rate, connection, description, id]
    );

    res.json({ message: 'Rate updated successfully' });
  } catch (error) {
    console.error('Error updating rate:', error);
    res.status(500).json({ error: 'Failed to update rate' });
  }
});

app.delete('/rates/:id', authenticateToken, async (req, res) => {
  try {
    if (!db) {
      return res.status(500).json({ error: 'Database not available' });
    }

    const { id } = req.params;
    await db.execute('DELETE FROM rates WHERE id = ?', [id]);

    res.json({ message: 'Rate deleted successfully' });
  } catch (error) {
    console.error('Error deleting rate:', error);
    res.status(500).json({ error: 'Failed to delete rate' });
  }
});

// Call Quality routes
app.get('/call-quality', authenticateToken, async (req, res) => {
  try {
    if (!db) {
      return res.status(500).json({ error: 'Database not available' });
    }

    const { page = 1, limit = 50, date } = req.query;
    const offset = (page - 1) * limit;

    let query = 'SELECT * FROM cdr WHERE disposition IS NOT NULL';
    let params = [];

    if (date) {
      query += ' AND DATE(calldate) = ?';
      params.push(date);
    }

    query += ' ORDER BY calldate DESC LIMIT ? OFFSET ?';
    params.push(parseInt(limit), offset);

    const [records] = await db.execute(query, params);
    res.json({ records });
  } catch (error) {
    console.error('Error fetching call quality data:', error);
    res.status(500).json({ error: 'Failed to fetch call quality data' });
  }
});

// SMS Management routes
app.get('/sms', authenticateToken, async (req, res) => {
  try {
    if (!db) {
      return res.status(500).json({ error: 'Database not available' });
    }

    const { page = 1, limit = 50, search } = req.query;
    const offset = (page - 1) * limit;

    let query = 'SELECT * FROM sms_history';
    let params = [];

    if (search) {
      query += ' WHERE phone_number LIKE ? OR message LIKE ?';
      params.push(`%${search}%`, `%${search}%`);
    }

    query += ' ORDER BY created_at DESC LIMIT ? OFFSET ?';
    params.push(parseInt(limit), offset);

    const [records] = await db.execute(query, params);
    res.json({ records });
  } catch (error) {
    console.error('Error fetching SMS history:', error);
    res.status(500).json({ error: 'Failed to fetch SMS history' });
  }
});

app.post('/sms/send', authenticateToken, async (req, res) => {
  try {
    if (!db) {
      return res.status(500).json({ error: 'Database not available' });
    }

    const { recipients, message, schedule } = req.body;

    for (const recipient of recipients) {
      await db.execute(
        'INSERT INTO sms_history (phone_number, message, status, cost, scheduled_at) VALUES (?, ?, ?, ?, ?)',
        [recipient, message, schedule ? 'Scheduled' : 'Sent', 0.05, schedule]
      );
    }

    res.status(201).json({ message: 'SMS sent successfully' });
  } catch (error) {
    console.error('Error sending SMS:', error);
    res.status(500).json({ error: 'Failed to send SMS' });
  }
});

app.get('/sms/templates', authenticateToken, async (req, res) => {
  try {
    if (!db) {
      return res.status(500).json({ error: 'Database not available' });
    }

    const [templates] = await db.execute('SELECT * FROM sms_templates ORDER BY created_at DESC');
    res.json(templates);
  } catch (error) {
    console.error('Error fetching SMS templates:', error);
    res.status(500).json({ error: 'Failed to fetch SMS templates' });
  }
});

app.post('/sms/templates', authenticateToken, async (req, res) => {
  try {
    if (!db) {
      return res.status(500).json({ error: 'Database not available' });
    }

    const { title, message, category } = req.body;

    await db.execute(
      'INSERT INTO sms_templates (title, message, category) VALUES (?, ?, ?)',
      [title, message, category]
    );

    res.status(201).json({ message: 'SMS template created successfully' });
  } catch (error) {
    console.error('Error creating SMS template:', error);
    res.status(500).json({ error: 'Failed to create SMS template' });
  }
});

app.get('/sms/stats', authenticateToken, async (req, res) => {
  try {
    if (!db) {
      return res.status(500).json({ error: 'Database not available' });
    }

    const [sentResult] = await db.execute('SELECT COUNT(*) as count FROM sms_history');
    const [deliveredResult] = await db.execute('SELECT COUNT(*) as count FROM sms_history WHERE status = "Delivered"');
    const [failedResult] = await db.execute('SELECT COUNT(*) as count FROM sms_history WHERE status = "Failed"');
    const [costResult] = await db.execute('SELECT SUM(cost) as total FROM sms_history');

    res.json({
      sent: sentResult[0].count,
      delivered: deliveredResult[0].count,
      failed: failedResult[0].count,
      cost: costResult[0].total || 0
    });
  } catch (error) {
    console.error('Error fetching SMS stats:', error);
    res.status(500).json({ error: 'Failed to fetch SMS stats' });
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Something went wrong!' });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Endpoint not found' });
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
  if (db) {
    db.end();
  }
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  if (db) {
    db.end();
  }
  process.exit(0);
});

startServer().catch(console.error);
