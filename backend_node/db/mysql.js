/**
 * MySQL Database Connection Manager
 * Handles connection pool and queries
 */

const mysql = require('mysql2/promise');

class MySQLConnection {
  constructor(config = {}) {
    this.config = {
      host: config.host || process.env.DB_HOST || 'localhost',
      user: config.user || process.env.DB_USER || 'root',
      password: config.password || process.env.DB_PASSWORD || 'root',
      database: config.database || process.env.DB_NAME || 'esc_config',
      waitForConnections: true,
      connectionLimit: config.connectionLimit || 10,
      queueLimit: 0,
      socketPath: config.socketPath || '/tmp/mysql.sock',
    };

    this.pool = null;
  }

  /**
   * Initialize connection pool
   */
  async initialize() {
    try {
      this.pool = await mysql.createPool(this.config);
      console.log(`MySQL connected to ${this.config.database}`);
      return true;
    } catch (error) {
      console.error('Failed to initialize MySQL pool:', error.message);
      throw error;
    }
  }

  /**
   * Execute query
   */
  async execute(query, params = []) {
    if (!this.pool) {
      throw new Error('Database pool not initialized');
    }

    try {
      const connection = await this.pool.getConnection();
      const result = await connection.execute(query, params);
      connection.release();
      return result;
    } catch (error) {
      console.error('Query error:', error.message);
      throw error;
    }
  }

  /**
   * Execute multiple queries (transaction)
   */
  async beginTransaction() {
    if (!this.pool) {
      throw new Error('Database pool not initialized');
    }

    const connection = await this.pool.getConnection();
    await connection.beginTransaction();
    return connection;
  }

  /**
   * Close connection pool
   */
  async close() {
    if (this.pool) {
      await this.pool.end();
      console.log('MySQL pool closed');
    }
  }

  /**
   * Health check
   */
  async ping() {
    try {
      const [result] = await this.execute('SELECT 1');
      return true;
    } catch (error) {
      return false;
    }
  }

  /**
   * Create database if not exists
   */
  async createDatabase() {
    const noDbConfig = { ...this.config };
    delete noDbConfig.database;

    try {
      const tempPool = await mysql.createPool(noDbConfig);
      const [result] = await tempPool.execute(
        `CREATE DATABASE IF NOT EXISTS ${this.config.database} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`
      );
      await tempPool.end();
      console.log(`Database ${this.config.database} created or already exists`);
    } catch (error) {
      console.error('Failed to create database:', error.message);
      throw error;
    }
  }
}

module.exports = MySQLConnection;
