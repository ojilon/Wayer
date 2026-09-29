cmake_minimum_required(VERSION 3.22.1)
project("wayer_engine")

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(CompilerFlags)

# ---------------------------------------------------------------------------
# Modular native layout (refactor/native-modules)
# See native/MODULES.md and each module's MIGRATION.md.
# All sources live under their module's include/ + src/; JNI lives in jni/.
# ---------------------------------------------------------------------------

add_subdirectory(core)
add_subdirectory(storage)
add_subdirectory(documents)
add_subdirectory(transfer)
add_subdirectory(media)
add_subdirectory(jni)

# Optional: keep a convenience alias matching older docs
add_library(wayer_native_modules INTERFACE)
target_link_libraries(wayer_native_modules INTERFACE
    wayer_core
    wayer_storage
    wayer_documents
    wayer_transfer
    wayer_media
)
