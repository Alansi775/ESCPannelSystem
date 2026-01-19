/**
 * Authentication Routes
 * Handles signup, login, verification endpoints
 */

const crypto = require('crypto');
const AuthService = require('../services/authService');
const getEmailService = require('../services/emailService');

class AuthRoutes {
  constructor(dbConnection, serverIP = 'localhost:7070') {
    this.db = dbConnection;
    this.authService = new AuthService(dbConnection);
    this.emailService = getEmailService();
    this.serverIP = serverIP;
  }

  /**
   * POST /signup
   * Create new user account and send verification email
   */
  async handleSignup(req, res, body) {
    try {
      const { email, password, name, language = 'tr' } = body;

      // Validate input
      if (!email || !password) {
        return {
          statusCode: 400,
          data: { error: 'Email and password are required', code: 'MISSING_FIELDS' },
        };
      }

      // Register user
      const user = await this.authService.register(email, password, name);

      // Send verification email
      try {
        await this.emailService.sendVerificationEmail(
          user.email,
          user.verifyToken,
          this.serverIP,
          language
        );
      } catch (emailError) {
        console.error('Email sending failed:', emailError.message);
        // Don't fail signup if email sending fails
        // In production, you might want to retry this with a queue
      }

      return {
        statusCode: 201,
        data: {
          success: true,
          message: 'User registered. Please check your email to verify your account.',
          userId: user.id,
          email: user.email,
        },
      };
    } catch (error) {
      console.error('Signup error:', error.message);

      // Check for duplicate email
      if (error.message.includes('already exists')) {
        return {
          statusCode: 409,
          data: {
            error: 'Email already registered',
            code: 'EMAIL_EXISTS',
          },
        };
      }

      if (error.message.includes('at least 6 characters')) {
        return {
          statusCode: 400,
          data: {
            error: 'Password must be at least 6 characters',
            code: 'WEAK_PASSWORD',
          },
        };
      }

      return {
        statusCode: 500,
        data: { error: error.message, code: 'SIGNUP_ERROR' },
      };
    }
  }

  /**
   * POST /login
   * Authenticate user and check email verification
   */
  async handleLogin(req, res, body) {
    try {
      const { email, password } = body;

      // Validate input
      if (!email || !password) {
        return {
          statusCode: 400,
          data: { error: 'Email and password are required', code: 'MISSING_FIELDS' },
        };
      }

      // Authenticate
      const result = await this.authService.login(email, password);

      if (!result.verified) {
        return {
          statusCode: 403,
          data: {
            success: false,
            status: result.status,
            userId: result.id,
            message: result.message,
            code: 'NOT_VERIFIED',
          },
        };
      }

      return {
        statusCode: 200,
        data: {
          success: true,
          status: result.status,
          user: {
            id: result.id,
            email: result.email,
            name: result.name,
          },
          message: 'Login successful',
        },
      };
    } catch (error) {
      console.error('Login error:', error.message);

      if (error.message.includes('not found')) {
        return {
          statusCode: 401,
          data: {
            error: 'Invalid email or password',
            code: 'AUTH_FAILED',
          },
        };
      }

      if (error.message.includes('Invalid password')) {
        return {
          statusCode: 401,
          data: {
            error: 'Invalid email or password',
            code: 'AUTH_FAILED',
          },
        };
      }

      return {
        statusCode: 500,
        data: { error: error.message, code: 'LOGIN_ERROR' },
      };
    }
  }

  /**
   * GET /verify?token=XXX
   * Verify email with token
   */
  async handleVerify(req, res, query) {
    try {
      const { token, redirect } = query;

      if (!token) {
        return {
          statusCode: 400,
          data: { error: 'Verification token required', code: 'MISSING_TOKEN' },
          isRedirect: false,
        };
      }

      // Verify token
      const user = await this.authService.verifyToken(token);

      // Send welcome email (optional)
      try {
        const lang = query.lang || 'tr';
        await this.emailService.sendWelcomeEmail(user.email, user.name, lang);
      } catch (emailError) {
        console.error('Welcome email failed:', emailError.message);
      }

      // Return success response
      const htmlResponse = `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <title>Email Verified</title>
          <style>
            body {
              font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
              display: flex;
              justify-content: center;
              align-items: center;
              height: 100vh;
              margin: 0;
              background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            }
            .container {
              background: white;
              padding: 40px;
              border-radius: 10px;
              box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);
              text-align: center;
              max-width: 500px;
            }
            .success-icon {
              font-size: 60px;
              color: #34C759;
              margin-bottom: 20px;
            }
            h1 {
              color: #1C1C1E;
              margin-bottom: 10px;
            }
            p {
              color: #8E8E93;
              line-height: 1.6;
            }
            .button {
              display: inline-block;
              margin-top: 20px;
              padding: 12px 30px;
              background: #007AFF;
              color: white;
              text-decoration: none;
              border-radius: 5px;
              font-weight: bold;
            }
            .button:hover {
              background: #0056b3;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="success-icon">✓</div>
            <h1>Email Verified!</h1>
            <p>Your email has been successfully verified.</p>
            <p>You can now log in to your account.</p>
            <a href="${redirect || 'https://localhost:3000'}" class="button">Return to App</a>
          </div>
        </body>
        </html>
      `;

      return {
        statusCode: 200,
        data: {
          success: true,
          message: 'Email verified successfully',
          user: {
            id: user.id,
            email: user.email,
            name: user.name,
          },
        },
        htmlResponse,
      };
    } catch (error) {
      console.error('Verification error:', error.message);

      const htmlResponse = `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <title>Verification Failed</title>
          <style>
            body {
              font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
              display: flex;
              justify-content: center;
              align-items: center;
              height: 100vh;
              margin: 0;
              background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            }
            .container {
              background: white;
              padding: 40px;
              border-radius: 10px;
              box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);
              text-align: center;
              max-width: 500px;
            }
            .error-icon {
              font-size: 60px;
              color: #FF3B30;
              margin-bottom: 20px;
            }
            h1 {
              color: #1C1C1E;
              margin-bottom: 10px;
            }
            p {
              color: #8E8E93;
              line-height: 1.6;
            }
            .button {
              display: inline-block;
              margin-top: 20px;
              padding: 12px 30px;
              background: #007AFF;
              color: white;
              text-decoration: none;
              border-radius: 5px;
              font-weight: bold;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="error-icon">✗</div>
            <h1>Verification Failed</h1>
            <p>${error.message}</p>
            <p>Please request a new verification link.</p>
            <a href="https://localhost:3000" class="button">Return to App</a>
          </div>
        </body>
        </html>
      `;

      if (error.message.includes('already verified')) {
        return {
          statusCode: 400,
          data: {
            error: 'Email already verified',
            code: 'ALREADY_VERIFIED',
          },
          htmlResponse,
        };
      }

      if (error.message.includes('Invalid or expired')) {
        return {
          statusCode: 400,
          data: {
            error: 'Invalid or expired verification token',
            code: 'INVALID_TOKEN',
          },
          htmlResponse,
        };
      }

      return {
        statusCode: 500,
        data: {
          error: error.message,
          code: 'VERIFY_ERROR',
        },
        htmlResponse,
      };
    }
  }

  /**
   * POST /resend-verification
   * Resend verification email
   */
  async handleResendVerification(req, res, body) {
    try {
      const { email, language = 'tr' } = body;

      if (!email) {
        return {
          statusCode: 400,
          data: { error: 'Email required', code: 'MISSING_EMAIL' },
        };
      }

      // Get user and regenerate token
      const user = await this.authService.regenerateVerificationToken(
        body.userId || 0
      );

      // Send email
      try {
        await this.emailService.sendResendVerificationEmail(
          user.email,
          user.verifyToken,
          this.serverIP,
          language
        );
      } catch (emailError) {
        console.error('Email resend failed:', emailError.message);
      }

      return {
        statusCode: 200,
        data: {
          success: true,
          message: 'Verification email sent. Please check your inbox.',
        },
      };
    } catch (error) {
      console.error('Resend verification error:', error.message);

      return {
        statusCode: 500,
        data: {
          error: error.message,
          code: 'RESEND_ERROR',
        },
      };
    }
  }

  /**
   * POST /change-password
   * Change user password
   */
  async handleChangePassword(req, res, body) {
    try {
      const { userId, oldPassword, newPassword } = body;

      if (!userId || !oldPassword || !newPassword) {
        return {
          statusCode: 400,
          data: { error: 'Missing required fields', code: 'MISSING_FIELDS' },
        };
      }

      const result = await this.authService.changePassword(userId, oldPassword, newPassword);

      return {
        statusCode: 200,
        data: {
          success: true,
          message: 'Password changed successfully',
        },
      };
    } catch (error) {
      console.error('Change password error:', error.message);

      if (error.message.includes('incorrect')) {
        return {
          statusCode: 401,
          data: {
            error: error.message,
            code: 'INVALID_PASSWORD',
          },
        };
      }

      return {
        statusCode: 500,
        data: {
          error: error.message,
          code: 'PASSWORD_CHANGE_ERROR',
        },
      };
    }
  }

  /**
   * POST /forgot-password
   * Send password reset email
   */
  async handleForgotPassword(req, res, body) {
    try {
      const { email, language = 'en' } = body;

      if (!email) {
        return {
          statusCode: 400,
          data: { error: 'Email is required', code: 'MISSING_EMAIL' },
        };
      }

      // Generate reset token
      const resetData = await this.authService.generatePasswordResetToken(email);

      // Send reset email
      try {
        await this.emailService.sendPasswordResetEmail(
          resetData.email,
          resetData.resetToken,
          this.serverIP,
          language
        );
      } catch (emailError) {
        console.error('Password reset email failed:', emailError.message);
      }

      return {
        statusCode: 200,
        data: {
          success: true,
          message: 'Password reset link sent to your email',
        },
      };
    } catch (error) {
      console.error('Forgot password error:', error.message);

      if (error.message.includes('not found')) {
        return {
          statusCode: 404,
          data: {
            error: 'User not found',
            code: 'USER_NOT_FOUND',
          },
        };
      }

      return {
        statusCode: 500,
        data: {
          error: error.message,
          code: 'FORGOT_PASSWORD_ERROR',
        },
      };
    }
  }

  /**
   * GET /reset-password?token=...
   * Verify and reset password with token
   */
  async handleResetPasswordPage(req, res, token) {
    try {
      if (!token) {
        return {
          statusCode: 400,
          data: '<h1>Invalid reset link</h1>',
          contentType: 'text/html',
        };
      }

      const newPassword = crypto.randomBytes(8).toString('hex');

      const result = await this.authService.resetPasswordWithToken(token, newPassword);

      const htmlResponse = `
        <!DOCTYPE html>
        <html>
        <head>
          <title>Password Reset</title>
          <style>
            body { font-family: Arial; background: #f5f5f5; margin: 0; padding: 20px; }
            .container { max-width: 500px; margin: 50px auto; background: white; padding: 40px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
            h1 { color: #333; text-align: center; }
            .code { background: #f9f9f9; padding: 15px; border-radius: 5px; font-family: monospace; font-size: 16px; text-align: center; margin: 20px 0; border: 1px solid #ddd; }
            .success { color: green; text-align: center; }
            p { color: #666; line-height: 1.6; }
          </style>
        </head>
        <body>
          <div class="container">
            <h1 class="success">✓ Password Reset Successful</h1>
            <p>Your password has been reset. You can now log in with your new temporary password:</p>
            <div class="code">${newPassword}</div>
            <p><strong>Important:</strong> Use this password to log in, then change it in your profile settings.</p>
            <p>If you didn't request this reset, please contact support immediately.</p>
          </div>
        </body>
        </html>
      `;

      return {
        statusCode: 200,
        data: htmlResponse,
        contentType: 'text/html',
      };
    } catch (error) {
      console.error('Reset password error:', error.message);

      const errorHtml = `
        <!DOCTYPE html>
        <html>
        <head>
          <title>Error</title>
          <style>
            body { font-family: Arial; background: #f5f5f5; margin: 0; padding: 20px; }
            .container { max-width: 500px; margin: 50px auto; background: white; padding: 40px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
            h1 { color: #d32f2f; text-align: center; }
            p { color: #666; text-align: center; }
          </style>
        </head>
        <body>
          <div class="container">
            <h1>✗ Reset Failed</h1>
            <p>${error.message}</p>
            <p>The reset link may have expired. Please try again.</p>
          </div>
        </body>
        </html>
      `;

      return {
        statusCode: 400,
        data: errorHtml,
        contentType: 'text/html',
      };
    }
  }
}

module.exports = AuthRoutes;
