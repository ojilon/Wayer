# wayer_storage — local FS, app cache files, index (no JNI)

# Optional submodules (search / cleaner / organizer) — may be INTERFACE until split
add_subdirectory(modules/search)
add_subdirectory(modules/cleaner)
add_subdirectory(modules/organizer)

add_library(wayer_storage STATIC
    src/analyse_storage_space.cpp
    src/list_files.cpp
    src/storage_cache.cpp
    src/storage_placeholder.cpp
)

target_include_directories(wayer_storage
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(wayer_storage
    PUBLIC
        wayer_core
        wayer_storage_search
        wayer_storage_cleaner
        wayer_storage_organizer
    PRIVATE
        project_warnings
)

target_compile_features(wayer_storage PUBLIC cxx_std_23)
