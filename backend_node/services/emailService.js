/**
 * Email Service
 * Handles email sending via nodemailer
 * Supports multiple providers (Gmail, SMTP, etc.)
 */

const nodemailer = require('nodemailer');

class EmailService {
  constructor() {
    this.transporter = null;
    this.isInitialized = false;
  }

  /**
   * Initialize email transporter
   * Supports Gmail, custom SMTP, or test account
   */
  async initialize() {
    try {
      // Try Gmail first (set env vars GMAIL_USER and GMAIL_PASS)
      if (process.env.GMAIL_USER && process.env.GMAIL_PASS) {
        this.transporter = nodemailer.createTransport({
          service: 'gmail',
          auth: {
            user: process.env.GMAIL_USER,
            pass: process.env.GMAIL_PASS,
          },
        });
        console.log('✓ Email service initialized with Gmail');
      } 
      // Try custom SMTP
      else if (process.env.SMTP_HOST) {
        this.transporter = nodemailer.createTransport({
          host: process.env.SMTP_HOST,
          port: process.env.SMTP_PORT || 587,
          secure: process.env.SMTP_SECURE === 'true',
          auth: {
            user: process.env.SMTP_USER,
            pass: process.env.SMTP_PASS,
          },
        });
        console.log('✓ Email service initialized with custom SMTP');
      }
      // Fallback: create test account for development
      else {
        const testAccount = await nodemailer.createTestAccount();
        this.transporter = nodemailer.createTransport({
          host: 'smtp.ethereal.email',
          port: 587,
          secure: false,
          auth: {
            user: testAccount.user,
            pass: testAccount.pass,
          },
        });
        console.log('⚠ Email service initialized with test account (development mode)');
        console.log(`Preview URL: https://ethereal.email/messages`);
      }

      this.isInitialized = true;
      return true;
    } catch (error) {
      console.error('✗ Failed to initialize email service:', error.message);
      throw error;
    }
  }

  /**
   * Send verification email
   * @param {string} email - Recipient email
   * @param {string} token - Verification token
   * @param {string} serverIP - Server IP for verification link
   * @param {string} lang - Language (en, tr)
   */
  async sendVerificationEmail(email, token, serverIP = 'localhost:7070', lang = 'tr') {
    if (!this.isInitialized) {
      throw new Error('Email service not initialized');
    }

    // Generate verification link
    const protocol = process.env.NODE_ENV === 'production' ? 'https' : 'http';
    const verifyLink = `${protocol}://${serverIP}/verify?token=${token}`;

    // Email templates
    const templates = {
      tr: {
        subject: 'ESC Yapılandırıcı - Email Doğrulaması',
        text: `
Merhaba,

ESC Yapılandırıcı uygulamasına kaydolduğunuz için teşekkür ederiz.

Lütfen hesabınızı doğrulamak için aşağıdaki bağlantıya tıklayın:
${verifyLink}

Bu bağlantı 24 saat içinde geçerlidir.

Eğer bu kaydı yapmadıysanız, lütfen bu e-postayı görmezden gelin.

Saygılarımızla,
ESC Yapılandırıcı Takımı
        `,
        html: `
<h2>Email Doğrulaması</h2>
<p>Merhaba,</p>
<p>ESC Yapılandırıcı uygulamasına kaydolduğunuz için teşekkür ederiz.</p>
<p>Lütfen hesabınızı doğrulamak için aşağıdaki düğmeye tıklayın:</p>
<p>
  <a href="${verifyLink}" style="display: inline-block; padding: 10px 20px; background-color: #007AFF; color: white; text-decoration: none; border-radius: 5px; font-weight: bold;">
    Email'i Doğrula
  </a>
</p>
<p>Ya da bu bağlantıyı tarayıcınıza yapıştırın:</p>
<p><code>${verifyLink}</code></p>
<p style="color: #666; font-size: 12px;">Bu bağlantı 24 saat içinde geçerlidir.</p>
<p style="color: #999; font-size: 12px;">Eğer bu kaydı yapmadıysanız, lütfen bu e-postayı görmezden gelin.</p>
        `,
      },
      en: {
        subject: 'ESC Configurator - Email Verification',
        text: `
Hello,

Thank you for signing up for the ESC Configurator app.

Please verify your account by clicking the link below:
${verifyLink}

This link will expire in 24 hours.

If you did not create this account, please ignore this email.

Best regards,
ESC Configurator Team
        `,
        html: `
<h2>Email Verification</h2>
<p>Hello,</p>
<p>Thank you for signing up for the ESC Configurator app.</p>
<p>Please verify your account by clicking the button below:</p>
<p>
  <a href="${verifyLink}" style="display: inline-block; padding: 10px 20px; background-color: #007AFF; color: white; text-decoration: none; border-radius: 5px; font-weight: bold;">
    Verify Email
  </a>
</p>
<p>Or paste this link in your browser:</p>
<p><code>${verifyLink}</code></p>
<p style="color: #666; font-size: 12px;">This link will expire in 24 hours.</p>
<p style="color: #999; font-size: 12px;">If you did not create this account, please ignore this email.</p>
        `,
      },
    };

    const template = templates[lang] || templates.en;

    try {
      const mailOptions = {
        from: process.env.EMAIL_FROM || 'noreply@escconfigrator.app',
        to: email,
        subject: template.subject,
        text: template.text,
        html: template.html,
      };

      const info = await this.transporter.sendMail(mailOptions);

      console.log(`✓ Verification email sent to ${email}`);
      
      // For development/testing
      if (process.env.NODE_ENV !== 'production') {
        console.log(`Preview URL: ${nodemailer.getTestMessageUrl(info)}`);
      }

      return true;
    } catch (error) {
      console.error(`✗ Failed to send email to ${email}:`, error.message);
      throw error;
    }
  }

  /**
   * Send resend verification email
   */
  async sendResendVerificationEmail(email, token, serverIP = 'localhost:7070', lang = 'tr') {
    return this.sendVerificationEmail(email, token, serverIP, lang);
  }

  /**
   * Send welcome email (optional, after verification)
   */
  async sendWelcomeEmail(email, name, lang = 'tr') {
    if (!this.isInitialized) {
      throw new Error('Email service not initialized');
    }

    const templates = {
      tr: {
        subject: 'ESC Yapılandırıcı\'ya Hoş Geldiniz',
        html: `
<h2>Hoş Geldiniz, ${name}!</h2>
<p>Hesabınız başarıyla doğrulanmıştır.</p>
<p>ESC Yapılandırıcı uygulamasını kullanmaya başlayabilirsiniz.</p>
<p>Sorularınız varsa, lütfen bizimle iletişime geçin.</p>
<p>Saygılarımızla,<br>ESC Yapılandırıcı Takımı</p>
        `,
      },
      en: {
        subject: 'Welcome to ESC Configurator',
        html: `
<h2>Welcome, ${name}!</h2>
<p>Your account has been successfully verified.</p>
<p>You can now start using the ESC Configurator app.</p>
<p>If you have any questions, please contact us.</p>
<p>Best regards,<br>ESC Configurator Team</p>
        `,
      },
    };

    const template = templates[lang] || templates.en;

    try {
      await this.transporter.sendMail({
        from: process.env.EMAIL_FROM || 'noreply@escconfigrator.app',
        to: email,
        subject: template.subject,
        html: template.html,
      });

      console.log(`✓ Welcome email sent to ${email}`);
      return true;
    } catch (error) {
      console.error(`✗ Failed to send welcome email to ${email}:`, error.message);
      // Don't throw - welcome email is optional
      return false;
    }
  }

  /**
   * Send password reset email
   */
  async sendPasswordResetEmail(email, resetToken, serverIP, lang = 'en') {
    const protocol = process.env.NODE_ENV === 'production' ? 'https' : 'http';
    const resetLink = `${protocol}://${serverIP}/reset-password?token=${resetToken}`;

    const templates = {
      tr: {
        subject: 'ESC Yapılandırıcı - Şifre Sıfırlama',
        html: `
<h2>Şifre Sıfırlama İsteği</h2>
<p>Merhaba,</p>
<p>Hesabınızın şifresini sıfırlamak için bir istek aldık.</p>
<p>Aşağıdaki düğmeye tıklayarak şifrenizi sıfırlayabilirsiniz:</p>
<p>
  <a href="${resetLink}" style="display: inline-block; padding: 10px 20px; background-color: #007AFF; color: white; text-decoration: none; border-radius: 5px; font-weight: bold;">
    Şifremi Sıfırla
  </a>
</p>
<p>Ya da bu bağlantıyı tarayıcınıza yapıştırın:</p>
<p><code>${resetLink}</code></p>
<p style="color: #666; font-size: 12px;">Bu bağlantı 1 saat içinde geçerlidir.</p>
<p style="color: #999; font-size: 12px;">Eğer bu isteği yapmadıysanız, lütfen bu e-postayı görmezden gelin.</p>
        `,
      },
      en: {
        subject: 'ESC Configurator - Password Reset',
        html: `
<h2>Password Reset Request</h2>
<p>Hello,</p>
<p>We received a request to reset your password.</p>
<p>Click the button below to reset your password:</p>
<p>
  <a href="${resetLink}" style="display: inline-block; padding: 10px 20px; background-color: #007AFF; color: white; text-decoration: none; border-radius: 5px; font-weight: bold;">
    Reset Password
  </a>
</p>
<p>Or paste this link in your browser:</p>
<p><code>${resetLink}</code></p>
<p style="color: #666; font-size: 12px;">This link will expire in 1 hour.</p>
<p style="color: #999; font-size: 12px;">If you did not request this reset, please ignore this email.</p>
        `,
      },
    };

    const template = templates[lang] || templates.en;

    try {
      await this.transporter.sendMail({
        from: process.env.EMAIL_FROM || 'noreply@escconfigrator.app',
        to: email,
        subject: template.subject,
        html: template.html,
      });

      console.log(`✓ Password reset email sent to ${email}`);
      return true;
    } catch (error) {
      console.error(`✗ Failed to send password reset email to ${email}:`, error.message);
      throw error;
    }
  }
}

// Create singleton instance
let emailServiceInstance = null;

function getEmailService() {
  if (!emailServiceInstance) {
    emailServiceInstance = new EmailService();
  }
  return emailServiceInstance;
}

module.exports = getEmailService;
