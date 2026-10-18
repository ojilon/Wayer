# =============================================================================
# jni/CMakeLists.txt — the only shared library Android actually loads
#
# wayer_engine.c is a tiny C trampoline:
#   Java  →  JNI  →  wayer_route_action()  (exported by the Odin archive)
#
# Everything else (C++ modules + Odin objects) is linked in statically.
# =============================================================================

add_library(wayer_engine SHARED wayer_engine.c)

# Android provides liblog; desktop / clangd configures may not.
find_library(log-lib log)

target_link_libraries(wayer_engine
    PRIVATE
        wayer_core_odin      # Odin router + ported storage pieces
        wayer_shim           # C++ functions still called from Odin
        wayer_storage
        wayer_documents
        wayer_transfer
        wayer_media
        wayer_preview
        project_warnings
)

if(log-lib)
    target_link_libraries(wayer_engine PRIVATE ${log-lib})
endif()

# This translation unit is pure C (no C++).
set_target_properties(wayer_engine PROPERTIES LANGUAGE C)
target_compile_features(wayer_engine PUBLIC c_std_11)

# Make sure the Odin archive is built before we try to link it.
add_dependencies(wayer_engine wayer_core_odin_gen)