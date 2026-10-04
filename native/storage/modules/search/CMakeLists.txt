# wayer_storage_search — file name/content search helpers
add_library(wayer_storage_search STATIC
    src/file_search.cpp
)

target_include_directories(wayer_storage_search
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(wayer_storage_search
    PUBLIC
        wayer_core
    PRIVATE
        project_warnings
)

target_compile_features(wayer_storage_search PUBLIC cxx_std_23)
