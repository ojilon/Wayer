# wayer_documents — document filter / future render hooks (no JNI)

add_library(wayer_documents STATIC
    # LEGACY flat path:
    document_engine.cpp
    src/documents_placeholder.cpp
)

target_include_directories(wayer_documents
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
        ${CMAKE_CURRENT_SOURCE_DIR}/..
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(wayer_documents
    PUBLIC
        wayer_core
        wayer_storage
    PRIVATE
        project_warnings
)

target_compile_features(wayer_documents PUBLIC cxx_std_23)
