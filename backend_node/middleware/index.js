/**
 * Middleware Functions
 * دوال البرمجيات الوسيطة
 */

/**
 * Enable CORS - السماح بطلبات من جميع الأصول
 */
function enableCORS(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
}

/**
 * Parse JSON request body
 */
function parseJSON(body) {
  try {
    return JSON.parse(body);
  } catch (error) {
    throw new Error('Invalid JSON in request body');
  }
}

/**
 * Validate request method
 */
function validateMethod(method, allowed) {
  return allowed.includes(method);
}

/**
 * Handle errors gracefully
 */
function handleError(res, error, statusCode = 500) {
  res.writeHead(statusCode, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    success: false,
    error: error.message || 'An error occurred'
  }));
}

module.exports = {
  enableCORS,
  parseJSON,
  validateMethod,
  handleError
};
