#!/bin/bash

# ESC Configuration System - Quick Start Script
# This script sets up and starts the complete system

set -e

echo "================================================"
echo "  ESC Configuration System - Quick Start"
echo "================================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Backend Setup
echo -e "${BLUE} Setting up Backend...${NC}"
cd backend_node

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
else
    echo "Dependencies already installed"
fi

echo -e "${GREEN} Backend ready${NC}"
echo ""

# Frontend Setup
echo -e "${BLUE}📱 Setting up Frontend...${NC}"
cd ../frontend_flutter

# Check if pubspec.lock exists
if [ ! -f "pubspec.lock" ]; then
    echo "Getting Flutter dependencies..."
    flutter pub get
else
    echo "Flutter dependencies already installed"
fi

echo -e "${GREEN} Frontend ready${NC}"
echo ""

# Instructions
echo -e "${YELLOW}================================================"
echo "  Ready to start!"
echo "================================================${NC}"
echo ""
echo "1️⃣  Start the Backend (Terminal 1):"
echo -e "   ${BLUE}cd backend_node${NC}"
echo -e "   ${BLUE}npm start${NC}"
echo ""
echo "2️⃣  Start the Frontend (Terminal 2):"
echo -e "   ${BLUE}cd frontend_flutter${NC}"
echo -e "   ${BLUE}flutter run${NC}"
echo ""
echo "3️⃣  Connect your ESC via USB and click 'Connect' in the app"
echo ""
echo -e "${GREEN} Happy configuring!${NC}"
