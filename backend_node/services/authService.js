/**
 * Authentication Service
 * Handles user registration, login, password hashing, token generation
 */

const bcrypt = require('bcrypt');
const crypto = require('crypto');

class AuthService {
  constructor(dbConnection) {
    this.db = dbConnection;
    this.SALT_ROUNDS = 10;
    this.TOKEN_EXPIRY_HOURS = 24;
  }

  /**
   * Hash password
   */
  async hashPassword(password) {
    try {
      const hash = await bcrypt.hash(password, this.SALT_ROUNDS);
      return hash;
    } catch (error) {
      throw new Error(`Failed to hash password: ${error.message}`);
    }
  }

  /**
   * Compare password with hash
   */
  async comparePassword(password, hash) {
    try {
      const isMatch = await bcrypt.compare(password, hash);
      return isMatch;
    } catch (error) {
      throw new Error(`Failed to compare password: ${error.message}`);
    }
  }

  /**
   * Generate verification token
   */
  generateVerificationToken() {
    return crypto.randomBytes(32).toString('hex');
  }

  /**
   * Calculate token expiry time
   */
  getTokenExpiryTime(hours = this.TOKEN_EXPIRY_HOURS) {
    const expiry = new Date();
    expiry.setHours(expiry.getHours() + hours);
    return expiry;
  }

  /**
   * Register new user
   * @param {string} email - User email
   * @param {string} password - User password (plaintext)
   * @param {string} name - User name (optional)
   * @returns {object} User info with verification token
   */
  async register(email, password, name = '') {
    try {
      // Validate input
      if (!email || !password) {
        throw new Error('Email and password are required');
      }

      if (password.length < 6) {
        throw new Error('Password must be at least 6 characters');
      }

      // Check if user already exists
      const [existingUser] = await this.db.execute(
        'SELECT id FROM users WHERE email = ?',
        [email.toLowerCase()]
      );

      if (existingUser.length > 0) {
        throw new Error('User already exists with this email');
      }

      // Hash password
      const hashedPassword = await this.hashPassword(password);

      // Generate verification token
      const verifyToken = this.generateVerificationToken();
      const verifyTokenExpire = this.getTokenExpiryTime();

      // Insert user
      const [result] = await this.db.execute(
        `INSERT INTO users (email, password, name, verify_token, verify_token_expire, email_verified)
         VALUES (?, ?, ?, ?, ?, false)`,
        [email.toLowerCase(), hashedPassword, name, verifyToken, verifyTokenExpire]
      );

      return {
        id: result.insertId,
        email: email.toLowerCase(),
        name,
        verifyToken,
      };
    } catch (error) {
      throw error;
    }
  }

  /**
   * Login user
   * @param {string} email - User email
   * @param {string} password - User password (plaintext)
   * @returns {object} User info if credentials match
   */
  async login(email, password) {
    try {
      if (!email || !password) {
        throw new Error('Email and password are required');
      }

      // Find user
      const [users] = await this.db.execute(
        'SELECT id, email, password, name, email_verified FROM users WHERE email = ?',
        [email.toLowerCase()]
      );

      if (users.length === 0) {
        throw new Error('User not found');
      }

      const user = users[0];

      // Compare password
      const isPasswordMatch = await this.comparePassword(password, user.password);
      if (!isPasswordMatch) {
        throw new Error('Invalid password');
      }

      // Check if email is verified
      if (!user.email_verified) {
        return {
          id: user.id,
          email: user.email,
          name: user.name,
          verified: false,
          status: 'NOT_VERIFIED',
          message: 'Email not verified. Please check your inbox.',
        };
      }

      return {
        id: user.id,
        email: user.email,
        name: user.name,
        verified: true,
        status: 'SUCCESS',
      };
    } catch (error) {
      throw error;
    }
  }

  /**
   * Verify email token
   * @param {string} token - Verification token
   * @returns {object} User info after verification
   */
  async verifyToken(token) {
    try {
      if (!token) {
        throw new Error('Verification token required');
      }

      // Find user with token
      const [users] = await this.db.execute(
        `SELECT id, email, name, verify_token_expire, email_verified 
         FROM users 
         WHERE verify_token = ?`,
        [token]
      );

      if (users.length === 0) {
        throw new Error('Invalid or expired verification token');
      }

      const user = users[0];

      // Check if already verified
      if (user.email_verified) {
        throw new Error('Email already verified');
      }

      // Check token expiry
      const now = new Date();
      if (new Date(user.verify_token_expire) < now) {
        throw new Error('Verification token has expired');
      }

      // Update user - mark as verified and clear token
      await this.db.execute(
        `UPDATE users 
         SET email_verified = true, verify_token = NULL, verify_token_expire = NULL
         WHERE id = ?`,
        [user.id]
      );

      return {
        id: user.id,
        email: user.email,
        name: user.name,
        verified: true,
        message: 'Email verified successfully',
      };
    } catch (error) {
      throw error;
    }
  }

  /**
   * Resend verification email
   * Generate new token and update user
   */
  async regenerateVerificationToken(userId) {
    try {
      const verifyToken = this.generateVerificationToken();
      const verifyTokenExpire = this.getTokenExpiryTime();

      const [result] = await this.db.execute(
        `UPDATE users 
         SET verify_token = ?, verify_token_expire = ?
         WHERE id = ? AND email_verified = false`,
        [verifyToken, verifyTokenExpire, userId]
      );

      if (result.affectedRows === 0) {
        throw new Error('User not found or already verified');
      }

      // Get updated user email
      const [users] = await this.db.execute(
        'SELECT email FROM users WHERE id = ?',
        [userId]
      );

      if (users.length === 0) {
        throw new Error('User not found');
      }

      return {
        userId,
        email: users[0].email,
        verifyToken,
      };
    } catch (error) {
      throw error;
    }
  }

  /**
   * Get user by ID
   */
  async getUserById(userId) {
    try {
      const [users] = await this.db.execute(
        'SELECT id, email, name, lastname, email_verified FROM users WHERE id = ?',
        [userId]
      );

      if (users.length === 0) {
        return null;
      }

      return users[0];
    } catch (error) {
      throw error;
    }
  }

  /**
   * Change password
   */
  async changePassword(userId, oldPassword, newPassword) {
    try {
      if (!oldPassword || !newPassword) {
        throw new Error('Old and new passwords are required');
      }

      if (newPassword.length < 6) {
        throw new Error('New password must be at least 6 characters');
      }

      // Get user
      const [users] = await this.db.execute(
        'SELECT password FROM users WHERE id = ?',
        [userId]
      );

      if (users.length === 0) {
        throw new Error('User not found');
      }

      // Verify old password
      const isMatch = await this.comparePassword(oldPassword, users[0].password);
      if (!isMatch) {
        throw new Error('Current password is incorrect');
      }

      // Hash new password
      const hashedPassword = await this.hashPassword(newPassword);

      // Update password
      await this.db.execute(
        'UPDATE users SET password = ? WHERE id = ?',
        [hashedPassword, userId]
      );

      return {
        success: true,
        message: 'Password changed successfully'
      };
    } catch (error) {
      throw error;
    }
  }

  /**
   * Generate password reset token
   */
  async generatePasswordResetToken(email) {
    try {
      // Check if user exists
      const [users] = await this.db.execute(
        'SELECT id FROM users WHERE email = ?',
        [email.toLowerCase()]
      );

      if (users.length === 0) {
        throw new Error('User not found');
      }

      const userId = users[0].id;

      // Generate token
      const resetToken = this.generateVerificationToken();
      const resetTokenExpire = this.getTokenExpiryTime(1); // 1 hour for password reset

      // Store token
      await this.db.execute(
        'UPDATE users SET reset_token = ?, reset_token_expire = ? WHERE id = ?',
        [resetToken, resetTokenExpire, userId]
      );

      return {
        userId,
        email: email.toLowerCase(),
        resetToken,
      };
    } catch (error) {
      throw error;
    }
  }

  /**
   * Reset password with token
   */
  async resetPasswordWithToken(token, newPassword) {
    try {
      if (!newPassword) {
        throw new Error('New password is required');
      }

      if (newPassword.length < 6) {
        throw new Error('New password must be at least 6 characters');
      }

      // Find user with valid token
      const [users] = await this.db.execute(
        'SELECT id FROM users WHERE reset_token = ? AND reset_token_expire > NOW()',
        [token]
      );

      if (users.length === 0) {
        throw new Error('Invalid or expired reset token');
      }

      const userId = users[0].id;

      // Hash new password
      const hashedPassword = await this.hashPassword(newPassword);

      // Update password and clear token
      await this.db.execute(
        'UPDATE users SET password = ?, reset_token = NULL, reset_token_expire = NULL WHERE id = ?',
        [hashedPassword, userId]
      );

      return {
        success: true,
        message: 'Password reset successfully'
      };
    } catch (error) {
      throw error;
    }
  }
}

module.exports = AuthService;
