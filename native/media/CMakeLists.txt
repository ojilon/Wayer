# wayer_media — placeholder for audio/video metadata / helpers (future)

add_library(wayer_media STATIC
    src/media_placeholder.cpp
)

target_include_directories(wayer_media
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(wayer_media
    PUBLIC
        wayer_core
    PRIVATE
        project_warnings
)

target_compile_features(wayer_media PUBLIC cxx_std_23)
