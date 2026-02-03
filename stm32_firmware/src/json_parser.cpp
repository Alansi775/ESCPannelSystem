#include "json_parser.h"
#include <string>
#include <cstring>
#include <cstdlib>
#include <cstdio>

using std::string;

static bool find_number_in_range(const string& s, size_t start, size_t end, const char* key, double& out) {
  size_t p = s.find(key, start);
  if (p == string::npos || p >= end) return false;
  size_t colon = s.find(':', p);
  if (colon == string::npos || colon >= end) return false;
  // start scanning after colon
  size_t i = colon + 1;
  // skip whitespace
  while (i < end && (s[i] == ' ' || s[i] == '\t' || s[i] == '\n' || s[i] == '\r')) ++i;
  if (i >= end) return false;
  // handle optional sign
  size_t j = i;
  if (s[j] == '+' || s[j] == '-') ++j;
  bool seen_digit = false;
  // integer part
  while (j < end && isdigit((unsigned char)s[j])) { seen_digit = true; ++j; }
  // fractional
  if (j < end && s[j] == '.') {
    ++j;
    while (j < end && isdigit((unsigned char)s[j])) { seen_digit = true; ++j; }
  }
  // exponent
  if (j < end && (s[j] == 'e' || s[j] == 'E')) {
    ++j;
    if (j < end && (s[j] == '+' || s[j] == '-')) ++j;
    bool had = false;
    while (j < end && isdigit((unsigned char)s[j])) { had = true; ++j; }
    if (!had) {
      // malformed exponent
    }
  }
  if (!seen_digit) return false;
  // parse substring
  string num = s.substr(i, j - i);
  char* endptr = nullptr;
  out = strtod(num.c_str(), &endptr);
  if (endptr == num.c_str()) return false;
  return true;
}

static bool find_int_in_range(const string& s, size_t start, size_t end, const char* key, long& out) {
  double d = 0.0;
  if (!find_number_in_range(s, start, end, key, d)) return false;
  out = (long)d;
  return true;
}

static bool find_string_in_range(const string& s, size_t start, size_t end, const char* key, string& out) {
  size_t p = s.find(key, start);
  if (p == string::npos || p >= end) return false;
  size_t colon = s.find(':', p);
  if (colon == string::npos || colon >= end) return false;
  size_t q1 = s.find('"', colon);
  if (q1 == string::npos || q1 >= end) return false;
  size_t q2 = s.find('"', q1 + 1);
  if (q2 == string::npos || q2 > end) return false;
  out = s.substr(q1 + 1, q2 - (q1 + 1));
  return true;
}

// find the braces-delimited object for a top-level key like "battery" or "motor"
static bool find_object_range(const string& s, const char* key, size_t& out_start, size_t& out_end) {
  size_t p = s.find(key);
  if (p == string::npos) return false;
  size_t brace = s.find('{', p);
  if (brace == string::npos) return false;
  // find matching closing brace
  int depth = 0;
  size_t i = brace;
  for (; i < s.size(); ++i) {
    if (s[i] == '{') ++depth;
    else if (s[i] == '}') {
      --depth;
      if (depth == 0) {
        out_start = brace + 1;
        out_end = i; // exclusive
        return true;
      }
    }
  }
  return false;
}

bool jsonparser::parse_json_to_appconfig(const std::vector<uint8_t>& json, AppConfig& out) {
  string s((const char*)json.data(), json.size());
  bool any = false;

  long tmpi = 0;
  double tmpd = 0.0;
  string tmps;

  // battery object
  size_t bstart, bend;
  if (find_object_range(s, "\"battery\"", bstart, bend)) {
    if (find_int_in_range(s, bstart, bend, "\"cells\"", tmpi)) { out.battery_cells = (uint8_t)tmpi; any = true; }
    if (find_number_in_range(s, bstart, bend, "\"voltage\"", tmpd)) { out.battery_voltage = (float)tmpd; any = true; }
    if (find_number_in_range(s, bstart, bend, "\"nominal\"", tmpd)) { out.battery_nominal = (float)tmpd; any = true; }
  }

  // sensor object
  size_t sstart, send;
  if (find_object_range(s, "\"sensor\"", sstart, send)) {
    if (find_string_in_range(s, sstart, send, "\"type\"", tmps)) {
      if (tmps == "sensorless") out.sensor_type = SENSORLESS;
      else out.sensor_type = SENSOR_UNKNOWN;
      any = true;
    }
    // optional sensor fields
    if (find_int_in_range(s, sstart, send, "\"maxRPM\"", tmpi)) { out.sensor_max_rpm = (uint32_t)tmpi; any = true; }
  }

  // motor object
  size_t mstart, mend;
  if (find_object_range(s, "\"motor\"", mstart, mend)) {
    if (find_string_in_range(s, mstart, mend, "\"type\"", tmps)) {
      // motor type ignored for now
      any = true;
    }
    if (find_int_in_range(s, mstart, mend, "\"kv\"", tmpi)) { out.motor_kv = (int32_t)tmpi; any = true; }
    if (find_int_in_range(s, mstart, mend, "\"poles\"", tmpi)) { out.motor_poles = (uint8_t)tmpi; any = true; }
  }

  // control object
  size_t cstart, cend;
  if (find_object_range(s, "\"control\"", cstart, cend)) {
    if (find_string_in_range(s, cstart, cend, "\"mode\"", tmps)) {
      if (tmps == "Throttle") out.control_mode = MODE_THROTTLE;
      else out.control_mode = MODE_UNKNOWN;
      any = true;
    }
    if (find_int_in_range(s, cstart, cend, "\"currentLimit\"", tmpi)) { out.control_current_limit = (uint16_t)tmpi; any = true; }
    if (find_int_in_range(s, cstart, cend, "\"pwmFrequency\"", tmpi)) { out.control_pwm_frequency = (uint16_t)tmpi; any = true; }
    // optional brake flag
    if (find_int_in_range(s, cstart, cend, "\"brakeEnabled\"", tmpi)) { out.control_brake_enabled = (uint8_t)tmpi; any = true; }
  }

  // safety object
  size_t s2start, s2end;
  if (find_object_range(s, "\"safety\"", s2start, s2end)) {
    if (find_int_in_range(s, s2start, s2end, "\"maxTemperature\"", tmpi)) { out.safety_max_tempreature = (uint8_t)tmpi; any = true; }
    if (find_int_in_range(s, s2start, s2end, "\"overcurrentLimit\"", tmpi)) { out.safety_overcurrent_limit = (uint16_t)tmpi; any = true; }
  }

  // Fallback: if some fields remain zero, try global (non-scoped) finds to be tolerant
  if (!any || out.battery_cells == 0) {
    long tli=0;
    if (find_int_in_range(s, 0, s.size(), "\"cells\"", tli)) { out.battery_cells = (uint8_t)tli; any = true; }
  }
  if (!any || out.battery_voltage == 0.0f) {
    double td=0.0;
    if (find_number_in_range(s, 0, s.size(), "\"voltage\"", td)) { out.battery_voltage = (float)td; any = true; }
    if (find_number_in_range(s, 0, s.size(), "\"nominal\"", td)) { out.battery_nominal = (float)td; any = true; }
  }
  if (!any || out.motor_kv == 0) {
    long tli=0;
    if (find_int_in_range(s, 0, s.size(), "\"kv\"", tli)) { out.motor_kv = (int32_t)tli; any = true; }
    if (find_int_in_range(s, 0, s.size(), "\"poles\"", tli)) { out.motor_poles = (uint8_t)tli; any = true; }
  }
  if (!any || out.control_current_limit == 0) {
    long tli=0;
    if (find_int_in_range(s, 0, s.size(), "\"currentLimit\"", tli)) { out.control_current_limit = (uint16_t)tli; any = true; }
    if (find_int_in_range(s, 0, s.size(), "\"pwmFrequency\"", tli)) { out.control_pwm_frequency = (uint16_t)tli; any = true; }
  }

  return any;
}
