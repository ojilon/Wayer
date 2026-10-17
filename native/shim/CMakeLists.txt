# wayer_shim — C++ shim layer exposing extern "C" wayer_* symbols for the Odin router.
# Each function is a one-line wrapper over the existing C++ domain module.
add_library(wayer_shim STATIC wayer_shim.cpp)

target_link_libraries(wayer_shim
    PUBLIC
        wayer_core
        wayer_storage
        wayer_documents
        wayer_transfer
        wayer_preview
    PRIVATE
        project_warnings
)

target_compile_features(wayer_shim PUBLIC cxx_std_23)
