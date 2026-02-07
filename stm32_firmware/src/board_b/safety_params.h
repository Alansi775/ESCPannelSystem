#pragma once

// Hardware-specific ADC and sensor parameters — update these only.

// ADC reference voltage in volts
#define SAFETY_ADC_REF_VOLTAGE 3.3f

// ADC resolution in bits (e.g., 12)
#define SAFETY_ADC_RESOLUTION_BITS 12

// Vbus divider ratio (Vbus = adc_voltage * VBUS_DIVIDER)
#define SAFETY_VBUS_DIVIDER 11.0f

// Shunt resistance in milliohms (mΩ). Example: 1 mΩ -> 1.0f
#define SAFETY_SHUNT_MOHMS 1.0f

// Shunt amplifier gain
#define SAFETY_SHUNT_AMP_GAIN 50.0f

// Temperature sensor: mV per degree (LM35 = 10.0)
#define SAFETY_TEMP_MV_PER_DEG 10.0f

// Calibration settings
#define SAFETY_CAL_PRINT_MS 100 // print interval during calibration (10Hz)
#define SAFETY_CAL_AVG_MS 2000  // average duration for zero-current offset
