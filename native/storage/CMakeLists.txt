# wayer_storage — local FS, app cache files, index (no JNI)

# Optional submodules (search / cleaner / organizer) — may be INTERFACE until split
add_subdirectory(modules/search)
add_subdirectory(modules/cleaner)
add_subdirectory(modules/organizer)

add_library(wayer_storage STATIC
    # ----- LEGACY sources (current flat layout) — remove as files move to src/ -----
    analyse_storage_space.cpp
    large_files.cpp
    list_files.cpp
    file_search.cpp
    duplicate_finder.cpp
    file_organizer.cpp
    storage_cache.cpp
    # ----- After migration, prefer only: -----
    # src/analyse_storage_space.cpp
    # src/list_files.cpp
    # ...
    src/storage_placeholder.cpp
)

target_include_directories(wayer_storage
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
        # Legacy: allows #include "storage/foo.hpp" from parent-relative includes
        ${CMAKE_CURRENT_SOURCE_DIR}/..
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
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
