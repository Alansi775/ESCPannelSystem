/**
 * Database Schema Manager
 * Creates and manages database tables
 */

class DatabaseSchema {
  constructor(dbConnection) {
    this.db = dbConnection;
  }

  /**
   * Initialize all tables
   */
  async initialize() {
    try {
      console.log('Initializing database schema...');
      
      // Create users table
      await this.createUsersTable();
      
      // Create configs table
      await this.createConfigsTable();
      
      // Create profiles table
      await this.createProfilesTable();
      
      console.log('✓ All tables initialized successfully');
      return true;
    } catch (error) {
      console.error('✗ Schema initialization failed:', error.message);
      throw error;
    }
  }

  /**
   * Create users table with email verification fields
   */
  async createUsersTable() {
    const query = `
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
    `;

    try {
      await this.db.execute(query);
      console.log('✓ users table created/verified');
    } catch (error) {
      if (error.message.includes('already exists')) {
        console.log('✓ users table already exists');
      } else {
        throw error;
      }
    }
  }

  /**
   * Create configs table
   */
  async createConfigsTable() {
    const query = `
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
    `;

    try {
      await this.db.execute(query);
      console.log('✓ esc_configs table created/verified');
    } catch (error) {
      if (error.message.includes('already exists')) {
        console.log('✓ esc_configs table already exists');
      } else {
        throw error;
      }
    }
  }

  /**
   * Create profiles table
   */
  async createProfilesTable() {
    const query = `
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
    `;

    try {
      await this.db.execute(query);
      console.log('✓ profiles table created/verified');
    } catch (error) {
      if (error.message.includes('already exists')) {
        console.log('✓ profiles table already exists');
      } else {
        throw error;
      }
    }
  }
}

module.exports = DatabaseSchema;
