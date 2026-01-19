#!/bin/bash

# Quick Start Script for ESC Configuration System v2.0
# سكريبت البدء السريع لنظام إدارة ESC v2.0

echo " ESC Configuration System v2.0 - Quick Setup"
echo "═════════════════════════════════════════════════"
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Step 1: Backend Setup
echo -e "${BLUE} Step 1: Setting up Backend...${NC}"
cd backend_node
npm install
echo -e "${GREEN}✓ Backend dependencies installed${NC}"
echo ""

# Step 2: Frontend Setup
echo -e "${BLUE} Step 2: Setting up Frontend...${NC}"
cd ../frontend_flutter
flutter pub get
echo -e "${GREEN}✓ Frontend dependencies installed${NC}"
echo ""

# Step 3: Summary
echo -e "${BLUE}═════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Setup Complete!${NC}"
echo ""
echo " To start the system:"
echo ""
echo -e "${YELLOW}Backend:${NC}"
echo "  cd backend_node"
echo "  npm start"
echo "  (Server runs on http://localhost:7070)"
echo ""
echo -e "${YELLOW}Frontend (في نافذة طرفية أخرى):${NC}"
echo "  cd frontend_flutter"
echo "  flutter run -t lib/main_modern.dart"
echo ""
echo -e "${GREEN}Database will auto-initialize on first backend start${NC}"
echo ""
echo "📖 Documentation: Read MODERN_UPDATES.md for details"
echo ""
