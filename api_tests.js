#!/usr/bin/env node

/**
 * ESC Configuration System - API Testing Guide
 * Run tests with: node api_tests.js
 */

const http = require('http');

// ANSI Colors
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
};

class APITester {
  constructor(baseUrl = 'http://localhost:7070') {
    this.baseUrl = baseUrl;
    this.testResults = [];
  }

  log(level, message, data = '') {
    const prefix = {
      info: `${colors.blue}ℹ${colors.reset}`,
      success: `${colors.green}✓${colors.reset}`,
      error: `${colors.red}✗${colors.reset}`,
      warn: `${colors.yellow}⚠${colors.reset}`,
      test: `${colors.cyan}→${colors.reset}`,
    }[level] || '●';

    console.log(`${prefix} ${message}${data ? ' ' + colors.cyan + data + colors.reset : ''}`);
  }

  async request(method, path, body = null) {
    return new Promise((resolve, reject) => {
      const url = new URL(path, this.baseUrl);
      const options = {
        method,
        headers: {
          'Content-Type': 'application/json',
        },
      };

      const req = http.request(url, options, (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          try {
            resolve({
              status: res.statusCode,
              data: data ? JSON.parse(data) : null,
              headers: res.headers,
            });
          } catch (e) {
            resolve({
              status: res.statusCode,
              data: data,
              headers: res.headers,
            });
          }
        });
      });

      req.on('error', reject);
      if (body) {
        req.write(JSON.stringify(body));
      }
      req.end();
    });
  }

  async testEndpoint(name, method, path, body = null, expectedStatus = 200) {
    try {
      this.log('test', `Testing ${method} ${path}`, name);
      const response = await this.request(method, path, body);

      if (response.status === expectedStatus) {
        this.log('success', `${method} ${path}`, `Status: ${response.status}`);
        this.testResults.push({ name, passed: true });
        return response.data;
      } else {
        this.log(
          'error',
          `${method} ${path}`,
          `Expected ${expectedStatus}, got ${response.status}`
        );
        this.testResults.push({ name, passed: false });
        return null;
      }
    } catch (error) {
      this.log('error', `${method} ${path}`, `Error: ${error.message}`);
      this.testResults.push({ name, passed: false });
      return null;
    }
  }

  printSummary() {
    console.log('\n' + '='.repeat(60));
    const passed = this.testResults.filter((r) => r.passed).length;
    const total = this.testResults.length;
    const percentage = ((passed / total) * 100).toFixed(1);

    if (passed === total) {
      this.log('success', `All tests passed!`, `${passed}/${total} (${percentage}%)`);
    } else {
      this.log('warn', `Some tests failed`, `${passed}/${total} (${percentage}%)`);
      console.log('\nFailed tests:');
      this.testResults.filter((r) => !r.passed).forEach((r) => {
        this.log('error', r.name);
      });
    }
    console.log('='.repeat(60) + '\n');
  }
}

async function runTests() {
  console.log(`\n${colors.cyan}${'='.repeat(60)}`);
  console.log('  ESC Configuration System - API Testing Suite');
  console.log(`${'='.repeat(60)}${colors.reset}\n`);

  const tester = new APITester();

  // Test 1: Server Status
  await tester.testEndpoint(
    'Get Server Status',
    'GET',
    '/status',
    null,
    200
  );

  // Test 2: List Available Ports
  await tester.testEndpoint(
    'List Serial Ports',
    'GET',
    '/ports',
    null,
    200
  );

  // Test 3: Generate Auto Config - Light Mode
  await tester.testEndpoint(
    'Generate Auto Config (4S Light)',
    'POST',
    '/autoConfig',
    {
      cells: 4,
      mode: 'light',
    },
    200
  );

  // Test 4: Generate Auto Config - Middle Mode
  await tester.testEndpoint(
    'Generate Auto Config (4S Middle)',
    'POST',
    '/autoConfig',
    {
      cells: 4,
      mode: 'middle',
    },
    200
  );

  // Test 5: Generate Auto Config - High Mode
  await tester.testEndpoint(
    'Generate Auto Config (4S High)',
    'POST',
    '/autoConfig',
    {
      cells: 4,
      mode: 'high',
    },
    200
  );

  // Test 6: Generate Auto Config - Different Cell Count
  await tester.testEndpoint(
    'Generate Auto Config (6S Middle)',
    'POST',
    '/autoConfig',
    {
      cells: 6,
      mode: 'middle',
    },
    200
  );

  // Test 7: Get Profiles (Empty)
  await tester.testEndpoint(
    'Get All Profiles',
    'GET',
    '/profiles',
    null,
    200
  );

  // Test 8: Save Profile
  const profileData = await tester.testEndpoint(
    'Save Profile',
    'POST',
    '/saveProfile',
    {
      profileName: 'Test Profile 4S Light',
      config: {
        maxRPM: 50000,
        currentLimit: 160,
        pwmFreq: 24000,
        tempLimit: 100,
        voltageCutoff: 1200,
      },
    },
    200
  );

  // Test 9: Get Profiles (After Save)
  if (profileData && profileData.profile) {
    await tester.testEndpoint(
      'Get All Profiles (After Save)',
      'GET',
      '/profiles',
      null,
      200
    );

    // Test 10: Get Profile by ID
    const profileId = profileData.profile.id;
    await tester.testEndpoint(
      `Get Profile by ID (${profileId})`,
      'GET',
      `/profiles/${profileId}`,
      null,
      200
    );
  }

  // Test 11: Invalid Auto Config (Bad Mode)
  await tester.testEndpoint(
    'Invalid Auto Config (Bad Mode)',
    'POST',
    '/autoConfig',
    {
      cells: 4,
      mode: 'invalid',
    },
    400
  );

  // Test 12: Invalid Auto Config (Bad Cells)
  await tester.testEndpoint(
    'Invalid Auto Config (Cells > 12)',
    'POST',
    '/autoConfig',
    {
      cells: 15,
      mode: 'middle',
    },
    400
  );

  // Test 13: 404 Not Found
  await tester.testEndpoint(
    '404 Not Found',
    'GET',
    '/nonexistent',
    null,
    404
  );

  // Print summary
  tester.printSummary();

  // Print detailed test results
  console.log(`${colors.blue}Detailed Results:${colors.reset}`);
  tester.testResults.forEach((result, index) => {
    const status = result.passed ? `${colors.green}PASS${colors.reset}` : `${colors.red}FAIL${colors.reset}`;
    console.log(`  ${index + 1}. ${status} - ${result.name}`);
  });
  console.log();
}

// Run tests
runTests().catch((error) => {
  console.error(`${colors.red}Test suite error: ${error.message}${colors.reset}`);
  process.exit(1);
});
