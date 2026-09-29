# libwayer_engine.so — sole JNI boundary

# Prefer migrated path; fall back to legacy root file until moved.
set(WAYER_JNI_SOURCES)
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/wayer_engine.cpp")
    list(APPEND WAYER_JNI_SOURCES wayer_engine.cpp)
elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../wayer_engine.cpp")
    list(APPEND WAYER_JNI_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/../wayer_engine.cpp)
else()
    message(FATAL_ERROR "wayer_engine.cpp not found in jni/ or native/")
endif()

add_library(wayer_engine SHARED ${WAYER_JNI_SOURCES})

find_library(log-lib log)

target_include_directories(wayer_engine
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/../
        ${CMAKE_CURRENT_SOURCE_DIR}/../core/include
        ${CMAKE_CURRENT_SOURCE_DIR}/../storage/include
        ${CMAKE_CURRENT_SOURCE_DIR}/../documents/include
        ${CMAKE_CURRENT_SOURCE_DIR}/../transfer/include
        ${CMAKE_CURRENT_SOURCE_DIR}/../media/include
)

target_link_libraries(wayer_engine
    PRIVATE
        wayer_core
        wayer_storage
        wayer_documents
        wayer_transfer
        wayer_media
        ${log-lib}
        project_warnings
)

target_compile_features(wayer_engine PUBLIC cxx_std_23)
