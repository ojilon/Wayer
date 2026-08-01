cmake_minimum_required(VERSION 3.22.1)
project("wayer_native")

# Target C++23 standard
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Tell CMake to look inside the 'cmake' folder for modules
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# Pull in your strict compiler flags template
include(CompilerFlags)

add_library(
    wayer_native
    SHARED
    wayer_native.cpp
)

find_library(
    log-lib
    log
)

target_link_libraries(
    wayer_native
    ${log-lib}
    project_warnings
)