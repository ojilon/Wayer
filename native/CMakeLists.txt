cmake_minimum_required(VERSION 3.22.1)
project("wayer_engine")

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(CompilerFlags)

# 1. Static library for reusable cross-platform core
add_library(
    wayer_core
    STATIC
    storage/storage_engine.cpp
    documents/document_engine.cpp
    transfer/transfer_engine.cpp
)

target_include_directories(wayer_core PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(wayer_core PRIVATE project_warnings)

# 2. Shared JNI library wrapper for Android
add_library(
    wayer_engine
    SHARED
    wayer_engine.cpp
)

find_library(log-lib log)

target_link_libraries(
    wayer_engine
    PRIVATE
    wayer_core
    ${log-lib}
    project_warnings
)