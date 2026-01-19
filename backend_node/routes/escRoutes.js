/**
 * ESC Configuration Routes
 * مسارات التكوين الأساسية للـ ESC
 */

const escConnection = require('../core/escConnection');
const escProtocol = require('../core/escProtocol');
const autoConfigEngine = require('../core/autoConfigEngine');

/**
 * GET /ports - قائمة المنافذ المتاحة
 */
function handleGetPorts(req, res) {
  try {
    const ports = escConnection.listAvailablePorts();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: true, data: ports }));
  } catch (error) {
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: false, error: error.message }));
  }
}

/**
 * POST /connect - الاتصال بـ ESC
 */
function handleConnect(req, res) {
  let body = '';
  
  req.on('data', chunk => {
    body += chunk;
  });
  
  req.on('end', async () => {
    try {
      const data = JSON.parse(body);
      const { portPath } = data;
      
      if (!portPath) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: false, error: 'مسار المنفذ مطلوب' }));
        return;
      }
      
      await escConnection.connect(portPath);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: true, message: 'تم الاتصال بنجاح' }));
    } catch (error) {
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: false, error: error.message }));
    }
  });
}

/**
 * POST /disconnect - قطع الاتصال
 */
function handleDisconnect(req, res) {
  try {
    escConnection.disconnect();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: true, message: 'تم قطع الاتصال' }));
  } catch (error) {
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: false, error: error.message }));
  }
}

/**
 * GET /config - الحصول على الإعدادات الحالية
 */
function handleGetConfig(req, res) {
  let body = '';
  
  req.on('data', chunk => {
    body += chunk;
  });
  
  req.on('end', async () => {
    try {
      const config = await escConnection.sendCommand('GET_CONFIG');
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: true, data: config }));
    } catch (error) {
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: false, error: error.message }));
    }
  });
}

/**
 * POST /apply - تطبيق الإعدادات
 */
function handleApplyConfig(req, res) {
  let body = '';
  
  req.on('data', chunk => {
    body += chunk;
  });
  
  req.on('end', async () => {
    try {
      const data = JSON.parse(body);
      await escConnection.sendCommand('SET_CONFIG', data);
      await escConnection.sendCommand('SAVE_FLASH');
      
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: true, message: 'تم تطبيق الإعدادات' }));
    } catch (error) {
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: false, error: error.message }));
    }
  });
}

/**
 * GET /status - الحصول على حالة الاتصال
 */
function handleGetStatus(req, res) {
  try {
    const isConnected = escConnection.isConnected();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ 
      success: true, 
      data: { 
        isConnected,
        portPath: escConnection.getPortPath()
      } 
    }));
  } catch (error) {
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: false, error: error.message }));
  }
}

/**
 * POST /autoConfig - توليد إعدادات تلقائية
 */
function handleAutoConfig(req, res) {
  let body = '';
  
  req.on('data', chunk => {
    body += chunk;
  });
  
  req.on('end', async () => {
    try {
      const data = JSON.parse(body);
      const { cells, mode } = data;
      
      if (!cells || !mode) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: false, error: 'خلايا البطارية والوضع مطلوبان' }));
        return;
      }
      
      const config = autoConfigEngine.generateAutoConfig(cells, mode);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: true, data: config }));
    } catch (error) {
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: false, error: error.message }));
    }
  });
}

module.exports = {
  handleGetPorts,
  handleConnect,
  handleDisconnect,
  handleGetConfig,
  handleApplyConfig,
  handleGetStatus,
  handleAutoConfig
};
