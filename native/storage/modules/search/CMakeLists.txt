# wayer_storage_search — file name/content search helpers
# Until sources move here, this is an INTERFACE target (symbols live in wayer_storage).

add_library(wayer_storage_search INTERFACE)

target_include_directories(wayer_storage_search
    INTERFACE
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)

# When migrating file_search.cpp:
# add_library(wayer_storage_search STATIC src/file_search.cpp)
# target_link_libraries(wayer_storage_search PUBLIC wayer_core)
# target_link_libraries(wayer_storage PRIVATE wayer_storage_search) from parent
