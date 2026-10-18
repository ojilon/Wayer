cmake_minimum_required(VERSION 3.22.1)
project(wayer_engine LANGUAGES C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Emit compile_commands.json for clangd (lands in the active build dir;
# under Gradle: app/.cxx/<variant>/<hash>/<abi>/).
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(CompilerFlags)

# ---------------------------------------------------------------------------
# Modular native layout (refactor/native-modules)
# See native/MODULES.md and each module's MIGRATION.md.
# All sources live under their module's include/ + src/; JNI lives in jni/.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Third-party libs (vendored locally, gitignored — see third_party/README.md
# and docs/BRIDGE_PLAN.md Step 0). Targets exist even before any module links
# them, so a missing local install fails fast at configure time, not deep in
# a module build.
# ---------------------------------------------------------------------------
if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/third_party/json/include/nlohmann/json.hpp")
    message(FATAL_ERROR "Missing third_party/json/include/nlohmann/json.hpp (see docs/BRIDGE_PLAN.md Step 0)")
endif()
if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/third_party/sqlite/sqlite3.c")
    message(FATAL_ERROR "Missing third_party/sqlite/sqlite3.c (see docs/BRIDGE_PLAN.md Step 0)")
endif()

# Header-only: include dir only, nothing to compile.
add_library(wayer_json INTERFACE)
target_include_directories(wayer_json INTERFACE
    ${CMAKE_CURRENT_SOURCE_DIR}/third_party/json/include
)

# Amalgamation: compiled once into a static lib.
# Deliberately NOT linked to project_warnings — the 9 MB C file would drown
# us in third-party warnings. Our flags stay on our code.
add_library(wayer_sqlite3 STATIC
    third_party/sqlite/sqlite3.c
)
target_include_directories(wayer_sqlite3 PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/third_party/sqlite
)

add_subdirectory(core)
add_subdirectory(storage)
add_subdirectory(documents)
add_subdirectory(transfer)
add_subdirectory(media)
add_subdirectory(preview)
add_subdirectory(shim)

# ── Odin core module → static lib (multiple .obj files), linked into wayer_engine ──
find_program(ODIN_EXECUTABLE odin REQUIRED)

if(ANDROID)
    if(ANDROID_ABI STREQUAL "arm64-v8a")
        set(ODIN_TARGET linux_arm64)
    elseif(ANDROID_ABI STREQUAL "x86_64")
        set(ODIN_TARGET linux_amd64)
    else()
        message(FATAL_ERROR
            "Unsupported Android ABI for Odin: ${ANDROID_ABI}")
    endif()

    set(ODIN_SUBTARGET_ARGS -subtarget:android)
else()
    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
        set(ODIN_TARGET windows_amd64)
    else()
        set(ODIN_TARGET windows_386)
    endif()

    set(ODIN_SUBTARGET_ARGS)
endif()

set(ODIN_OBJ_DIR "${CMAKE_CURRENT_BINARY_DIR}/odin_objs")
set(ODIN_OUTPUT_PREFIX "${ODIN_OBJ_DIR}/wayer_core_odin")
set(ODIN_ARCHIVE "${CMAKE_CURRENT_BINARY_DIR}/libwayer_core_odin.a")

file(GLOB_RECURSE ODIN_SRC CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/odin/*.odin"
    "${CMAKE_CURRENT_SOURCE_DIR}/core/*.odin"
    "${CMAKE_CURRENT_SOURCE_DIR}/storage/*.odin"
    "${CMAKE_CURRENT_SOURCE_DIR}/documents/*.odin"
    "${CMAKE_CURRENT_SOURCE_DIR}/transfer/*.odin"
    "${CMAKE_CURRENT_SOURCE_DIR}/media/*.odin"
    "${CMAKE_CURRENT_SOURCE_DIR}/preview/*.odin"
    "${CMAKE_CURRENT_SOURCE_DIR}/shim/*.odin"
)

if(ANDROID)
    set(LLVM_AR
        "${CMAKE_ANDROID_NDK}/toolchains/llvm/prebuilt/windows-x86_64/bin/llvm-ar.exe"
    )
else()
    find_program(LLVM_AR NAMES llvm-ar llvm-ar.exe REQUIRED)
endif()

set(ODIN_BUILD_SCRIPT
    "${CMAKE_CURRENT_SOURCE_DIR}/odin/build_odin.cmake"
)

add_custom_command(
    OUTPUT "${ODIN_ARCHIVE}"
    COMMAND "${CMAKE_COMMAND}"
        "-DODIN_EXECUTABLE=${ODIN_EXECUTABLE}"
        "-DANDROID_NDK_ROOT=${CMAKE_ANDROID_NDK}"
        "-DODIN_SOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}/odin"
        "-DODIN_OUTPUT_PREFIX=${ODIN_OUTPUT_PREFIX}"
        "-DODIN_ARCHIVE=${ODIN_ARCHIVE}"
        "-DODIN_TARGET=${ODIN_TARGET}"
        "-DODIN_SUBTARGET_ARGS=${ODIN_SUBTARGET_ARGS}"
        "-DLLVM_AR=${LLVM_AR}"
        -P "${ODIN_BUILD_SCRIPT}"
    DEPENDS ${ODIN_SRC} "${ODIN_BUILD_SCRIPT}"
    COMMENT "Building Odin core (${ODIN_TARGET})"
    VERBATIM
)

add_custom_target(wayer_core_odin_gen
    DEPENDS "${ODIN_ARCHIVE}"
)

add_library(wayer_core_odin STATIC IMPORTED GLOBAL)
set_target_properties(wayer_core_odin PROPERTIES
    IMPORTED_LOCATION "${ODIN_ARCHIVE}"
)


add_subdirectory(jni)

# Optional: keep a convenience alias matching older docs
add_library(wayer_native_modules INTERFACE)
target_link_libraries(wayer_native_modules INTERFACE
    wayer_core
    wayer_storage
    wayer_documents
    wayer_transfer
    wayer_media
    wayer_preview
)
