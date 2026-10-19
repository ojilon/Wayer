# =============================================================================
# storage/CMakeLists.txt — C++ side of the storage module
#
# Parallel Odin files live in src/*.odin (walker, extension_map, stats_json,
# analyse_storage_space, safety). Those are compiled by the top-level Odin
# step in native/CMakeLists.txt — you do NOT list them here.
#
# When a piece is fully rewritten in Odin and no longer needed from C++,
# just delete the corresponding .cpp from the list below.
# =============================================================================

# Optional submodules (search / cleaner / organizer)
add_subdirectory(modules/search)
add_subdirectory(modules/cleaner)
add_subdirectory(modules/organizer)

add_library(wayer_storage STATIC
    src/analyse_storage_space.cpp
    src/dir_walk_android.c
    src/extension_map.cpp
    src/index_c.c
    src/list_files.cpp
    src/safety.cpp
    src/stats_db.cpp
    src/stats_json.cpp
    src/storage_cache.cpp
    src/storage_placeholder.cpp
    src/walker.cpp
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
        wayer_json
        wayer_sqlite3
        project_warnings
)

target_compile_features(wayer_storage PUBLIC cxx_std_23)