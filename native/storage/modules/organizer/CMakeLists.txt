# wayer_storage_organizer — plan/apply file organization

add_library(wayer_storage_organizer INTERFACE)

target_include_directories(wayer_storage_organizer
    INTERFACE
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)
