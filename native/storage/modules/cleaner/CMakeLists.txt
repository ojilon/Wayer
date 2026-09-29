# wayer_storage_cleaner — duplicates, large files, future junk cleanup

add_library(wayer_storage_cleaner INTERFACE)

target_include_directories(wayer_storage_cleaner
    INTERFACE
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)
