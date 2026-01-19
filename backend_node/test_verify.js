const mysql = require('mysql2/promise');

async function getToken() {
  const pool = await mysql.createPool({
    host: 'localhost',
    user: 'root',
    password: 'root',
    database: 'esc_config'
  });

  const [results] = await pool.execute(
    'SELECT verify_token FROM users WHERE email = ? AND email_verified = false LIMIT 1',
    ['test@example.com']
  );

  if (results.length > 0) {
    console.log(results[0].verify_token);
  }
  await pool.end();
}

getToken();
