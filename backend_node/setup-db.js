#!/usr/bin/env node

/**
 * Database Setup Script
 * يعد قاعدة البيانات والجداول للعمل
 */

const mysql = require('mysql2/promise');

async function setupDatabase() {
  try {
    console.log('http://localhost:7070 Setting up database...\n');

    // 1. Connect to MySQL (without database)
    console.log('📌 Connecting to MySQL...');
    const connection = await mysql.createConnection({
      host: process.env.DB_HOST || 'localhost',
      user: process.env.DB_USER || 'root',
      password: process.env.DB_PASSWORD || 'root',
      socketPath: process.env.DB_SOCKET || '/tmp/mysql.sock',
    });
    console.log('✓ Connected to MySQL\n');

    // 2. Create database if not exists
    const dbName = process.env.DB_NAME || 'esc_config';
    console.log(`📌 Creating database "${dbName}"...`);
    await connection.execute(
      `CREATE DATABASE IF NOT EXISTS ${dbName} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`
    );
    console.log(`✓ Database "${dbName}" ready\n`);

    // 3. Switch to database
    console.log(`📌 Using database "${dbName}"...`);
    await connection.query(`USE ${dbName}`);
    console.log('✓ Database selected\n');

    // 4. Create users table
    console.log('📌 Creating users table...');
    await connection.execute(`
      CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        email VARCHAR(255) NOT NULL UNIQUE,
        password VARCHAR(255) NOT NULL,
        name VARCHAR(255),
        email_verified BOOLEAN DEFAULT false,
        verify_token VARCHAR(255),
        verify_token_expire DATETIME,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_email (email),
        INDEX idx_verify_token (verify_token)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    console.log('✓ Users table created\n');

    // 5. Create esc_configs table
    console.log('📌 Creating esc_configs table...');
    await connection.execute(`
      CREATE TABLE IF NOT EXISTS esc_configs (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        name VARCHAR(255),
        profile_name VARCHAR(255),
        mode VARCHAR(50),
        cells INT,
        battery_voltage FLOAT,
        throttle_min INT,
        throttle_max INT,
        config_data JSON,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        INDEX idx_user_id (user_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    console.log('✓ ESC Configs table created\n');

    // 6. Create profiles table
    console.log('📌 Creating profiles table...');
    await connection.execute(`
      CREATE TABLE IF NOT EXISTS profiles (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        profile_name VARCHAR(255) NOT NULL,
        config_data JSON NOT NULL,
        description TEXT,
        is_default BOOLEAN DEFAULT false,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        INDEX idx_user_id (user_id),
        UNIQUE KEY unique_profile (user_id, profile_name)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    console.log('✓ Profiles table created\n');

    // 7. Create esc_profiles table
    console.log('📌 Creating esc_profiles table...');
    await connection.execute(`
      CREATE TABLE IF NOT EXISTS esc_profiles (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) UNIQUE NOT NULL,
        config_json LONGTEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_name (name),
        INDEX idx_updated_at (updated_at)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    console.log('✓ ESC Profiles table created\n');

    // 8. Close connection
    await connection.end();

    console.log(' Database setup completed successfully!\n');
    console.log('You can now run: npm start');
    process.exit(0);

  } catch (error) {
    console.error(' Database setup failed:', error.message);
    console.error('\nTroubleshooting:');
    console.error('1. Make sure MySQL is running: brew services list');
    console.error('2. Check credentials: DB_USER=root, DB_PASSWORD=root');
    console.error('3. Try: mysql -u root -p');
    process.exit(1);
  }
}

setupDatabase();
