#!/usr/bin/env python3
import serial
import time
import sys

def send_frame():
    # البيانات المطلوبة
    data = bytes([
        0xAA, 0x55, 0x01, 0x06, 0x56, 0xB8, 0x56, 0xB8, 
        0x00, 0x01, 0x00, 0x00, 0x03, 0xE8, 0x04, 0x01, 
        0x00, 0x33, 0x00, 0x10, 0x00, 0x00, 0x3C, 0x00, 
        0x64, 0x00, 0x00, 0x00, 0x93
    ])
    
    port = '/dev/cu.usbserial-A50285BI'
    
    try:
        print(f"🔌 Opening port: {port}")
        ser = serial.Serial(port, 115200, timeout=2)
        time.sleep(2)  # انتظر حتى يستقر الـ serial port
        
        print(f"📤 Sending {len(data)} bytes...")
        print("Data (HEX):", ' '.join(f'{b:02X}' for b in data))
        
        ser.write(data)
        print("✅ Data sent successfully!")
        
        # انتظر شوي واقرأ الرد
        time.sleep(1)
        if ser.in_waiting > 0:
            response = ser.read(ser.in_waiting)
            print(f"📥 Response: {response}")
        
        ser.close()
        print("✅ Port closed")
        
    except serial.SerialException as e:
        print(f"❌ Error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    send_frame()