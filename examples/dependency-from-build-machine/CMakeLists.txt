cmake_minimum_required(VERSION 3.20)

project(cmake-system-info LANGUAGES CXX)

message(STATUS "----------------------------------------------------------")
message(STATUS "CMAKE_SYSTEM_NAME: ${CMAKE_SYSTEM_NAME}")
message(STATUS "CMAKE_SYSTEM_PROCESSOR: ${CMAKE_SYSTEM_PROCESSOR}")
message(STATUS "CMAKE_CROSSCOMPILING: ${CMAKE_CROSSCOMPILING}")
message(STATUS "CMAKE_LIBRARY_ARCHITECTURE: ${CMAKE_LIBRARY_ARCHITECTURE}")
message(STATUS "----------------------------------------------------------")

# fmt
set(fmt_DIR "${CMAKE_BINARY_DIR}/generators")
find_package(fmt REQUIRED)
message("FMT version found: ${fmt_VERSION}, expected=11.0.2")
message("FMT was found at: ${fmt_DIR}")

# simdjson
# set(simdjson_DIR "${CMAKE_BINARY_DIR}/generators")
find_package(simdjson CONFIG REQUIRED)
message("simdjson version found: ${simdjson_VERSION}")
message("simdjson found at: ${simdjson_DIR}")

add_executable(hello_world hello_world.cpp)
target_link_libraries(hello_world PRIVATE fmt::fmt simdjson::simdjson)