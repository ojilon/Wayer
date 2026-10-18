# =============================================================================
# CompilerFlags.cmake — shared warning / safety flags
#
# We attach these to most of our own targets via the INTERFACE library
# "project_warnings". Third-party code (sqlite) deliberately does NOT use them.
#
# Note: $<COMPILE_LANGUAGE:CXX> is only used on compile OPTIONS (allowed).
# It must NOT be used on target_compile_features (CMake rejects that).
# =============================================================================

cmake_minimum_required(VERSION 3.22.1)

option(WAYER_ENABLE_ANALYZER
    "Enable GCC -fanalyzer (slow and noisy on C++)" OFF)
option(WAYER_WARNINGS_AS_ERRORS
    "Treat warnings as errors (nice for CI, noisy for day-to-day work)" OFF)

if(NOT TARGET project_warnings)
    add_library(project_warnings INTERFACE)

    # C++23 for C++ TUs. Plain form only — no $<COMPILE_LANGUAGE:...> here.
    # C files that link this target simply ignore the C++ feature.
    target_compile_features(project_warnings INTERFACE cxx_std_23)

    # -----------------------------------------------------------------------
    # GCC
    # -----------------------------------------------------------------------
    if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        target_compile_options(project_warnings INTERFACE
            -Wall
            -Wextra
            -Wpedantic
            -Wshadow
            -Wcast-align
            -Wunused
            -Wconversion
            -Wsign-conversion
            -Wnull-dereference
            -Wdouble-promotion
            -Wformat=2
            # C++-only options (generator expression is legal on compile_options):
            $<$<COMPILE_LANGUAGE:CXX>:-Wnon-virtual-dtor>
            $<$<COMPILE_LANGUAGE:CXX>:-Woverloaded-virtual>
        )
        if(WAYER_ENABLE_ANALYZER)
            target_compile_options(project_warnings INTERFACE -fanalyzer)
        endif()
    endif()

    # -----------------------------------------------------------------------
    # Clang (what the Android NDK uses)
    # -----------------------------------------------------------------------
    if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        target_compile_options(project_warnings INTERFACE
            -Wall
            -Wextra
            -Wpedantic
            -Wshadow
            -Wcast-align
            -Wconversion
            -Wsign-conversion
            -Wnull-dereference
            -Wdouble-promotion
            -Wformat=2
            # C++-only:
            $<$<COMPILE_LANGUAGE:CXX>:-Wnon-virtual-dtor>
            $<$<COMPILE_LANGUAGE:CXX>:-Woverloaded-virtual>
        )
    endif()

    # -----------------------------------------------------------------------
    # Hardening flags shared by GCC and Clang
    # -----------------------------------------------------------------------
    if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
        target_compile_options(project_warnings INTERFACE
            -fstack-protector-strong
            -fvisibility=hidden
            $<$<CONFIG:Debug>:-fno-omit-frame-pointer>
        )
        # _FORTIFY_SOURCE needs optimisation; skip it in Debug (-O0).
        target_compile_definitions(project_warnings INTERFACE
            $<$<NOT:$<CONFIG:Debug>>:_FORTIFY_SOURCE=2>
        )
        if(WAYER_WARNINGS_AS_ERRORS)
            target_compile_options(project_warnings INTERFACE -Werror)
        endif()
    endif()

endif()