
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
    
    console.log('Database initialization completed');
  } catch (error) {
    console.error('Database initialization failed:', error);
    console.log('Server will continue but database operations may fail');
  }

  // Authentication routes
  app.post('/auth/login', async (req, res) => {
    const { username, password } = req.body;

    try {
      const users = await executeQuery('SELECT * FROM users WHERE username = ?', [username]);
      if (users.length === 0) {
        return res.status(401).json({ error: 'Invalid credentials' });
      }

      const user = users[0];
      const passwordMatch = await bcrypt.compare(password, user.password);

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
      const totalCustomers = (await executeQuery('SELECT COUNT(*) AS total FROM customers'))[0].total;
      const activeCustomers = (await executeQuery('SELECT COUNT(*) AS total FROM customers WHERE status = "active"'))[0].total;
      const totalDIDs = (await executeQuery('SELECT COUNT(*) AS total FROM did_numbers'))[0].total;
      const availableDIDs = (await executeQuery('SELECT COUNT(*) AS total FROM did_numbers WHERE customer_id IS NULL'))[0].total;

      res.json({
        totalCustomers,
        activeCustomers,
        totalDIDs,
        availableDIDs
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

// Start the server
startServer();
