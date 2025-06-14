
const mysql = require('mysql2/promise');

// Database connection configuration
const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 3306,
  user: process.env.DB_USER || 'asterisk',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'asterisk',
  connectionLimit: 10,
  acquireTimeout: 60000,
  timeout: 60000,
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
    console.log(`Password set: ${dbConfig.password ? 'Yes' : 'No (empty)'}`);
    
    db = mysql.createPool(dbConfig);
    
    // Test the connection
    const connection = await db.getConnection();
    await connection.ping();
    connection.release();
    console.log('✓ Database pool created and tested successfully');
    
    return true;
  } catch (error) {
    console.error('✗ Database pool creation failed:', error.message);
    console.error('Please check your database configuration and ensure MySQL is running');
    return false;
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

module.exports = {
  createDatabasePool,
  executeQuery,
  getPool: () => db
};
