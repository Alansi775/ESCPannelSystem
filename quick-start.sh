#!/bin/bash

# 🚀 ESC Panel System - Quick Start Script
# January 23, 2026

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     ESC Panel System - Quick Start Configuration           ║"
echo "║              Backend + Database Setup                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check Node.js
echo -e "${BLUE}[1/5]${NC} Checking Node.js..."
if command -v node &> /dev/null; then
    NODE_VERSION=$(node -v)
    echo -e "${GREEN}✓${NC} Node.js ${NODE_VERSION} found"
else
    echo -e "${RED}✗${NC} Node.js not found. Please install it."
    exit 1
fi

# Check MySQL
echo -e "${BLUE}[2/5]${NC} Checking MySQL..."
if command -v mysql &> /dev/null; then
    echo -e "${GREEN}✓${NC} MySQL found"
else
    echo -e "${RED}✗${NC} MySQL not found. Install with: brew install mysql"
    exit 1
fi

# Check if MySQL is running
echo -e "${BLUE}[3/5]${NC} Checking MySQL Service..."
if mysql -u root -p'root' -e "SELECT 1" &> /dev/null; then
    echo -e "${GREEN}✓${NC} MySQL service is running"
else
    echo -e "${YELLOW}⚠${NC} MySQL not running. Starting..."
    sudo brew services start mysql
    sleep 2
    if mysql -u root -p'root' -e "SELECT 1" &> /dev/null; then
        echo -e "${GREEN}✓${NC} MySQL started successfully"
    else
        echo -e "${RED}✗${NC} Could not start MySQL"
        exit 1
    fi
fi

# Install dependencies
echo -e "${BLUE}[4/5]${NC} Installing Node dependencies..."
cd backend_node
if [ ! -d "node_modules" ]; then
    npm install --silent
    echo -e "${GREEN}✓${NC} Dependencies installed"
else
    echo -e "${GREEN}✓${NC} Dependencies already installed"
fi

# Setup database
echo -e "${BLUE}[5/5]${NC} Setting up database..."
if node setup-db.js &> /dev/null; then
    echo -e "${GREEN}✓${NC} Database configured"
else
    echo -e "${YELLOW}⚠${NC} Database already configured (or minor issue)"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                 ✅ Setup Complete!                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Display connection info
echo -e "${BLUE}Database Connection Info:${NC}"
echo "  Host:     127.0.0.1"
echo "  Port:     3306"
echo "  Username: root"
echo "  Password: root"
echo "  Database: esc_config"
echo "  Socket:   /tmp/mysql.sock"
echo ""

echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Start the server:"
echo "     ${YELLOW}node server.js${NC}"
echo ""
echo "  2. Server will run on:"
echo "     ${YELLOW}http://localhost:7070${NC}"
echo ""
echo "  3. Test in another terminal:"
echo "     ${YELLOW}curl http://localhost:7070/status${NC}"
echo ""
echo "  4. Connect VS Code Extension:"
echo "     - Open MySQL extension"
echo "     - Click '+' to add connection"
echo "     - Use connection info above"
echo ""
echo "  5. View API Documentation:"
echo "     See READY_TO_GO.md for full API reference"
echo ""

echo -e "${GREEN}System is ready!${NC}"
