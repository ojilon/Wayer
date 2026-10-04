# wayer_preview — read-only document/text preview for the in-app viewer (no JNI)

add_library(wayer_preview STATIC
    src/preview.cpp
)

target_include_directories(wayer_preview
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(wayer_preview
    PUBLIC
        wayer_core
    PRIVATE
        project_warnings
)

target_compile_features(wayer_preview PUBLIC cxx_std_23)
