#!/bin/bash

# 🔄 Restart ESC Server Script

echo "🛑 Stopping old server..."
pkill -f "node server.js"
sleep 1

echo "🗑️  Clearing port 7070..."
lsof -i :7070 | awk 'NR!=1 {print $2}' | xargs -r kill -9 2>/dev/null

echo "⏳ Waiting..."
sleep 2

echo "🚀 Starting new server..."
cd /Users/MohammedSaleh/Desktop/ESCPannelSystem/backend_node

# اختر واحد من الخيارات التالية:

# الخيار 1: تشغيل مباشر (يظهر جميع الرسائل)
# node server.js

# الخيار 2: تشغيل في الخلفية مع حفظ السجلات
nohup node server.js > /tmp/esc_server.log 2>&1 &

sleep 2
echo ""
echo "http://localhost:7070 Server started!"
echo ""
echo "📍 Server: http://localhost:7070"
echo "📊 Logs: tail -f /tmp/esc_server.log"
echo ""
echo "🧪 Test:"
echo "   curl http://localhost:7070/status"
