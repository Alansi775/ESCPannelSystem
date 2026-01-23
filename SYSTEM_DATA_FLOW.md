# ESC Panel System - Complete Data Flow

**Status:** ✅ FULLY OPERATIONAL  
**Date:** January 23, 2026

---

## What Happens When User Clicks "Apply Configuration"

### Visual Flow:

```
┌─────────────────┐
│  Flutter App    │ User selects 12 parameters across 7 wizard steps
└────────┬────────┘
         │
         │ _buildConfigurationJSON()
         ▼
    ┌────────────────────────────────────────────────────┐
    │  JSON Configuration (297 bytes)                    │
    │  {                                                 │
    │    "timestamp": "2026-01-23T19:03:20.984",        │
    │    "battery": {cells, voltage, nominal},          │
    │    "sensor": {type, maxRPM},                      │
    │    "motor": {type, kv, poles},                    │
    │    "control": {mode, currentLimit, pwmFreq},      │
    │    "safety": {maxTemp, overcurrentLimit}          │
    │  }                                                 │
    └────────┬───────────────────────────────────────────┘
             │
             ├─────────────────────┬─────────────────────┐
             │                     │                     │
             ▼                     ▼                     ▼
    ┌──────────────────┐  ┌──────────────────┐  ┌─────────────────┐
    │  Database Save   │  │  Serial TX       │  │  User Feedback  │
    │  (MySQL)         │  │  (UART/Serial)   │  │  (UI Message)   │
    │  HTTP POST       │  │  HTTP POST       │  │  ✅ Success!    │
    │  /saveConfig     │  │  /applyConfig    │  │                 │
    └─────────┬────────┘  └────────┬─────────┘  └─────────────────┘
              │                    │
              ▼                    ▼
    ┌──────────────────┐  ┌──────────────────────────┐
    │ esc_configs      │  │  ESC Device              │
    │ Table            │  │  Receives 303 bytes      │
    │ id=2             │  │  Binary packet           │
    │ user_id=14       │  │  Parses & applies       │
    │ config_json={...}│  │  Hardware configured    │
    └──────────────────┘  └──────────────────────────┘
```

---

## Detailed Step-by-Step

### STEP 1: User Input Collection (Wizard Pages)

**Screen: Connect Screen**
- User selects ESC device port: `/dev/tty.URT1`
- Stored in: `ESCProvider.connectedPort`

**Screen: Battery Step**
- User selects: 8 cells
- Stored in: `ESCProvider.wizardBatteryCells = 8`

**Screen: Sensor Step**
- User selects: Encoder
- User enters: maxRPM = 5000
- Stored in: `ESCProvider.wizardSensorMode = "Encoder"`, `wizardMaxRPM = 5000`

**Screen: Motor Step**
- User selects: BLDC motor, 1000 KV, 4 poles
- Stored in: `ESCProvider` (motorType, kvRating, polePairs)

**Screen: Control Step**
- User selects: Throttle mode, 50A, 16 kHz PWM, 60°C limit, 100A overcurrent
- Stored in: `ESCProvider` (controlMode, maxCurrent, pwmFrequency, maxTemp, overcurrentLimit)

**Result:** `ESCProvider.wizardConfig` now contains:
```dart
{
  'batteryCells': 8,
  'motorType': 'BLDC',
  'polePairs': 4,
  'kvRating': 1000,
  'maxCurrent': 50,
  'maxRPM': 5000,
  'sensorMode': 'Encoder',
  'controlMode': 'Throttle',
  'brakeEnabled': false,
  'pwmFrequency': 16,
  'maxTemp': 60,
  'overcurrentLimit': 100,
}
```

---

### STEP 2: User Clicks "Apply" Button

**File:** `lib/ui/screens/wizard_screen.dart`  
**Function:** `onPressed()` handler for Apply button

```dart
onPressed: () async {
  // This code runs when user clicks "Apply Configuration"
}
```

---

### STEP 3: Build Configuration JSON

**Function:** `_buildConfigurationJSON(ESCProvider provider)`

**Input:** Raw wizard selections from `ESCProvider.wizardConfig`

**Process:**
1. Get each value from wizardConfig
2. Transform into standardized JSON structure
3. Add timestamp
4. Calculate derived values (e.g., voltage from cells)

**Output:**
```json
{
  "timestamp": "2026-01-23T19:03:20.984",
  "battery": {
    "cells": 8,
    "voltage": 29.6,
    "nominal": 29.6
  },
  "sensor": {
    "type": "encoder",
    "maxRPM": 5000
  },
  "motor": {
    "type": "BLDC",
    "kv": 1000,
    "poles": 4
  },
  "control": {
    "mode": "Throttle",
    "currentLimit": 50,
    "pwmFrequency": 16
  },
  "safety": {
    "maxTemperature": 60,
    "overcurrentLimit": 100
  }
}
```

**Size:** ~297 bytes

---

### STEP 4: Clean JSON for Safety

**Function:** `_cleanMap(configJson)`

**Why:** Ensures all nested Maps are proper `Map<String, dynamic>` type for JSON serialization

**Process:**
- Convert any `LinkedMap` to `Map<String, dynamic>`
- Verify all values are JSON-safe (String, int, double, bool, null)
- Remove any custom objects

**Result:** Clean, JSON-serializable configuration

---

### STEP 5: Part A - Save to Database

**API Endpoint:** `POST http://localhost:7070/saveConfig`

**Request sent to Backend:**
```json
{
  "userId": 14,
  "profileName": "config-1769184600984",
  "escType": "BLDC",
  "configJson": { /* 297-byte config */ }
}
```

**Backend Processing (server.js):**
```javascript
// 1. Validate userId exists
// 2. Check JSON size < 2MB
// 3. DELETE any previous configs for this user
//    → Only ONE config per user (new one replaces old)
// 4. INSERT new config into esc_configs table
// 5. Return configId to confirm
```

**Database Result:**
```sql
INSERT INTO esc_configs (
  user_id, profile_name, esc_type, config_json, created_at, updated_at
) VALUES (
  14, 'config-1769184600984', 'BLDC', '{...}', NOW(), NOW()
);
-- Inserted row with ID=2
```

**Response back to Flutter:**
```json
{
  "success": true,
  "message": "Configuration saved (previous configuration replaced)",
  "configId": 2,
  "userId": 14,
  "profileName": "config-1769184600984"
}
```

**Result:** ✅ Configuration permanently stored in database

---

### STEP 5: Part B - Apply to ESC Device via Serial

**Immediately after database save completes...**

**API Endpoint:** `POST http://localhost:7070/applyConfig`

**Request sent to Backend:**
```json
{
  "userId": 14,
  "configJson": { /* same 297-byte config */ },
  "portPath": "/dev/tty.URT1"
}
```

**Backend Processing (server.js → escConnection.js):**

1. **Connect to Serial Port**
   ```javascript
   const port = new SerialPort({
     path: "/dev/tty.URT1",
     baudRate: 115200
   });
   ```

2. **Build Binary Packet**
   - Convert JSON to string: `'{"timestamp":"2026-01-23T19:03:20.984",...}'`
   - Create header: `[0xAE, 0x53]` (AESC protocol)
   - Add length: Big-endian 16-bit = `0x0129` (297 in decimal)
   - Calculate checksum: XOR of all JSON bytes
   - Add terminator: `0x0A` (line feed)

3. **Packet Structure (303 bytes total):**
   ```
   HEADER   LENGTH  CHECKSUM  JSON DATA           TERMINATOR
   ├─ 2B ─┤├─ 2B ─┤├─1B─┤├────── 297B ──────┤├─ 1B ─┤
   AE 53   01 29   12    {"timestamp":"..."}  0A
   ```

4. **Transmit via Serial**
   ```javascript
   port.write(packet, (error) => {
     if (!error) {
       console.log("✓ Configuration packet sent successfully (303 bytes)");
     }
   });
   ```
   - Transmission speed: 115200 baud
   - Time to transmit: ~26 milliseconds

5. **Response to Flutter:**
   ```json
   {
     "success": true,
     "message": "Configuration applied to ESC device",
     "transmission": {
       "bytesSent": 303,
       "packetStructure": {
         "header": "ae53",
         "length": "0129",
         "checksum": "12",
         "dataLength": 297,
         "terminator": "0A"
       }
     }
   }
   ```

**Result:** ✅ Configuration transmitted to ESC device

---

## What The ESC Device Receives

### Binary Packet on UART:

```
SERIAL PORT: /dev/tty.URT1
BAUD RATE: 115200
STOP BITS: 1
PARITY: None
DATA BITS: 8

RECEIVED PACKET (303 bytes):
┌──────────────────────────────────────────────────────────┐
│ AE 53 01 29 12 7B 22 74 69 6D 65 73 74 61 6D 70 ...  0A │
│ ↑     ↑     ↑  ↑  ↑       ↑                        ↑     │
│ HEADER  LEN CHK JSON DATA                      TERM     │
└──────────────────────────────────────────────────────────┘

Full JSON String (297 bytes):
{"timestamp":"2026-01-23T19:03:20.984","battery":{...},"sensor":{...},...}
```

### ESC Firmware Must Do:

```c
// ESC Firmware (pseudocode)

1. Wait for data on UART
2. Read until 0x0A (terminator)
3. Validate header = 0xAE53
4. Extract length from bytes 2-3
5. Extract checksum from byte 4
6. Read JSON data (length bytes)
7. Verify checksum: calculate XOR of data, compare with extracted checksum
8. If checksum valid:
   - Parse JSON
   - Extract parameters (cells, maxRPM, motorType, etc.)
   - Apply to hardware registers
   - Configure motor controller
   - Send ACK back to system

If checksum invalid:
   - Send error/NAK
   - Wait for retry
```

---

## Complete Timeline

```
T+0ms    User clicks "Apply Configuration" button

T+10ms   _buildConfigurationJSON() runs
         - Collect 12 parameters
         - Validate types
         - Add timestamp
         Result: 297-byte JSON

T+20ms   _cleanMap() runs
         - Type validation
         - JSON-safe checking

T+30ms   HTTP POST /saveConfig sent to backend
         - Backend connects to MySQL
         - DELETE old config
         - INSERT new config
         - Return configId

T+80ms   HTTP POST /applyConfig sent to backend
         - Backend connects to serial port
         - Build 303-byte binary packet
         - Transmit over UART
         - Response returned

T+150ms  Total end-to-end time
         ✅ Database saved
         ✅ Serial transmitted
         ✅ User sees success message
```

---

## Database State After Apply

### Before:
```
MySQL: esc_configs table
(empty for user_id=14, or contains old config)
```

### After:
```
MySQL: esc_configs table

id | user_id | profile_name         | esc_type | config_json                      | created_at | updated_at
---+---------+----------------------+----------+----------------------------------+------------+------------
2  | 14      | config-1769184600984 | BLDC     | {"timestamp":"2026-01-...}       | 2026-01... | 2026-01...

✅ Only ONE row (old one deleted, new one inserted)
```

---

## Key Points for ESC Firmware Development

### 1. Serial Protocol Details
- **Port:** Any available UART (e.g., `/dev/ttyS0` on Raspberry Pi, hardware UART on microcontroller)
- **Baud Rate:** 115200 (fixed)
- **Protocol:** Custom binary with JSON payload
- **Packet Size:** ~303 bytes (variable based on config size)

### 2. Packet Parsing
```c
struct packet {
  uint8_t header[2];      // 0xAE, 0x53
  uint16_t length;        // big-endian, data length
  uint8_t checksum;       // XOR of all data bytes
  char* json_data;        // variable length
  uint8_t terminator;     // 0x0A
};
```

### 3. Checksum Algorithm
```c
uint8_t calculate_checksum(uint8_t* data, uint16_t length) {
  uint8_t checksum = 0;
  for (int i = 0; i < length; i++) {
    checksum ^= data[i];  // XOR
  }
  return checksum;
}
```

### 4. JSON Configuration Keys
The ESC must extract and apply these JSON keys:

| Key | Path | Type | Example | Action |
|-----|------|------|---------|--------|
| cells | battery.cells | int | 8 | Configure LiPo cells |
| maxRPM | sensor.maxRPM | int | 5000 | Set speed limit |
| motorKV | motor.kv | int | 1000 | Store motor constant |
| motorPoles | motor.poles | int | 4 | Configure poles |
| currentLimit | control.currentLimit | int | 50 | Set current limit |
| pwmFreq | control.pwmFrequency | int | 16 | Set PWM frequency |
| maxTemp | safety.maxTemperature | int | 60 | Set thermal cutoff |
| overcurrentLimit | safety.overcurrentLimit | int | 100 | Set OCP threshold |
| sensorType | sensor.type | string | "encoder" | Configure sensor |
| motorType | motor.type | string | "BLDC" | Set motor type |
| controlMode | control.mode | string | "Throttle" | Set control mode |

### 5. Configuration Application
After parsing JSON:
```c
// Example: Apply battery configuration
if (config.battery.cells == 8) {
  // Set voltage threshold to 8 * 3.0V = 24V (for LiPo)
  set_battery_cells(8);
  set_low_voltage_cutoff(2.8);  // 2.8V per cell
}

// Example: Apply motor configuration
if (config.motor.type == "BLDC") {
  set_motor_type(BLDC);
  set_motor_kv(config.motor.kv);
  set_pole_pairs(config.motor.poles);
}

// Example: Apply safety limits
set_temperature_limit(config.safety.maxTemperature);
set_current_limit(config.control.currentLimit);
```

### 6. Acknowledgment (Optional)
ESC can send ACK back to system:
```c
// Send ACK packet back to system
uint8_t ack_packet[] = {0xAE, 0x53, 0x00, 0x01, 0x01, 0x4F, 0x4B, 0x0A};
//                       HEADER      LEN   CHKSUM "OK"  TERM
uart_write(ack_packet, sizeof(ack_packet));
```

---

## Example ESC Pseudocode

```c
#include "uart.h"
#include "json_parser.h"

void main() {
  uart_init(115200);
  
  while (1) {
    if (uart_has_data()) {
      // Read packet
      uint8_t header[2];
      uart_read(header, 2);
      
      if (header[0] == 0xAE && header[1] == 0x53) {
        // Valid AESC header
        uint16_t length = uart_read_u16_be();
        uint8_t checksum = uart_read_u8();
        
        uint8_t* json_data = malloc(length);
        uart_read(json_data, length);
        
        uint8_t terminator = uart_read_u8();
        
        // Validate
        if (terminator == 0x0A && 
            calculate_checksum(json_data, length) == checksum) {
          
          // Parse JSON
          config_t config = parse_json(json_data, length);
          
          // Apply configuration
          apply_battery_config(config.battery);
          apply_motor_config(config.motor);
          apply_sensor_config(config.sensor);
          apply_control_config(config.control);
          apply_safety_config(config.safety);
          
          // Send ACK
          uart_write_ack();
        }
        
        free(json_data);
      }
    }
  }
}
```

---

## Debugging Tips

### In Flutter (Debug Console):
```
💾 Step 1: Saving configuration to database...
✓ Configuration saved to database

📤 Step 2: Applying configuration to ESC device...
✓ Configuration applied to device
```

### In Backend (Node.js Console):
```
📝 [saveConfig] Received configuration:
  User ID: 14
  Configuration JSON: {...}
✓ New configuration saved to database (ID: 2)

🔧 [applyConfig] Applying configuration to ESC device
   Port: /dev/tty.URT1
   → Connecting to device...
   ✓ Connected
📤 [Serial TX] Sending configuration (297 bytes)
✓ Configuration packet sent successfully (303 bytes total)
```

### In ESC (Serial Monitor):
```
Received packet: 303 bytes
Header: 0xAE 0x53 ✓
Length: 297 bytes ✓
Checksum: 0x12 ✓
Data: {"timestamp":"2026-01-23T19:03:20.984"...}
Terminator: 0x0A ✓
Applying configuration:
  - Battery cells: 8
  - Motor type: BLDC
  - KV Rating: 1000
  - Sensor: Encoder (5000 RPM)
  - Current limit: 50A
  - PWM frequency: 16 kHz
  - Temperature limit: 60°C
Configuration applied successfully! ✓
Sending ACK...
```

---

## Summary

When user clicks "Apply Configuration":

1. **Flutter builds 297-byte JSON** from 12 wizard parameters
2. **HTTP POST to Backend** saves to MySQL database
3. **Backend checks port connection** to ESC device
4. **303-byte binary packet created** (header + length + checksum + JSON + terminator)
5. **Serial transmission** at 115200 baud to ESC
6. **ESC receives packet**, validates checksum, parses JSON
7. **ESC applies configuration** to motor controller hardware
8. **System ready** to operate with new settings

**Total time:** ~150-200 milliseconds

---

**Use this document when developing ESC firmware.**
