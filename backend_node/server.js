/**
 * ESC Configuration Server
 * Pure Node.js HTTP server (no Express)
 * Endpoints: /status, /connect, /config, /apply, /saveProfile, /profiles, /signup, /login, /verify
 */

// Load environment variables
require('dotenv').config();

const http = require('http');
const url = require('url');
const ESCConnection = require('./core/escConnection');
const ESCProtocol = require('./core/escProtocol');
const AutoConfigEngine = require('./core/autoConfigEngine');
const ProfileManager = require('./core/profileManager');
const PaymentStub = require('./core/paymentStub');
const MySQLConnection = require('./db/mysql');
const DatabaseSchema = require('./db/schema');
const AuthRoutes = require('./routes/authRoutes');
const getEmailService = require('./services/emailService');

const PORT = process.env.PORT || 7070;
const SERVER_IP = process.env.SERVER_IP || 'localhost:7070';

// Global instances
let escConnection = null;  // Will be initialized as ESCConnection instance
let profileManager = null;
let dbConnection = null;
let authRoutes = null;
let emailService = null;

/**
 * Parse JSON request body
 */
function parseRequestBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', (chunk) => {
      data += chunk;
    });
    req.on('end', () => {
      try {
        resolve(data ? JSON.parse(data) : {});
      } catch (error) {
        reject(new Error('Invalid JSON'));
      }
    });
    req.on('error', reject);
  });
}

/**
 * Send JSON response
 */
function sendResponse(res, statusCode, data) {
  res.writeHead(statusCode, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
  });
  res.end(JSON.stringify(data, null, 2));
}

/**
 * Handle CORS preflight
 */
function handleCORS(req, res) {
  if (req.method === 'OPTIONS') {
    res.writeHead(200, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    });
    res.end();
    return true;
  }
  return false;
}

/**
 * Main request handler
 */
async function requestHandler(req, res) {
  if (handleCORS(req, res)) return;

  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;
  const method = req.method;

  try {
    // GET /status - Check server and ESC connection status
    if (pathname === '/status' && method === 'GET') {
      const status = {
        server: 'running',
        timestamp: new Date().toISOString(),
        escConnection: escConnection?.getStatus() || { isConnected: false },
        database: await dbConnection.ping(),
        license: PaymentStub.getLicenseInfo(),
      };
      sendResponse(res, 200, status);
    }

    // POST /connect - Connect to ESC device
    else if (pathname === '/connect' && method === 'POST') {
      const body = await parseRequestBody(req);
      const { portPath } = body;

      if (!portPath) {
        sendResponse(res, 400, {
          error: 'portPath is required',
          availablePorts: await ESCConnection.listAvailablePorts(),
        });
        return;
      }

      try {
        if (escConnection?.isConnected) {
          await escConnection.disconnect();
        }

        escConnection = new ESCConnection();
        await escConnection.connect(portPath);

        sendResponse(res, 200, {
          success: true,
          message: 'Connected to ESC',
          status: escConnection.getStatus(),
        });
      } catch (error) {
        sendResponse(res, 500, {
          error: `Connection failed: ${error.message}`,
          availablePorts: await ESCConnection.listAvailablePorts(),
        });
      }
    }

    // GET /config - Get current ESC configuration
    else if (pathname === '/config' && method === 'GET') {
      if (!escConnection?.isConnected) {
        sendResponse(res, 400, { error: 'Not connected to ESC' });
        return;
      }

      try {
        const command = ESCProtocol.buildGetConfig();
        const response = await escConnection.sendCommand(command);
        const parsed = ESCProtocol.parsePacket(response);

        if (!parsed.valid) {
          sendResponse(res, 500, { error: parsed.error });
          return;
        }

        const config = ESCProtocol.parseConfigResponse(parsed.data);
        sendResponse(res, 200, {
          success: true,
          config,
        });
      } catch (error) {
        sendResponse(res, 500, { error: error.message });
      }
    }

    // POST /apply - Apply configuration to ESC
    else if (pathname === '/apply' && method === 'POST') {
      if (!escConnection?.isConnected) {
        sendResponse(res, 400, { error: 'Not connected to ESC' });
        return;
      }

      const body = await parseRequestBody(req);
      const { maxRPM, currentLimit, pwmFreq, tempLimit, voltageCutoff } = body;

      if (!maxRPM || !currentLimit || !pwmFreq || !tempLimit || voltageCutoff === undefined) {
        sendResponse(res, 400, {
          error: 'Missing required fields',
          required: [
            'maxRPM',
            'currentLimit',
            'pwmFreq',
            'tempLimit',
            'voltageCutoff',
          ],
        });
        return;
      }

      try {
        const config = {
          maxRPM,
          currentLimit,
          pwmFreq,
          tempLimit,
          voltageCutoff,
        };

        const validated = AutoConfigEngine.validateConfig(config);
        const command = ESCProtocol.buildSetConfig(validated);
        const response = await escConnection.sendCommand(command);
        const parsed = ESCProtocol.parsePacket(response);

        if (!parsed.valid) {
          sendResponse(res, 500, { error: parsed.error });
          return;
        }

        // Send save to flash
        const saveCommand = ESCProtocol.buildSaveFlash();
        await escConnection.sendCommand(saveCommand);

        sendResponse(res, 200, {
          success: true,
          message: 'Configuration applied and saved',
          config: validated,
        });
      } catch (error) {
        sendResponse(res, 500, { error: error.message });
      }
    }

    // POST /saveProfile - Save configuration profile
    else if (pathname === '/saveProfile' && method === 'POST') {
      const body = await parseRequestBody(req);
      const { profileName, config } = body;

      if (!profileName || !config) {
        sendResponse(res, 400, {
          error: 'profileName and config are required',
        });
        return;
      }

      try {
        const result = await profileManager.saveProfile(profileName, config);
        sendResponse(res, 200, {
          success: true,
          message: 'Profile saved',
          profile: result,
        });
      } catch (error) {
        sendResponse(res, 500, { error: error.message });
      }
    }

    // GET /profiles - Get all saved profiles
    else if (pathname === '/profiles' && method === 'GET') {
      try {
        const profiles = await profileManager.loadAllProfiles();
        sendResponse(res, 200, {
          success: true,
          count: profiles.length,
          profiles,
        });
      } catch (error) {
        sendResponse(res, 500, { error: error.message });
      }
    }

    // GET /profiles/:id - Get profile by ID
    else if (pathname.startsWith('/profiles/') && method === 'GET') {
      const id = parseInt(pathname.split('/')[2]);
      if (isNaN(id)) {
        sendResponse(res, 400, { error: 'Invalid profile ID' });
        return;
      }

      try {
        const profile = await profileManager.loadProfileById(id);
        if (!profile) {
          sendResponse(res, 404, { error: 'Profile not found' });
          return;
        }

        sendResponse(res, 200, {
          success: true,
          profile,
        });
      } catch (error) {
        sendResponse(res, 500, { error: error.message });
      }
    }

    // POST /autoConfig - Generate auto configuration
    else if (pathname === '/autoConfig' && method === 'POST') {
      const body = await parseRequestBody(req);
      const { cells, mode } = body;

      if (!cells) {
        sendResponse(res, 400, {
          error: 'cells parameter is required',
          presets: AutoConfigEngine.getPresetsInfo(),
        });
        return;
      }

      try {
        const config = AutoConfigEngine.generateAutoConfig(cells, mode || 'middle');
        sendResponse(res, 200, {
          success: true,
          config,
        });
      } catch (error) {
        sendResponse(res, 400, { error: error.message });
      }
    }

    // GET /ports - List available serial ports
    else if (pathname === '/ports' && method === 'GET') {
      try {
        const ports = await ESCConnection.listAvailablePorts();
        sendResponse(res, 200, {
          success: true,
          ports,
        });
      } catch (error) {
        sendResponse(res, 500, { error: error.message });
      }
    }

    // GET /disconnect - Disconnect from ESC
    else if (pathname === '/disconnect' && method === 'GET') {
      try {
        if (escConnection?.isConnected) {
          await escConnection.disconnect();
        }
        sendResponse(res, 200, {
          success: true,
          message: 'Disconnected from ESC',
        });
      } catch (error) {
        sendResponse(res, 500, { error: error.message });
      }
    }

    // POST /signup - Create new user account
    else if (pathname === '/signup' && method === 'POST') {
      const body = await parseRequestBody(req);
      const response = await authRoutes.handleSignup(req, res, body);
      sendResponse(res, response.statusCode, response.data);
    }

    // POST /login - Authenticate user
    else if (pathname === '/login' && method === 'POST') {
      const body = await parseRequestBody(req);
      const response = await authRoutes.handleLogin(req, res, body);
      sendResponse(res, response.statusCode, response.data);
    }

    // GET /verify - Verify email token
    else if (pathname === '/verify' && method === 'GET') {
      const response = await authRoutes.handleVerify(req, res, parsedUrl.query);
      
      if (response.htmlResponse) {
        res.writeHead(response.statusCode, {
          'Content-Type': 'text/html; charset=utf-8',
          'Access-Control-Allow-Origin': '*',
        });
        res.end(response.htmlResponse);
      } else {
        sendResponse(res, response.statusCode, response.data);
      }
    }

    // POST /resend-verification - Resend verification email
    else if (pathname === '/resend-verification' && method === 'POST') {
      const body = await parseRequestBody(req);
      const response = await authRoutes.handleResendVerification(req, res, body);
      sendResponse(res, response.statusCode, response.data);
    }

    // POST /change-password - Change user password
    else if (pathname === '/change-password' && method === 'POST') {
      const body = await parseRequestBody(req);
      const response = await authRoutes.handleChangePassword(req, res, body);
      sendResponse(res, response.statusCode, response.data);
    }

    // POST /forgot-password - Send password reset email
    else if (pathname === '/forgot-password' && method === 'POST') {
      const body = await parseRequestBody(req);
      const response = await authRoutes.handleForgotPassword(req, res, body);
      sendResponse(res, response.statusCode, response.data);
    }

    // GET /reset-password?token=... - Reset password with token
    else if (pathname === '/reset-password' && method === 'GET') {
      const urlObj = new url.URL('http://localhost' + req.url);
      const token = urlObj.searchParams.get('token');
      const response = await authRoutes.handleResetPasswordPage(req, res, token);
      res.writeHead(response.statusCode, { 'Content-Type': response.contentType || 'application/json' });
      res.end(JSON.stringify(response.data));
      return;
    }

    // GET /getConfig/:userId - Get current configuration for a user
    else if (pathname.startsWith('/getConfig/') && method === 'GET') {
      const userId = parseInt(pathname.split('/').pop());
      
      if (!userId) {
        sendResponse(res, 400, { error: 'User ID is required' });
        return;
      }

      try {
        const query = `
          SELECT id, user_id, profile_name, esc_type, config_json, created_at, updated_at
          FROM esc_configs
          WHERE user_id = ?
          LIMIT 1
        `;

        const result = await dbConnection.execute(query, [userId]);
        const rows = result[0];

        if (rows.length === 0) {
          sendResponse(res, 404, {
            error: 'No configuration found for this user',
            userId,
          });
          return;
        }

        const config = rows[0];
        console.log(`✓ Retrieved configuration for user ${userId}:`);
        console.log(`  Config ID: ${config.id}`);
        console.log(`  Profile: ${config.profile_name || 'unnamed'}`);

        sendResponse(res, 200, {
          success: true,
          config: {
            id: config.id,
            userId: config.user_id,
            profileName: config.profile_name,
            escType: config.esc_type,
            configJson: typeof config.config_json === 'string' ? JSON.parse(config.config_json) : config.config_json,
            createdAt: config.created_at,
            updatedAt: config.updated_at,
          },
        });
      } catch (error) {
        console.error('✗ Error retrieving configuration:', error.message);
        sendResponse(res, 500, {
          error: 'Failed to retrieve configuration',
          details: error.message,
        });
      }
    }

    // POST /saveConfig - Save configuration to database
    else if (pathname === '/saveConfig' && method === 'POST') {
      const body = await parseRequestBody(req);
      const { userId, profileName, configJson, escType } = body;

      // Validate input
      if (!userId || !configJson) {
        sendResponse(res, 400, {
          error: 'userId and configJson are required',
        });
        return;
      }

      // Validate JSON size (< 2MB)
      const jsonString = JSON.stringify(configJson);
      if (jsonString.length > 2 * 1024 * 1024) {
        sendResponse(res, 413, {
          error: 'Configuration JSON too large (max 2MB)',
        });
        return;
      }

      try {
        // Log the JSON to terminal
        console.log('\nhttp://localhost:7070 [saveConfig] Received configuration:');
        console.log('  User ID:', userId);
        console.log('  Profile Name:', profileName || 'unnamed');
        console.log('  ESC Type:', escType || 'auto-detect');
        console.log('  Configuration JSON:');
        console.log(JSON.stringify(configJson, null, 2));

        // Delete any previous configs for this user (keep only latest)
        console.log('  → Checking for previous configurations...');
        const deleteQuery = `DELETE FROM esc_configs WHERE user_id = ?`;
        const deleteResult = await dbConnection.execute(deleteQuery, [userId]);
        if (deleteResult[0]?.affectedRows > 0) {
          console.log(`  ✓ Deleted ${deleteResult[0].affectedRows} previous configuration(s)`);
        }

        // Save new configuration to database
        const query = `
          INSERT INTO esc_configs (user_id, profile_name, esc_type, config_json, created_at, updated_at)
          VALUES (?, ?, ?, ?, NOW(), NOW())
        `;

        const result = await dbConnection.execute(query, [
          userId,
          profileName || null,
          escType || null,
          jsonString,
        ]);

        // mysql2 returns [rows, fields] - rows[0] contains info
        const configId = result[0]?.insertId;
        console.log('✓ New configuration saved to database (ID:', configId, ')\n');

        sendResponse(res, 201, {
          success: true,
          message: 'Configuration saved (previous configuration replaced)',
          configId,
          userId,
          profileName,
        });
      } catch (error) {
        console.error('✗ Error saving configuration:', error.message);
        sendResponse(res, 500, {
          error: 'Failed to save configuration',
          details: error.message,
        });
      }
    }

    // POST /applyConfig - Send configuration to connected ESC device via Serial
    else if (pathname === '/applyConfig' && method === 'POST') {
      const body = await parseRequestBody(req);
      const { userId, configJson, portPath } = body;

      if (!configJson) {
        sendResponse(res, 400, {
          error: 'configJson is required',
        });
        return;
      }

      if (!portPath) {
        sendResponse(res, 400, {
          error: 'portPath is required - device must be connected first',
        });
        return;
      }

      try {
        console.log('\nhttp://localhost:7070 [applyConfig] Applying configuration to ESC device');
        console.log(`   Port: ${portPath}`);
        console.log(`   User ID: ${userId}`);

        // Check if already connected to this port
        const currentStatus = escConnection.getStatus();
        let needsConnect = !currentStatus.isConnected || currentStatus.portPath !== portPath;

        // Connect if needed
        if (needsConnect) {
          console.log('   → Connecting to device...');
          try {
            await escConnection.connect(portPath);
            console.log('   ✓ Connected');
          } catch (error) {
            throw new Error(`Failed to connect to port: ${error.message}`);
          }
        }

        // Send configuration via Serial
        const txResult = await escConnection.sendConfiguration(configJson);

        sendResponse(res, 200, {
          success: true,
          message: 'Configuration applied to ESC device',
          userId,
          portPath,
          transmission: txResult,
        });
      } catch (error) {
        console.error('✗ Error applying configuration:', error.message);
        sendResponse(res, 500, {
          error: 'Failed to apply configuration to device',
          details: error.message,
        });
      }
    }

    // DELETE /deleteConfig/:userId - Delete configuration for a user
    else if (pathname.startsWith('/deleteConfig/') && method === 'DELETE') {
      const userId = parseInt(pathname.split('/').pop());
      
      if (!userId) {
        sendResponse(res, 400, { error: 'User ID is required' });
        return;
      }

      try {
        const query = `DELETE FROM esc_configs WHERE user_id = ?`;
        const result = await dbConnection.execute(query, [userId]);

        const affectedRows = result[0]?.affectedRows || 0;
        console.log(`✓ Deleted configuration(s) for user ${userId} (${affectedRows} rows)`);

        sendResponse(res, 200, {
          success: true,
          message: `Configuration deleted (${affectedRows} rows affected)`,
          userId,
        });
      } catch (error) {
        console.error('✗ Error deleting configuration:', error.message);
        sendResponse(res, 500, {
          error: 'Failed to delete configuration',
          details: error.message,
        });
      }
    }

    // 404 - Not found
    else {
      sendResponse(res, 404, {
        error: 'Endpoint not found',
        availableEndpoints: [
          'GET /status',
          'POST /connect',
          'GET /config',
          'POST /apply',
          'POST /saveProfile',
          'GET /profiles',
          'GET /profiles/:id',
          'POST /autoConfig',
          'POST /saveConfig',
          'GET /getConfig/:userId',
          'DELETE /deleteConfig/:userId',
          'GET /ports',
          'GET /disconnect',
          'POST /signup',
          'POST /login',
          'GET /verify',
          'POST /resend-verification',
        ],
      });
    }
  } catch (error) {
    console.error('Request error:', error);
    sendResponse(res, 500, { error: error.message });
  }
}

/**
 * Initialize server
 */
async function initializeServer() {
  try {
    console.log(' Initializing ESC Configuration Server...');

    // Initialize database
    dbConnection = new MySQLConnection({
      host: process.env.DB_HOST || 'localhost',
      user: process.env.DB_USER || 'root',
      password: process.env.DB_PASSWORD || 'root',
      database: process.env.DB_NAME || 'esc_config',
      socketPath: process.env.DB_SOCKET || '/tmp/mysql.sock',
    });
    await dbConnection.createDatabase();
    await dbConnection.initialize();

    // Initialize database schema
    const schema = new DatabaseSchema(dbConnection);
    await schema.initialize();

    // Initialize email service
    emailService = getEmailService();
    await emailService.initialize();

    // Initialize authentication routes
    authRoutes = new AuthRoutes(dbConnection, SERVER_IP);

    // Initialize profile manager
    profileManager = new ProfileManager(dbConnection);
    await profileManager.initializeSchema();

    //  CRITICAL FIX: Initialize ESC Connection instance
    escConnection = new ESCConnection();
    console.log(' ESC Connection instance created');

    // Create HTTP server
    const server = http.createServer(requestHandler);

    server.on('clientError', (error) => {
      console.error('Client error:', error);
    });

    server.listen(PORT, '0.0.0.0', () => {
      console.log(` Server listening on http://localhost:${PORT}`);
      console.log(` Database: ${dbConnection.config.database}`);
      console.log(` Email Service: Initialized`);
      console.log(` Authentication: Enabled`);
      console.log(` ESC Connection: Ready for connection`);
      console.log(` Available endpoints: See GET /status for info`);
    });
  } catch (error) {
    console.error(' Failed to initialize server:', error.message);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('\n Shutting down...');
  try {
    if (escConnection?.isConnected) {
      await escConnection.disconnect();
    }
    if (dbConnection) {
      await dbConnection.close();
    }
    process.exit(0);
  } catch (error) {
    console.error('Error during shutdown:', error);
    process.exit(1);
  }
});

// Start server
initializeServer();
