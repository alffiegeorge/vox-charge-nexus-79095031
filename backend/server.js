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

// Database connection with fallback values
const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 3306,
  user: process.env.DB_USER || 'asterisk',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'asterisk',
  connectionLimit: 10,
  acquireTimeout: 60000,
  timeout: 60000,
  reconnect: true
};

let db;

async function initializeDatabase() {
  try {
    console.log('Attempting to connect to database...');
    console.log(`Host: ${dbConfig.host}:${dbConfig.port}`);
    console.log(`Database: ${dbConfig.database}`);
    console.log(`User: ${dbConfig.user}`);
    
    db = mysql.createPool(dbConfig);
    console.log('✓ Database pool created');
    
    // Test connection
    const connection = await db.getConnection();
    await connection.ping();
    connection.release();
    console.log('✓ Database connection test successful');
    
    // Create users table if it doesn't exist
    await createUsersTable();
    
  } catch (error) {
    console.error('✗ Database connection failed:', error.message);
    console.error('Please check your database configuration and ensure MySQL is running');
    // Don't exit the process, allow the server to start without DB for debugging
    console.log('Server will start without database connection for debugging');
  }
}

async function createUsersTable() {
  try {
    console.log('Creating/checking users table...');
    await db.execute(`
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
    
    // Check if admin user exists, if not create it
    const [existingAdmin] = await db.execute('SELECT COUNT(*) as count FROM users WHERE username = ?', ['admin']);
    console.log('Admin user check result:', existingAdmin[0]);
    
    if (existingAdmin[0].count === 0) {
      console.log('Creating default admin user...');
      const hashedPassword = await bcrypt.hash('admin123', 10);
      console.log('Admin password hash generated:', hashedPassword);
      await db.execute(
        'INSERT INTO users (username, password, email, role, status) VALUES (?, ?, ?, ?, ?)',
        ['admin', hashedPassword, 'admin@ibilling.local', 'admin', 'active']
      );
      console.log('✓ Default admin user created with password: admin123');
    } else {
      console.log('Admin user already exists');
    }
    
    // Check if customer user exists, if not create it
    const [existingCustomer] = await db.execute('SELECT COUNT(*) as count FROM users WHERE username = ?', ['customer']);
    console.log('Customer user check result:', existingCustomer[0]);
    
    if (existingCustomer[0].count === 0) {
      console.log('Creating default customer user...');
      const hashedPassword = await bcrypt.hash('customer123', 10);
      console.log('Customer password hash generated:', hashedPassword);
      await db.execute(
        'INSERT INTO users (username, password, email, role, status) VALUES (?, ?, ?, ?, ?)',
        ['customer', hashedPassword, 'customer@ibilling.local', 'customer', 'active']
      );
      console.log('✓ Default customer user created with password: customer123');
    } else {
      console.log('Customer user already exists');
    }
    
    // Let's also verify the users are in the database
    const [allUsers] = await db.execute('SELECT id, username, role, status FROM users');
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
  try {
    const { username, password } = req.body;
    
    console.log('=== LOGIN ATTEMPT ===');
    console.log('Username:', username);
    console.log('Password provided:', password ? 'Yes' : 'No');
    console.log('Password length:', password ? password.length : 0);
    console.log('Request body:', req.body);

    if (!username || !password) {
      console.log('Missing username or password');
      return res.status(400).json({ error: 'Username and password required' });
    }

    if (!db) {
      console.log('Database not available');
      return res.status(500).json({ error: 'Database not available' });
    }

    // Check users table for authentication
    console.log('Querying database for user:', username);
    const [users] = await db.execute(
      'SELECT id, username, password, email, role, status FROM users WHERE username = ?',
      [username]
    );

    console.log('Database query result count:', users.length);
    if (users.length > 0) {
      const user = users[0];
      console.log('User found:');
      console.log('- ID:', user.id);
      console.log('- Username:', user.username);
      console.log('- Role:', user.role);
      console.log('- Status:', user.status);
      console.log('- Email:', user.email);
      console.log('- Stored password hash:', user.password);
      
      if (user.status !== 'active') {
        console.log('User account is not active:', user.status);
        return res.status(401).json({ error: 'Account is not active' });
      }
      
      console.log('Comparing passwords...');
      console.log('Input password:', password);
      console.log('Stored hash:', user.password);
      
      const isValidPassword = await bcrypt.compare(password, user.password);
      console.log('Password comparison result:', isValidPassword);

      if (!isValidPassword) {
        console.log('Password comparison failed');
        return res.status(401).json({ error: 'Invalid credentials' });
      }

      console.log('Login successful for user:', username);

      const token = jwt.sign(
        { id: user.id, username: user.username, role: user.role },
        process.env.JWT_SECRET || 'your-secret-key',
        { expiresIn: '24h' }
      );

      res.json({
        token,
        user: {
          id: user.id,
          username: user.username,
          role: user.role,
          email: user.email
        }
      });
    } else {
      console.log('No user found with username:', username);
      return res.status(401).json({ error: 'Invalid credentials' });
    }

  } catch (error) {
    console.error('Login error:', error);
    console.error('Error stack:', error.stack);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Customer routes
app.get('/customers', authenticateToken, async (req, res) => {
  try {
    if (!db) {
      return res.status(500).json({ error: 'Database not available' });
    }

    const [customers] = await db.execute('SELECT * FROM customers ORDER BY created_at DESC');
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

    await db.execute(
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
