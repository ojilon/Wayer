cmake_minimum_required(VERSION 3.22.1)
project("wayer_engine")

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(CompilerFlags)

add_library(
    wayer_engine
    SHARED
    wayer_engine.cpp
    storage/storage_engine.cpp
    transfer/transfer_engine.cpp
)

target_include_directories(wayer_engine PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

find_library(log-lib log)

target_link_libraries(
    wayer_engine
    PRIVATE
    ${log-lib}
    project_warnings
)