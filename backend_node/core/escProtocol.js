/**
 * ESC Protocol Handler
 * Defines packet structure, CRC checks, and command handling
 */

const CRC16_TABLE = Array.from({ length: 256 }, (_, i) => {
  let crc = i << 8;
  for (let j = 0; j < 8; j++) {
    crc = (crc << 1) ^ (crc & 0x8000 ? 0x1021 : 0);
  }
  return crc & 0xffff;
});

class ESCProtocol {
  static COMMANDS = {
    GET_CONFIG: 0x01,
    SET_CONFIG: 0x02,
    SAVE_FLASH: 0x03,
    GET_STATUS: 0x04,
  };

  static PACKET_FRAME = {
    START: 0xAA,
    END: 0x55,
  };

  /**
   * Calculate CRC16 checksum
   */
  static calculateCRC(data) {
    let crc = 0xffff;
    for (let byte of data) {
      crc = ((crc << 8) ^ CRC16_TABLE[(crc >> 8) ^ byte]) & 0xffff;
    }
    return crc;
  }

  /**
   * Build command packet
   * Format: [START] [LEN_H] [LEN_L] [CMD] [DATA...] [CRC_H] [CRC_L] [END]
   */
  static buildPacket(command, data = []) {
    const packet = [command, ...data];
    const crc = this.calculateCRC(packet);
    const length = packet.length + 2; // +2 for CRC

    const frame = [
      this.PACKET_FRAME.START,
      (length >> 8) & 0xff,
      length & 0xff,
      ...packet,
      (crc >> 8) & 0xff,
      crc & 0xff,
      this.PACKET_FRAME.END,
    ];

    return Buffer.from(frame);
  }

  /**
   * Parse response packet
   * Returns {valid: boolean, command: number, data: Buffer}
   */
  static parsePacket(buffer) {
    if (buffer.length < 7) {
      return { valid: false, error: 'Packet too short' };
    }

    if (buffer[0] !== this.PACKET_FRAME.START) {
      return { valid: false, error: 'Invalid start frame' };
    }

    if (buffer[buffer.length - 1] !== this.PACKET_FRAME.END) {
      return { valid: false, error: 'Invalid end frame' };
    }

    const length = (buffer[1] << 8) | buffer[2];
    const payloadEnd = 3 + length;

    if (buffer.length < payloadEnd + 1) {
      return { valid: false, error: 'Incomplete packet' };
    }

    const payload = buffer.slice(3, 3 + length - 2);
    const crcReceived = (buffer[3 + length - 2] << 8) | buffer[3 + length - 1];
    const crcCalculated = this.calculateCRC(payload);

    if (crcReceived !== crcCalculated) {
      return { valid: false, error: 'CRC mismatch' };
    }

    return {
      valid: true,
      command: payload[0],
      data: payload.slice(1),
    };
  }

  /**
   * Build GET_CONFIG command
   */
  static buildGetConfig() {
    return this.buildPacket(this.COMMANDS.GET_CONFIG);
  }

  /**
   * Build SET_CONFIG command
   * params: {maxRPM, currentLimit, pwmFreq, tempLimit, voltageCutoff}
   */
  static buildSetConfig(params) {
    const data = [];
    // Pack as little-endian 16-bit values
    data.push((params.maxRPM >> 8) & 0xff, params.maxRPM & 0xff);
    data.push((params.currentLimit >> 8) & 0xff, params.currentLimit & 0xff);
    data.push((params.pwmFreq >> 8) & 0xff, params.pwmFreq & 0xff);
    data.push((params.tempLimit >> 8) & 0xff, params.tempLimit & 0xff);
    data.push(
      (params.voltageCutoff >> 8) & 0xff,
      params.voltageCutoff & 0xff
    );

    return this.buildPacket(this.COMMANDS.SET_CONFIG, data);
  }

  /**
   * Build SAVE_FLASH command
   */
  static buildSaveFlash() {
    return this.buildPacket(this.COMMANDS.SAVE_FLASH);
  }

  /**
   * Build GET_STATUS command
   */
  static buildGetStatus() {
    return this.buildPacket(this.COMMANDS.GET_STATUS);
  }

  /**
   * Parse config response
   * Returns {maxRPM, currentLimit, pwmFreq, tempLimit, voltageCutoff}
   */
  static parseConfigResponse(data) {
    if (data.length < 10) {
      return null;
    }

    return {
      maxRPM: (data[0] << 8) | data[1],
      currentLimit: (data[2] << 8) | data[3],
      pwmFreq: (data[4] << 8) | data[5],
      tempLimit: (data[6] << 8) | data[7],
      voltageCutoff: (data[8] << 8) | data[9],
    };
  }

  /**
   * Parse status response
   * Returns {voltage, current, rpm, temperature}
   */
  static parseStatusResponse(data) {
    if (data.length < 8) {
      return null;
    }

    return {
      voltage: ((data[0] << 8) | data[1]) / 100, // mV to V
      current: ((data[2] << 8) | data[3]) / 10, // mA to A
      rpm: (data[4] << 8) | data[5],
      temperature: data[6],
    };
  }
}

module.exports = ESCProtocol;
