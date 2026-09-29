# wayer_storage_organizer — plan/apply file organization
add_library(wayer_storage_organizer STATIC
    src/file_organizer.cpp
)

# Needs parent storage/include for header-only walker/safety/extension_map.
# (Include dir only — no link to wayer_storage to keep the graph acyclic.)
target_include_directories(wayer_storage_organizer
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
        ${CMAKE_CURRENT_SOURCE_DIR}/../../include
)

target_link_libraries(wayer_storage_organizer
    PUBLIC
        wayer_core
    PRIVATE
        project_warnings
)

target_compile_features(wayer_storage_organizer PUBLIC cxx_std_23)
