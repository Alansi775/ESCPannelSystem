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
