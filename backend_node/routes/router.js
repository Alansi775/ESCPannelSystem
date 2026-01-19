/**
 * Request Router
 * موجه الطلبات الرئيسي
 */

const escRoutes = require('./routes/escRoutes');
const profileRoutes = require('./routes/profileRoutes');
const middleware = require('./middleware');

/**
 * Route handler function
 * يوجه الطلبات إلى المعالجات المناسبة
 */
async function router(req, res) {
  const { method, url } = req;
  
  // Enable CORS
  middleware.enableCORS(res);
  
  // Handle OPTIONS requests
  if (method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }
  
  // Parse URL
  const urlParts = url.split('?')[0].split('/').filter(Boolean);
  const query = new URLSearchParams(url.split('?')[1] || '');
  
  try {
    // ESC Routes
    if (urlParts[0] === 'ports' && method === 'GET') {
      return escRoutes.handleGetPorts(req, res);
    }
    
    if (urlParts[0] === 'connect' && method === 'POST') {
      return escRoutes.handleConnect(req, res);
    }
    
    if (urlParts[0] === 'disconnect' && method === 'POST') {
      return escRoutes.handleDisconnect(req, res);
    }
    
    if (urlParts[0] === 'config' && method === 'GET') {
      return escRoutes.handleGetConfig(req, res);
    }
    
    if (urlParts[0] === 'apply' && method === 'POST') {
      return escRoutes.handleApplyConfig(req, res);
    }
    
    if (urlParts[0] === 'status' && method === 'GET') {
      return escRoutes.handleGetStatus(req, res);
    }
    
    if (urlParts[0] === 'autoConfig' && method === 'POST') {
      return escRoutes.handleAutoConfig(req, res);
    }
    
    // Profile Routes
    if (urlParts[0] === 'saveProfile' && method === 'POST') {
      return profileRoutes.handleSaveProfile(req, res);
    }
    
    if (urlParts[0] === 'profiles' && method === 'GET') {
      if (urlParts[1]) {
        return profileRoutes.handleGetProfile(req, res, urlParts[1]);
      }
      return profileRoutes.handleGetProfiles(req, res);
    }
    
    if (urlParts[0] === 'profiles' && urlParts[1] && method === 'DELETE') {
      return profileRoutes.handleDeleteProfile(req, res, urlParts[1]);
    }
    
    // 404 Not Found
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: false, error: 'Route not found' }));
    
  } catch (error) {
    middleware.handleError(res, error);
  }
}

module.exports = router;
