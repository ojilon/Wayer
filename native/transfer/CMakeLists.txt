# wayer_transfer — protocol helpers, listener hooks (no full Java NetworkManager replacement)

add_library(wayer_transfer STATIC
    src/transfer_engine.cpp
    src/transfer_placeholder.cpp
)

target_include_directories(wayer_transfer
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(wayer_transfer
    PUBLIC
        wayer_core
        wayer_storage
    PRIVATE
        project_warnings
)

target_compile_features(wayer_transfer PUBLIC cxx_std_23)
