# libwayer_engine.so — sole JNI boundary
add_library(wayer_engine SHARED wayer_engine.cpp)

find_library(log-lib log)

# No include dirs needed: every module exposes its public headers via
# PUBLIC target_include_directories, propagated through target_link_libraries.
# (Do NOT re-add native/ or module roots here — <wayer/...> must resolve
# through the module targets to keep the dependency graph honest.)

target_link_libraries(wayer_engine
    PRIVATE
        wayer_core
        wayer_storage
        wayer_documents
        wayer_transfer
        wayer_media
        ${log-lib}
        project_warnings
)

target_compile_features(wayer_engine PUBLIC cxx_std_23)
