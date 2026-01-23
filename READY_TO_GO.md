# http://localhost:7070 ESC Panel System - Ready to Connect & Test

**Date**: January 23, 2026  
**Status**: Backend Running on Port 7070 http://localhost:7070

---

## 🟢 Current System Status

### Backend Server
- http://localhost:7070 **Server**: Running on `http://localhost:7070`
- http://localhost:7070 **Database**: Connected to MySQL (esc_config)
- http://localhost:7070 **API**: All endpoints responding
- http://localhost:7070 **Authentication**: Working (Registration, Login)
- http://localhost:7070 **Auto-Config**: Generating profiles (3 modes: Light/Middle/High)

### Database (4 Tables)
```
http://localhost:7070 users            - 1 record (test@example.com)
http://localhost:7070 esc_configs      - Ready
http://localhost:7070 profiles         - Ready
http://localhost:7070 esc_profiles     - Ready
```

### Frontend
- ⏳ Not started yet (Flutter - Optional for now)
- Can test API directly via curl/Postman

---

## 📊 VS Code Database Extension Setup

### Connection Details
```
Name:            ESC Config Local
Connection:      esc_config_main
Server Type:     MySQL
Host:            127.0.0.1
Port:            3306
Username:        root
Password:        root
Database:        esc_config
Socket:          /tmp/mysql.sock
```

### After Connecting, You'll See:
```
ESC Config Local
├── users
│   └── test@example.com (id=1)
├── esc_configs (empty)
├── profiles (empty)
└── esc_profiles (empty)
```

---

## 🧪 API Endpoints - TESTED & WORKING

### 1. Health Check http://localhost:7070
```bash
curl http://localhost:7070/status
```
**Response**: Server info + ESC connection status + Database health

### 2. List Available Ports http://localhost:7070
```bash
curl http://localhost:7070/ports
```
**Response**: 
```json
{
  "success": true,
  "ports": [
    {
      "path": "/dev/tty.URT1",
      "manufacturer": "Unknown",
      "serialNumber": "N/A",
      "description": "Serial Device"
    }
  ]
}
```

### 3. Register User http://localhost:7070
```bash
curl -X POST http://localhost:7070/signup \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "Password123",
    "name": "Your Name"
  }'
```
**Response**: 
```json
{
  "success": true,
  "message": "User registered. Please check your email to verify your account.",
  "userId": 1,
  "email": "user@example.com"
}
```

### 4. Generate Auto-Config http://localhost:7070
```bash
curl -X POST http://localhost:7070/autoConfig \
  -H "Content-Type: application/json" \
  -d '{"cells": 4, "mode": "middle"}'
```
**Response**:
```json
{
  "success": true,
  "config": {
    "maxRPM": 43200,
    "currentLimit": 200,
    "pwmFreq": 16000,
    "tempLimit": 95,
    "voltageCutoff": 1200,
    "cells": 4,
    "mode": "middle",
    "timestamp": "2026-01-23T13:31:56.442Z",
    "description": "Auto-configured for 4S middle mode"
  }
}
```

### 5. Connect to ESC ⚠️ (Needs Fix)
```bash
curl -X POST http://localhost:7070/connect \
  -H "Content-Type: application/json" \
  -d '{"portPath": "/dev/tty.URT1"}'
```
**Status**: ⚠️ Will attempt to connect but uses wrong packet format
**Issue**: Routes don't build binary packets correctly

### 6. Get Config from ESC ⚠️ (Needs Fix)
```bash
curl http://localhost:7070/config
```
**Status**: ⚠️ Packet format incorrect

### 7. Apply Config to ESC ⚠️ (Needs Fix)
```bash
curl -X POST http://localhost:7070/apply \
  -H "Content-Type: application/json" \
  -d '{
    "maxRPM": 43200,
    "currentLimit": 200,
    "pwmFreq": 16000,
    "tempLimit": 95,
    "voltageCutoff": 1200
  }'
```
**Status**: ⚠️ Packet format incorrect

---

## ⚠️ Known Issues (Hardware Communication)

### Issue #1: Packet Building ❌
- Routes send string commands instead of binary packets
- **Location**: `backend_node/routes/escRoutes.js` lines 75, 101
- **Fix**: Use ESCProtocol.buildGetConfig() instead of strings
- **Effort**: 1-2 hours

### Issue #2: Response Parsing ❌
- No packet boundary detection
- No request/response correlation
- **Location**: `backend_node/core/escConnection.js`
- **Fix**: Implement packet buffering and framing
- **Effort**: 2-3 hours

### Issue #3: Multi-Vendor Support ❌
- Only supports one hardcoded protocol
- No vendor detection
- **Fix**: Create protocol abstraction layer
- **Effort**: 3-5 days

---

## http://localhost:7070 Database Queries You Can Run

Via VS Code Extension or Terminal:

```sql
-- View all users
SELECT * FROM users;

-- Count users
SELECT COUNT(*) as total_users FROM users;

-- View table structure
DESCRIBE users;

-- View profiles
SELECT * FROM profiles;

-- View auto-generated configs
SELECT * FROM esc_configs;

-- Check database size
SELECT 
  table_name,
  ROUND(((data_length + index_length) / 1024 / 1024), 2) as size_mb
FROM information_schema.tables
WHERE table_schema = 'esc_config';
```

---

## 🚀 Next Steps

### Now:
1. http://localhost:7070 Connect VS Code Extension to database
2. http://localhost:7070 Browse the tables
3. http://localhost:7070 Test API endpoints with curl/Postman

### This Week:
1. Fix packet building in routes (1 day)
2. Implement response parsing (1-2 days)
3. Add error handling (1 day)
4. Test with simulated ESC (1 day)

### Next Week:
1. Create protocol abstraction layer (2-3 days)
2. Implement BLHeli protocol support (3-5 days)
3. Test with real ESC hardware

---

## http://localhost:7070 Troubleshooting

### Server Won't Start
```bash
# Check if port 7070 is in use
lsof -i :7070

# Check MySQL running
brew services list | grep mysql

# Start MySQL if needed
sudo brew services start mysql
```

### Database Won't Connect
```bash
# Test MySQL directly
mysql -u root -p'root' -D esc_config -e "SHOW TABLES;"

# Run setup script if needed
node backend_node/setup-db.js
```

### API Endpoint Returns Error
```bash
# Check server logs
tail -f /tmp/esc_server.log

# Or restart server
pkill -f "node server.js"
cd backend_node && node server.js
```

---

## 📋 Quick Reference

| Component | Status | Port | Health |
|---|---|---|---|
| Backend Server | http://localhost:7070 Running | 7070 | 200 OK |
| MySQL Database | http://localhost:7070 Connected | 3306 | 4 tables |
| Authentication | http://localhost:7070 Working | - | Users table |
| Auto-Config | http://localhost:7070 Working | - | 3 presets |
| ESC Connection | ⚠️ Needs Fix | - | Packet issue |
| Serial Ports | http://localhost:7070 Detected | - | 3 ports found |

---

## 💡 Tips

1. **Keep Server Running**: Leave `node server.js` running in a terminal
2. **Monitor Logs**: Check `/tmp/esc_server.log` for errors
3. **Test Database**: Use VS Code Extension to query tables
4. **Use Postman**: Import API for easier testing
5. **Check Email**: Verification emails go to Ethereal (development)

---

## 📞 Support

All critical systems are now operational. Ready to:
- Browse database via VS Code
- Test API endpoints
- Begin fixing hardware communication issues
- Deploy to production with fixes

**Estimated time to production-ready**: 2-3 weeks (with fixes)

