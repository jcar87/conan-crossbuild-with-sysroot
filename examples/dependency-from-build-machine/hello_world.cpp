#include <fmt/core.h>
#include <simdjson.h>
#include <string>

int main() {
  

  simdjson::ondemand::parser parser;
  auto json = "[1,2,3]"_padded;
  simdjson::ondemand::document doc = parser.iterate(json); // parse a string

  fmt::print("Hello, world!\n");

  return 0;
}