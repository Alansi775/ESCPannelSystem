#!/bin/bash

# ESC Configuration System - API Testing Script
# Usage: ./run_tests.sh

set -e

BASE_URL="http://localhost:7070"

echo "================================================"
echo "  ESC Configuration API Testing"
echo "================================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
PASS=0
FAIL=0

test_endpoint() {
    local name=$1
    local method=$2
    local endpoint=$3
    local data=$4
    
    echo -e "${BLUE}→${NC} Testing: $name"
    
    if [ -z "$data" ]; then
        # GET request
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$BASE_URL$endpoint")
    else
        # POST request
        response=$(curl -s -w "\n%{http_code}" -X "$method" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$BASE_URL$endpoint")
    fi
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        echo -e "${GREEN}✓ PASS${NC} (HTTP $http_code)"
        ((PASS++))
    else
        echo -e "${RED}✗ FAIL${NC} (HTTP $http_code)"
        ((FAIL++))
    fi
    
    echo "  Response: $(echo $body | head -c 80)..."
    echo ""
}

# Test 1: Server Status
test_endpoint "Get Server Status" "GET" "/status"

# Test 2: List Ports
test_endpoint "List Available Ports" "GET" "/ports"

# Test 3: Auto Config - 4S Light
test_endpoint "Generate Auto Config (4S Light)" "POST" "/autoConfig" \
    '{"cells":4,"mode":"light"}'

# Test 4: Auto Config - 4S Middle
test_endpoint "Generate Auto Config (4S Middle)" "POST" "/autoConfig" \
    '{"cells":4,"mode":"middle"}'

# Test 5: Auto Config - 6S High
test_endpoint "Generate Auto Config (6S High)" "POST" "/autoConfig" \
    '{"cells":6,"mode":"high"}'

# Test 6: Get Profiles
test_endpoint "Get All Profiles" "GET" "/profiles"

# Test 7: Save Profile
test_endpoint "Save Profile" "POST" "/saveProfile" \
    '{"profileName":"Test Profile","config":{"maxRPM":50000,"currentLimit":160,"pwmFreq":24000,"tempLimit":100,"voltageCutoff":1200}}'

# Test 8: Invalid Endpoint
test_endpoint "404 Not Found" "GET" "/nonexistent"

# Print Summary
echo "================================================"
echo "  Test Summary"
echo "================================================"
echo -e "${GREEN}Passed: $PASS${NC}"
echo -e "${RED}Failed: $FAIL${NC}"
TOTAL=$((PASS + FAIL))
echo -e "Total: $TOTAL"

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
