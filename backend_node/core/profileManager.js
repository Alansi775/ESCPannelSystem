/**
 * Profile Manager
 * Handles saving, loading, and managing ESC configuration profiles
 */

class ProfileManager {
  constructor(dbConnection) {
    this.db = dbConnection;
  }

  /**
   * Save configuration profile
   */
  async saveProfile(profileName, config) {
    if (!profileName || profileName.trim() === '') {
      throw new Error('Profile name is required');
    }

    if (!config || typeof config !== 'object') {
      throw new Error('Invalid configuration object');
    }

    const query =
      'INSERT INTO esc_profiles (name, config_json, created_at, updated_at) VALUES (?, ?, NOW(), NOW()) ON DUPLICATE KEY UPDATE config_json = VALUES(config_json), updated_at = NOW()';

    try {
      const result = await this.db.execute(query, [
        profileName,
        JSON.stringify(config),
      ]);
      return { id: result.insertId, name: profileName, success: true };
    } catch (error) {
      throw new Error(`Failed to save profile: ${error.message}`);
    }
  }

  /**
   * Load all profiles
   */
  async loadAllProfiles() {
    const query =
      'SELECT id, name, config_json, created_at, updated_at FROM esc_profiles ORDER BY updated_at DESC';

    try {
      const [rows] = await this.db.execute(query);
      return rows.map((row) => ({
        id: row.id,
        name: row.name,
        config: JSON.parse(row.config_json),
        createdAt: row.created_at,
        updatedAt: row.updated_at,
      }));
    } catch (error) {
      throw new Error(`Failed to load profiles: ${error.message}`);
    }
  }

  /**
   * Load profile by ID
   */
  async loadProfileById(profileId) {
    const query =
      'SELECT id, name, config_json, created_at, updated_at FROM esc_profiles WHERE id = ?';

    try {
      const [rows] = await this.db.execute(query, [profileId]);
      if (rows.length === 0) {
        return null;
      }

      const row = rows[0];
      return {
        id: row.id,
        name: row.name,
        config: JSON.parse(row.config_json),
        createdAt: row.created_at,
        updatedAt: row.updated_at,
      };
    } catch (error) {
      throw new Error(`Failed to load profile: ${error.message}`);
    }
  }

  /**
   * Load profile by name
   */
  async loadProfileByName(profileName) {
    const query =
      'SELECT id, name, config_json, created_at, updated_at FROM esc_profiles WHERE name = ?';

    try {
      const [rows] = await this.db.execute(query, [profileName]);
      if (rows.length === 0) {
        return null;
      }

      const row = rows[0];
      return {
        id: row.id,
        name: row.name,
        config: JSON.parse(row.config_json),
        createdAt: row.created_at,
        updatedAt: row.updated_at,
      };
    } catch (error) {
      throw new Error(`Failed to load profile: ${error.message}`);
    }
  }

  /**
   * Delete profile
   */
  async deleteProfile(profileId) {
    const query = 'DELETE FROM esc_profiles WHERE id = ?';

    try {
      const result = await this.db.execute(query, [profileId]);
      return result.affectedRows > 0;
    } catch (error) {
      throw new Error(`Failed to delete profile: ${error.message}`);
    }
  }

  /**
   * Initialize database schema
   */
  async initializeSchema() {
    const createTableQuery = `
      CREATE TABLE IF NOT EXISTS esc_profiles (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) UNIQUE NOT NULL,
        config_json LONGTEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_name (name),
        INDEX idx_updated_at (updated_at)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `;

    try {
      await this.db.execute(createTableQuery);
      console.log('Database schema initialized successfully');
    } catch (error) {
      throw new Error(`Failed to initialize schema: ${error.message}`);
    }
  }
}

module.exports = ProfileManager;
