# wayer_transfer — protocol helpers, listener hooks (no full Java NetworkManager replacement)

add_library(wayer_transfer STATIC
    # LEGACY:
    transfer_engine.cpp
    src/transfer_placeholder.cpp
)

target_include_directories(wayer_transfer
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
        ${CMAKE_CURRENT_SOURCE_DIR}/..
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(wayer_transfer
    PUBLIC
        wayer_core
        wayer_storage
    PRIVATE
        project_warnings
)

target_compile_features(wayer_transfer PUBLIC cxx_std_23)
