# wayer_documents — document filter / future render hooks (no JNI)

add_library(wayer_file_system STATIC
    src/android_fs.c
)

target_include_directories(wayer_file_system
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(wayer_file_system
    PUBLIC
        wayer_core
        wayer_storage
    PRIVATE
        project_warnings
)

target_compile_features(wayer_file_system PUBLIC cxx_std_23)
