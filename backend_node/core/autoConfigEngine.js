/**
 * Auto Configuration Engine
 * Generates recommended ESC settings based on battery cells and flying mode
 */

class AutoConfigEngine {
  /**
   * Configuration presets for different modes
   */
  static PRESETS = {
    light: {
      // Racing/Acro: Max performance, lower current limit
      maxRPMMultiplier: 1.0,
      currentLimitPerCell: 40, // Amps
      pwmFreq: 24000, // Hz
      tempLimit: 100, // °C
      voltageCutoffPerCell: 2.8, // V
    },
    middle: {
      // Balanced mode
      maxRPMMultiplier: 0.9,
      currentLimitPerCell: 50, // Amps
      pwmFreq: 16000, // Hz
      tempLimit: 95, // °C
      voltageCutoffPerCell: 3.0, // V
    },
    high: {
      // Heavy lift/Freestyle: High torque, high current
      maxRPMMultiplier: 0.8,
      currentLimitPerCell: 70, // Amps
      pwmFreq: 8000, // Hz
      tempLimit: 85, // °C
      voltageCutoffPerCell: 3.2, // V
    },
  };

  /**
   * Generate auto config based on battery cells and mode
   * @param {number} cells - Battery S count (e.g., 3, 4, 6)
   * @param {string} mode - 'light', 'middle', or 'high'
   * @returns {Object} Configuration object
   */
  static generateAutoConfig(cells, mode = 'middle') {
    if (!cells || cells < 1 || cells > 12) {
      throw new Error('Invalid cell count. Must be between 1-12S');
    }

    const validModes = Object.keys(this.PRESETS);
    if (!validModes.includes(mode)) {
      throw new Error(
        `Invalid mode. Must be one of: ${validModes.join(', ')}`
      );
    }

    const preset = this.PRESETS[mode];

    // Calculate motor KV based on cells (typical 1200KV for 4S)
    const baseKV = 1200;
    const maxRPM = Math.round((baseKV * cells * 10) * preset.maxRPMMultiplier);

    // Current limit: safer lower limit for racing, higher for heavy lift
    const currentLimit = preset.currentLimitPerCell * cells;

    // PWM frequency: higher for racing (cooler response), lower for efficiency
    const pwmFreq = preset.pwmFreq;

    // Temperature limit
    const tempLimit = preset.tempLimit;

    // Voltage cutoff per cell (prevent over-discharge)
    const voltageCutoff = preset.voltageCutoffPerCell * cells * 100; // in centivolts

    return {
      maxRPM,
      currentLimit,
      pwmFreq,
      tempLimit,
      voltageCutoff: Math.round(voltageCutoff),
      cells,
      mode,
      timestamp: new Date().toISOString(),
      description: `Auto-configured for ${cells}S ${mode} mode`,
    };
  }

  /**
   * Validate and adjust config values
   */
  static validateConfig(config) {
    const validated = { ...config };

    // Validate maxRPM
    if (validated.maxRPM < 1000) validated.maxRPM = 1000;
    if (validated.maxRPM > 300000) validated.maxRPM = 300000;

    // Validate current limit
    if (validated.currentLimit < 5) validated.currentLimit = 5;
    if (validated.currentLimit > 500) validated.currentLimit = 500;

    // Validate PWM frequency
    const validFreqs = [8000, 12000, 16000, 24000, 32000];
    if (!validFreqs.includes(validated.pwmFreq)) {
      validated.pwmFreq = validFreqs.reduce((prev, curr) =>
        Math.abs(curr - validated.pwmFreq) < Math.abs(prev - validated.pwmFreq)
          ? curr
          : prev
      );
    }

    // Validate temp limit
    if (validated.tempLimit < 50) validated.tempLimit = 50;
    if (validated.tempLimit > 120) validated.tempLimit = 120;

    // Validate voltage cutoff (in centivolts)
    if (validated.voltageCutoff < 0) validated.voltageCutoff = 0;
    if (validated.voltageCutoff > 5000) validated.voltageCutoff = 5000;

    return validated;
  }

  /**
   * Get configuration presets info
   */
  static getPresetsInfo() {
    return Object.keys(this.PRESETS).map((mode) => ({
      mode,
      preset: this.PRESETS[mode],
    }));
  }
}

module.exports = AutoConfigEngine;
