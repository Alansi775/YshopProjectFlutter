import pool from './src/config/database.js';

async function checkDB() {
  try {
    const connection = await pool.getConnection();
    
    // Check users table
    console.log('\n=== USERS TABLE ===');
    const [users] = await connection.query('SELECT * FROM users');
    console.table(users);
    
    // Check stores table
    console.log('\n=== STORES TABLE ===');
    const [stores] = await connection.query('SELECT * FROM stores');
    console.table(stores);
    
    connection.release();
    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

checkDB();
