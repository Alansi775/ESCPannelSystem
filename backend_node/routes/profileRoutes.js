/**
 * Profile Routes
 * مسارات إدارة الملفات الشخصية
 */

const profileManager = require('../core/profileManager');

/**
 * POST /saveProfile - حفظ ملف شخصي جديد
 */
function handleSaveProfile(req, res) {
  let body = '';
  
  req.on('data', chunk => {
    body += chunk;
  });
  
  req.on('end', async () => {
    try {
      const data = JSON.parse(body);
      const { name, config } = data;
      
      if (!name || !config) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: false, error: 'الاسم والإعدادات مطلوبان' }));
        return;
      }
      
      const result = await profileManager.saveProfile(name, config);
      res.writeHead(201, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: true, data: result }));
    } catch (error) {
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: false, error: error.message }));
    }
  });
}

/**
 * GET /profiles - الحصول على جميع الملفات الشخصية
 */
function handleGetProfiles(req, res) {
  try {
    profileManager.loadAllProfiles().then(profiles => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: true, data: profiles }));
    });
  } catch (error) {
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: false, error: error.message }));
  }
}

/**
 * GET /profiles/:id - الحصول على ملف شخصي محدد
 */
function handleGetProfile(req, res, id) {
  try {
    profileManager.loadProfileById(id).then(profile => {
      if (!profile) {
        res.writeHead(404, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: false, error: 'الملف الشخصي غير موجود' }));
        return;
      }
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: true, data: profile }));
    });
  } catch (error) {
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: false, error: error.message }));
  }
}

/**
 * DELETE /profiles/:id - حذف ملف شخصي
 */
function handleDeleteProfile(req, res, id) {
  try {
    profileManager.deleteProfile(id).then(() => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: true, message: 'تم حذف الملف الشخصي' }));
    });
  } catch (error) {
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: false, error: error.message }));
  }
}

module.exports = {
  handleSaveProfile,
  handleGetProfiles,
  handleGetProfile,
  handleDeleteProfile
};
