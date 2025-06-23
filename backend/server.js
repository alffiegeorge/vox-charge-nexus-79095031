const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const dotenv = require('dotenv');

dotenv.config();

const app = express();
const port = process.env.PORT || 3001;

// Enable CORS for all routes
app.use(cors());

// Middleware to parse JSON bodies
app.use(express.json());

// Database connection
const { executeQuery, createDatabasePool } = require('./database');

// Setup database tables on startup
const { setupDIDTables } = require('./routes/setup-did-tables');

// Initialize database and start server
async function startServer() {
  try {
    console.log('Initializing database connection...');
    await createDatabasePool();
    
    console.log('Setting up DID tables...');
    await setupDIDTables();
    
    // Ensure default admin user exists with proper password hash
    await setupDefaultUsers();
    
    console.log('Database initialization completed');
  } catch (error) {
    console.error('Database initialization failed:', error);
    console.log('Server will continue but database operations may fail');
  }

  // Authentication routes
  app.post('/auth/login', async (req, res) => {
    const { username, password } = req.body;

    try {
      console.log('Login attempt for username:', username);
      
      const result = await executeQuery('SELECT * FROM users WHERE username = ?', [username]);
      const users = result[0]; // Get the actual data from the result
      
      if (!users || users.length === 0) {
        console.log('User not found:', username);
        return res.status(401).json({ error: 'Invalid credentials' });
      }

      const user = users[0];
      console.log('User found:', { id: user.id, username: user.username, role: user.role });
      console.log('Password hash exists:', !!user.password);

      // Check if password hash exists
      if (!user.password) {
        console.error('User password hash is missing for:', username);
        return res.status(401).json({ error: 'Account setup incomplete. Please contact administrator.' });
      }

      const passwordMatch = await bcrypt.compare(password, user.password);
      console.log('Password match:', passwordMatch);

      if (!passwordMatch) {
        return res.status(401).json({ error: 'Invalid credentials' });
      }

      const token = jwt.sign({ id: user.id, role: user.role, username: user.username, email: user.email }, process.env.JWT_SECRET, { expiresIn: '12h' });
      res.json({ token: token, user: { id: user.id, username: user.username, role: user.role, email: user.email } });

    } catch (error) {
      console.error('Login error:', error);
      res.status(500).json({ error: 'Login failed' });
    }
  });

  // API Routes
  app.use('/api/customers', require('./routes/customers'));
  app.use('/api/cdr', require('./routes/cdr'));
  app.use('/api/dids', require('./routes/dids'));

  // Dashboard stats route
  app.get('/api/dashboard/stats', async (req, res) => {
    try {
      const totalCustomersResult = await executeQuery('SELECT COUNT(*) AS total FROM customers');
      const activeCustomersResult = await executeQuery('SELECT COUNT(*) AS total FROM customers WHERE status = "active"');
      const totalDIDsResult = await executeQuery('SELECT COUNT(*) AS total FROM did_numbers');
      const availableDIDsResult = await executeQuery('SELECT COUNT(*) AS total FROM did_numbers WHERE customer_id IS NULL');

      res.json({
        totalCustomers: totalCustomersResult[0][0].total,
        activeCustomers: activeCustomersResult[0][0].total,
        totalDIDs: totalDIDsResult[0][0].total,
        availableDIDs: availableDIDsResult[0][0].total
      });
    } catch (error) {
      console.error('Error fetching dashboard stats:', error);
      res.status(500).json({ error: 'Failed to fetch dashboard stats' });
    }
  });

  // Health check endpoint
  app.get('/health', (req, res) => {
    res.json({ status: 'OK', message: 'API is healthy' });
  });

  // Error handling middleware
  app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).send('Internal Server Error!');
  });

  // Start the server
  app.listen(port, () => {
    console.log(`Server is running on port ${port}`);
  });
}

// Function to ensure default users exist
async function setupDefaultUsers() {
  try {
    console.log('Setting up default users...');
    
    // Check if admin user exists
    const adminResult = await executeQuery('SELECT * FROM users WHERE username = ?', ['admin']);
    const adminUsers = adminResult[0];
    
    if (!adminUsers || adminUsers.length === 0) {
      console.log('Creating default admin user...');
      
      // Hash the password 'admin123'
      const hashedPassword = await bcrypt.hash('admin123', 10);
      
      await executeQuery(`
        INSERT INTO users (username, password, email, role, status) 
        VALUES (?, ?, ?, ?, ?)
      `, ['admin', hashedPassword, 'admin@ibilling.local', 'admin', 'active']);
      
      console.log('✓ Default admin user created');
    } else if (!adminUsers[0].password) {
      console.log('Fixing admin user password...');
      
      // Hash the password 'admin123' and update
      const hashedPassword = await bcrypt.hash('admin123', 10);
      
      await executeQuery(`
        UPDATE users SET password = ? WHERE username = ?
      `, [hashedPassword, 'admin']);
      
      console.log('✓ Admin user password fixed');
    } else {
      console.log('✓ Admin user already exists with password');
    }
    
    // Check if customer user exists
    const customerResult = await executeQuery('SELECT * FROM users WHERE username = ?', ['customer']);
    const customerUsers = customerResult[0];
    
    if (!customerUsers || customerUsers.length === 0) {
      console.log('Creating default customer user...');
      
      // Hash the password 'customer123'
      const hashedPassword = await bcrypt.hash('customer123', 10);
      
      await executeQuery(`
        INSERT INTO users (username, password, email, role, status) 
        VALUES (?, ?, ?, ?, ?)
      `, ['customer', hashedPassword, 'customer@ibilling.local', 'customer', 'active']);
      
      console.log('✓ Default customer user created');
    } else if (!customerUsers[0].password) {
      console.log('Fixing customer user password...');
      
      // Hash the password 'customer123' and update
      const hashedPassword = await bcrypt.hash('customer123', 10);
      
      await executeQuery(`
        UPDATE users SET password = ? WHERE username = ?
      `, [hashedPassword, 'customer']);
      
      console.log('✓ Customer user password fixed');
    } else {
      console.log('✓ Customer user already exists with password');
    }
    
  } catch (error) {
    console.error('Error setting up default users:', error);
  }
}

// Start the server
startServer();
