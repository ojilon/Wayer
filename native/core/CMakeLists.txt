# wayer_core — shared foundation (no domain logic, no JNI)

add_library(wayer_core STATIC
    src/core_placeholder.cpp
    # After migration, add:
    # src/paths.cpp
    # src/logging.cpp
)

target_include_directories(wayer_core
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(wayer_core
    PRIVATE
        project_warnings
)

target_compile_features(wayer_core PUBLIC cxx_std_23)
