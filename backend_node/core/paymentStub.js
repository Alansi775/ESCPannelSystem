/**
 * Payment/License Stub
 * Temporary stub for license verification
 * In production, this would integrate with Stripe, PayPal, or custom license service
 */

class PaymentStub {
  /**
   * Check if user has valid license
   * Stub: always returns true for now
   */
  static isLicenseValid(userId = null) {
    // TODO: In production, check against:
    // - Database of valid licenses
    // - Third-party payment service (Stripe, PayPal)
    // - License server
    return true;
  }

  /**
   * Get license info
   */
  static getLicenseInfo(userId = null) {
    return {
      valid: true,
      tier: 'pro', // free, basic, pro
      expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(), // 1 year from now
      features: {
        unlimited_profiles: true,
        auto_config: true,
        profile_sync: true,
        ota_updates: true,
      },
    };
  }

  /**
   * Check specific feature access
   */
  static hasFeatureAccess(feature, userId = null) {
    const license = this.getLicenseInfo(userId);
    if (!license.valid) {
      return false;
    }

    const features = license.features || {};
    return features[feature] === true;
  }

  /**
   * Verify payment token (stub)
   */
  static async verifyPaymentToken(token) {
    // TODO: Verify with payment provider
    return {
      valid: true,
      amount: 2999, // in cents
      currency: 'USD',
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * Get pricing info
   */
  static getPricingInfo() {
    return {
      tiers: [
        {
          name: 'Free',
          price: 0,
          features: {
            unlimited_profiles: false,
            max_profiles: 3,
            auto_config: true,
            profile_sync: false,
          },
        },
        {
          name: 'Basic',
          price: 999, // $9.99
          features: {
            unlimited_profiles: true,
            auto_config: true,
            profile_sync: true,
            ota_updates: false,
          },
        },
        {
          name: 'Pro',
          price: 2999, // $29.99
          features: {
            unlimited_profiles: true,
            auto_config: true,
            profile_sync: true,
            ota_updates: true,
          },
        },
      ],
    };
  }
}

module.exports = PaymentStub;
