/**
 * ESC Serial Connection Manager
 * Handles serial port detection, connection, and communication
 */

const { SerialPort } = require('serialport');
const { ReadlineParser } = require('@serialport/parser-readline');

class ESCConnection {
  constructor() {
    this.port = null;
    this.isConnected = false;
    this.baudRate = 115200;
    this.responseTimeout = 2000;
    this.pendingResponse = null;
    this.responseResolve = null;
    this.responseReject = null;
  }

  /**
   * List available serial ports
   */
  static async listAvailablePorts() {
    try {
      const ports = await SerialPort.list();
      return ports.map((p) => ({
        path: p.path,
        manufacturer: p.manufacturer || 'Unknown',
        serialNumber: p.serialNumber || 'N/A',
        description: p.description || 'Serial Device',
      }));
    } catch (error) {
      console.error('Error listing ports:', error.message);
      return [];
    }
  }

  /**
   * Connect to ESC device
   */
  async connect(portPath) {
    return new Promise((resolve, reject) => {
      try {
        const fs = require('fs');
        // On macOS the usable device node is usually /dev/cu.* rather than /dev/tty.*
        // If the provided portPath doesn't exist, try swapping /dev/tty. -> /dev/cu.
        if (!fs.existsSync(portPath) && process.platform === 'darwin') {
          const alt = portPath.replace('/dev/tty.', '/dev/cu.');
          if (alt !== portPath && fs.existsSync(alt)) {
            console.log(`Port ${portPath} not found; using ${alt} instead`);
            portPath = alt;
          }
        }

        this.port = new SerialPort({
          path: portPath,
          baudRate: this.baudRate,
          autoOpen: false,
        });

        this.port.on('open', () => {
          console.log(`Connected to ${portPath}`);
          this.isConnected = true;
          resolve(true);
        });

        this.port.on('error', (error) => {
          console.error('Serial port error:', error.message);
          this.isConnected = false;
          reject(error);
        });

        this.port.on('close', () => {
          console.log('Port closed');
          this.isConnected = false;
        });

        this.port.on('data', (data) => {
          this.handleData(data);
        });

        this.port.open();
      } catch (error) {
        reject(error);
      }
    });
  }

  /**
   * Handle incoming data
   */
  handleData(data) {
    this.pendingResponse = data;
    if (this.responseResolve) {
      this.responseResolve(data);
      this.responseResolve = null;
      this.responseReject = null;
    }
  }

  /**
   * Send command and wait for response
   */
  async sendCommand(commandBuffer, timeout = this.responseTimeout) {
    if (!this.isConnected || !this.port) {
      throw new Error('Not connected to ESC');
    }

    return new Promise((resolve, reject) => {
      this.responseResolve = resolve;
      this.responseReject = reject;

      const timeoutId = setTimeout(() => {
        this.responseResolve = null;
        this.responseReject = null;
        reject(new Error('Response timeout'));
      }, timeout);

      this.port.write(commandBuffer, (error) => {
        if (error) {
          clearTimeout(timeoutId);
          this.responseResolve = null;
          this.responseReject = null;
          reject(error);
        }
      });
    });
  }

  /**
   * Send configuration JSON to ESC device
   * Format: [HEADER(2)] [LENGTH(2)] [CHECKSUM(1)] [JSON_DATA(n)] [TERMINATOR(1)]
   */
  async sendConfiguration(configJson) {
    if (!this.isConnected || !this.port) {
      throw new Error('Not connected to ESC');
    }

    try {
      // Convert config to JSON string
      const jsonString = JSON.stringify(configJson);
      console.log(`\nhttp://localhost:7070 [Serial TX] Sending configuration (${jsonString.length} bytes)`);
      console.log(`   Config: ${jsonString}`);

      // Create binary packet with protocol format
      const HEADER = Buffer.from([0xAE, 0x53]); // "AESC" header in hex (0xAE=A, 0x53=E, 0x53=S, 0x43=C)
      const jsonBuffer = Buffer.from(jsonString, 'utf8');
      const length = Buffer.alloc(2);
      length.writeUInt16BE(jsonBuffer.length, 0); // Big-endian length
      
      // Calculate simple checksum
      let checksum = 0;
      for (let i = 0; i < jsonBuffer.length; i++) {
        checksum ^= jsonBuffer[i]; // XOR checksum
      }
      const checksumBuffer = Buffer.from([checksum]);
      
      // Assemble complete packet
      const packet = Buffer.concat([HEADER, length, checksumBuffer, jsonBuffer, Buffer.from([0x0A])]);

      return new Promise((resolve, reject) => {
        this.port.write(packet, (error) => {
          if (error) {
            console.error('❌ Serial write error:', error.message);
            reject(error);
          } else {
            console.log(`✓ Configuration packet sent successfully (${packet.length} bytes total)\n`);
            resolve({
              success: true,
              bytesSent: packet.length,
              packetStructure: {
                header: HEADER.toString('hex'),
                length: length.toString('hex'),
                checksum: checksumBuffer.toString('hex'),
                dataLength: jsonBuffer.length,
                terminator: '0A',
              },
            });
          }
        });
      });
    } catch (error) {
      console.error('❌ Error sending configuration:', error.message);
      throw error;
    }
  }

  /**
   * Disconnect from ESC
   */
  async disconnect() {
    return new Promise((resolve, reject) => {
      if (!this.port || !this.isConnected) {
        resolve(true);
        return;
      }

      this.port.close((error) => {
        if (error) {
          console.error('Error closing port:', error.message);
          reject(error);
        } else {
          this.isConnected = false;
          resolve(true);
        }
      });
    });
  }

  /**
   * Check if connected
   */
  getStatus() {
    return {
      isConnected: this.isConnected,
      portPath: this.port?.path || null,
    };
  }
}

module.exports = ESCConnection;
