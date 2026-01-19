const http = require('http');
const mysql = require('./db/mysql');
const profileManager = require('./core/profileManager');
const router = require('./routes/router');
const middleware = require('./middleware');

const PORT = process.env.PORT || 7070;

/**
 * Main server request handler
 * يتعامل مع جميع الطلبات الواردة
 */
function requestHandler(req, res) {
  try {
    middleware.enableCORS(res);
    
    if (req.method === 'OPTIONS') {
      res.writeHead(200);
      res.end();
      return;
    }

    router(req, res);
  } catch (error) {
    middleware.handleError(res, error);
  }
}

// Create HTTP server
const server = http.createServer(requestHandler);

/**
 * Initialize and start the server
 */
async function startServer() {
  try {
    console.log(' Initializing ESC Configuration System v2.0');
    console.log('═'.repeat(50));
    
    // Initialize database
    await mysql.initialize();
    console.log(' Database connection pool initialized');
    
    // Initialize profile manager
    await profileManager.initialize();
    console.log(' Profile manager ready');
    
    // Start HTTP server
    server.listen(PORT, () => {
      console.log(` Server running on http://localhost:${PORT}`);
      console.log('📡 Ready for ESC connections');
      console.log('═'.repeat(50));
    });

  } catch (error) {
    console.error('❌ Server startup error:', error.message);
    process.exit(1);
  }
}

// Handle server errors
server.on('error', (error) => {
  console.error('❌ Server error:', error.message);
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\n📴 Shutting down server gracefully...');
  server.close(() => {
    console.log(' Server stopped');
    process.exit(0);
  });
});

// Start the server
startServer();
