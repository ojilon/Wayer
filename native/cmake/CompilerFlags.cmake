# ============================================================================
# CompilerFlags.cmake - Reusable Modern C++ Strict Safety Configuration
# ============================================================================
cmake_minimum_required(VERSION 3.22.1)

option(WAYER_ENABLE_ANALYZER "Enable GCC -fanalyzer (slow, noisy on C++)" OFF)
option(WAYER_WARNINGS_AS_ERRORS "Treat warnings as errors (enable in CI/release, not by default)" OFF)

if(NOT TARGET project_warnings)
    add_library(project_warnings INTERFACE)

    # 1. Enforce Modern C++ Standards
    # NOTE: CXX_EXTENSIONS is set project-wide (set(CMAKE_CXX_EXTENSIONS OFF)
    # in the top-level CMakeLists); set() has no INTERFACE mode.
    target_compile_features(project_warnings INTERFACE cxx_std_23)

    # 2a. Strict warning flags for GCC (unchanged set)
    if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        target_compile_options(project_warnings INTERFACE
            -Wall
            -Wextra          # Reasonable and standard additional warnings
            -Wpedantic       # Warn if you violate pure ISO C++
            -Wshadow         # Warn if a local variable shadows another variable
            -Wnon-virtual-dtor # Warn if a class has virtual functions but no virtual destructor
            -Wcast-align     # Warn about pointer casts that increase alignment
            -Wunused         # Warn about any unused variables/functions
            -Woverloaded-virtual # Warn if you accidentally overload instead of override
            -Wconversion     # Warn about implicit type conversions that may lose data
            -Wsign-conversion # Warn about implicit sign conversions
            -Wnull-dereference # Warn if a null dereference is detected
            -Wdouble-promotion # Warn if float is implicitly promoted to double
            -Wformat=2       # Security checks on printf/scanf style functions
        )
        # GCC-only deep static analyzer: opt-in, it is slow and noisy on C++.
        if(WAYER_ENABLE_ANALYZER)
            target_compile_options(project_warnings INTERFACE -fanalyzer)
        endif()
    endif()

    # 2b. Strict warning flags for Clang / AppleClang (this is what the NDK uses)
    if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        target_compile_options(project_warnings INTERFACE
            -Wall
            -Wextra
            -Wpedantic
            -Wshadow
            -Wnon-virtual-dtor
            -Wcast-align
            -Woverloaded-virtual
            -Wconversion
            -Wsign-conversion
            -Wnull-dereference
            -Wdouble-promotion
            -Wformat=2
        )
    endif()

    # 2c. Hardening for GCC/Clang (MSVC is not used by this project).
    # JNI entry points stay exported via JNIEXPORT despite -fvisibility=hidden.
    if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
        target_compile_options(project_warnings INTERFACE
            -fstack-protector-strong
            -fvisibility=hidden
            $<$<CONFIG:Debug>:-fno-omit-frame-pointer>
        )
        # _FORTIFY_SOURCE requires optimization; Debug (-O0) is excluded.
        target_compile_definitions(project_warnings INTERFACE
            $<$<NOT:$<CONFIG:Debug>>:_FORTIFY_SOURCE=2>
        )
        if(WAYER_WARNINGS_AS_ERRORS)
            target_compile_options(project_warnings INTERFACE -Werror)
        endif()
    endif()

endif()
