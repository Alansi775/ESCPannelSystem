#ifndef JSON_PARSER_H
#define JSON_PARSER_H
#include <vector>
#include "app_config.h"

namespace jsonparser {
  bool parse_json_to_appconfig(const std::vector<uint8_t>& json, AppConfig& out);
}

#endif // JSON_PARSER_H
