cmake_minimum_required(VERSION 3.22.1)
project("wayer_engine")

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
