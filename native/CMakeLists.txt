# =============================================================================
# native/CMakeLists.txt — top-level native build (C + C++ + Odin)
#
# Beginner map:
#   1. Third-party (json, sqlite)  → always available
#   2. C++ modules (core, storage, …) → still doing real work via the shim
#   3. Odin package                → router + the pieces we have rewritten
#   4. jni/                        → thin C wrapper that Android actually loads
#
# You can add new .odin files almost anywhere under native/ without editing
# this file. CMake discovers them with GLOB_RECURSE (see ODIN section below).
# Just make sure some existing Odin package imports the new file (or put it
# next to an already-imported package).
# =============================================================================

cmake_minimum_required(VERSION 3.22.1)
project(wayer_engine LANGUAGES C CXX)

# --- language standards -------------------------------------------------------
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Helps clangd / IDEs. Gradle copies the result to repo-root build/.
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(CompilerFlags)

# =============================================================================
# Third-party (vendored, gitignored — see third_party/README.md)
# Fail early at configure time if they are missing.
# =============================================================================
if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/third_party/json/include/nlohmann/json.hpp")
    message(FATAL_ERROR
        "Missing third_party/json/include/nlohmann/json.hpp\n"
        "See docs/BRIDGE_PLAN.md Step 0.")
endif()
if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/third_party/sqlite/sqlite3.c")
    message(FATAL_ERROR
        "Missing third_party/sqlite/sqlite3.c\n"
        "See docs/BRIDGE_PLAN.md Step 0.")
endif()

# Header-only JSON
add_library(wayer_json INTERFACE)
target_include_directories(wayer_json INTERFACE
    ${CMAKE_CURRENT_SOURCE_DIR}/third_party/json/include
)

# SQLite amalgamation (one big C file). We deliberately do NOT attach
# project_warnings — third-party noise would drown our own warnings.
add_library(wayer_sqlite3 STATIC
    third_party/sqlite/sqlite3.c
)
target_include_directories(wayer_sqlite3 PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/third_party/sqlite
)

# =============================================================================
# C++ domain modules (still the bulk of the work today)
# =============================================================================
add_subdirectory(core)
add_subdirectory(storage)
add_subdirectory(documents)
add_subdirectory(transfer)
add_subdirectory(media)
add_subdirectory(preview)
add_subdirectory(shim)

# =============================================================================
# Odin — build a static archive that the C JNI layer links against
#
# How it works (simple version):
#   1. We run the Odin compiler once, producing several .o files.
#   2. We pack those .o files into libwayer_core_odin.a with llvm-ar.
#   3. jni/ links that archive + the C++ shim + the other modules.
#
# Adding new .odin files:
#   - Drop them anywhere under native/ (e.g. native/storage/src/foo.odin).
#   - Import them from an existing package (see native/odin/wayer_core.odin).
#   - CMake will notice the new file on the next configure (GLOB_RECURSE
#     + CONFIGURE_DEPENDS) and rebuild the Odin archive. No CMake edit needed.
# =============================================================================

# --- find the Odin compiler ---------------------------------------------------
# Must be on PATH. Install from https://odin-lang.org (latest monthly release).
find_program(ODIN_EXECUTABLE odin REQUIRED)
message(STATUS "Odin compiler: ${ODIN_EXECUTABLE}")

# --- pick the right Odin target for this ABI ----------------------------------
# We only ship arm64-v8a for now (modern phones). See gradle.properties.
if(ANDROID)
    if(ANDROID_ABI STREQUAL "arm64-v8a")
        set(ODIN_TARGET linux_arm64)
    else()
        message(FATAL_ERROR
            "This experiment branch only builds arm64-v8a.\n"
            "Current ABI is '${ANDROID_ABI}'.\n"
            "Change aurora.abiFilters in gradle.properties if you need more.")
    endif()
    set(ODIN_SUBTARGET_ARGS "-subtarget:android")
else()
    # Desktop / host builds (for clangd, unit tests, etc.)
    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
        set(ODIN_TARGET windows_amd64)   # change if you develop on Linux/macOS
    else()
        set(ODIN_TARGET windows_386)
    endif()
    set(ODIN_SUBTARGET_ARGS "")
endif()

# --- output locations ---------------------------------------------------------
set(ODIN_OBJ_DIR       "${CMAKE_CURRENT_BINARY_DIR}/odin_objs")
set(ODIN_OUTPUT_PREFIX "${ODIN_OBJ_DIR}/wayer_core_odin")
set(ODIN_ARCHIVE       "${CMAKE_CURRENT_BINARY_DIR}/libwayer_core_odin.a")

# --- discover every .odin file under native/ ----------------------------------
# CONFIGURE_DEPENDS = CMake re-runs the glob when files appear/disappear,
# so you can add new .odin files without touching this CMakeLists.
file(GLOB_RECURSE ODIN_SRC CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/*.odin"
)

list(LENGTH ODIN_SRC _odin_count)
message(STATUS "Odin sources found: ${_odin_count}")

# --- find llvm-ar (host-aware) ------------------------------------------------
# The NDK ships llvm-ar for every host OS. Older code hard-coded the Windows
# path; that broke Linux/macOS builds. We detect the host tag instead.
if(ANDROID AND DEFINED CMAKE_ANDROID_NDK)
    # Host tag examples: windows-x86_64, linux-x86_64, darwin-x86_64, darwin-arm64
    if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
        set(_NDK_HOST_TAG "windows-x86_64")
        set(_AR_NAME "llvm-ar.exe")
    elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
        if(CMAKE_HOST_SYSTEM_PROCESSOR MATCHES "arm64|aarch64")
            set(_NDK_HOST_TAG "darwin-arm64")
        else()
            set(_NDK_HOST_TAG "darwin-x86_64")
        endif()
        set(_AR_NAME "llvm-ar")
    else()
        # Linux and everything else
        set(_NDK_HOST_TAG "linux-x86_64")
        set(_AR_NAME "llvm-ar")
    endif()

    set(LLVM_AR
        "${CMAKE_ANDROID_NDK}/toolchains/llvm/prebuilt/${_NDK_HOST_TAG}/bin/${_AR_NAME}"
    )
    if(NOT EXISTS "${LLVM_AR}")
        # Fallback: let CMake search the PATH
        message(WARNING "NDK llvm-ar not at expected path: ${LLVM_AR}")
        find_program(LLVM_AR NAMES llvm-ar llvm-ar.exe REQUIRED)
    endif()
else()
    find_program(LLVM_AR NAMES llvm-ar llvm-ar.exe REQUIRED)
endif()
message(STATUS "llvm-ar: ${LLVM_AR}")

# --- custom command that actually runs Odin -----------------------------------
set(ODIN_BUILD_SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/odin/build_odin.cmake")

add_custom_command(
    OUTPUT "${ODIN_ARCHIVE}"
    COMMAND "${CMAKE_COMMAND}"
        "-DODIN_EXECUTABLE=${ODIN_EXECUTABLE}"
        "-DANDROID_NDK_ROOT=${CMAKE_ANDROID_NDK}"
        "-DODIN_SOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}/odin"
        "-DODIN_NATIVE_ROOT=${CMAKE_CURRENT_SOURCE_DIR}"
        "-DODIN_OUTPUT_PREFIX=${ODIN_OUTPUT_PREFIX}"
        "-DODIN_ARCHIVE=${ODIN_ARCHIVE}"
        "-DODIN_TARGET=${ODIN_TARGET}"
        "-DODIN_SUBTARGET_ARGS=${ODIN_SUBTARGET_ARGS}"
        "-DLLVM_AR=${LLVM_AR}"
        -P "${ODIN_BUILD_SCRIPT}"
    DEPENDS ${ODIN_SRC} "${ODIN_BUILD_SCRIPT}"
    COMMENT "Building Odin package (${ODIN_TARGET}${ODIN_SUBTARGET_ARGS})"
    VERBATIM
)

add_custom_target(wayer_core_odin_gen
    DEPENDS "${ODIN_ARCHIVE}"
)

# Imported static library so other targets can link it normally.
add_library(wayer_core_odin STATIC IMPORTED GLOBAL)
set_target_properties(wayer_core_odin PROPERTIES
    IMPORTED_LOCATION "${ODIN_ARCHIVE}"
)

# =============================================================================
# JNI shared library (the only thing Android loads)
# =============================================================================
add_subdirectory(jni)

# Convenience alias used by older docs / scripts
add_library(wayer_native_modules INTERFACE)
target_link_libraries(wayer_native_modules INTERFACE
    wayer_core
    wayer_storage
    wayer_documents
    wayer_transfer
    wayer_media
    wayer_preview
    wayer_file_system
)