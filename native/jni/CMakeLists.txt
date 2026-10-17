# libwayer_engine.so — sole JNI boundary (C wrapper over Odin core).
add_library(wayer_engine SHARED wayer_engine.c)

# Android provides liblog; desktop configures (clangd compile DB) don't.
find_library(log-lib log)

target_link_libraries(wayer_engine
    PRIVATE
        wayer_core_odin
        wayer_shim
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

# Force C language for this TU.
set_target_properties(wayer_engine PROPERTIES LANGUAGE C)
target_compile_features(wayer_engine PUBLIC c_std_11)

add_dependencies(wayer_engine wayer_core_odin_gen)