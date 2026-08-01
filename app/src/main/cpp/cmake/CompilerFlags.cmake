# ============================================================================
# CompilerFlags.cmake - Reusable Modern C++ Strict Safety Configuration
# ============================================================================
cmake_minimum_required(VERSION 3.22.1)

if(NOT TARGET project_warnings)
    add_library(project_warnings INTERFACE)

    # 1. Enforce Modern C++ Standards
    target_compile_features(project_warnings INTERFACE cxx_std_23)
    set(CMAKE_CXX_STANDARD_REQUIRED ON INTERFACE)
    set(CMAKE_CXX_EXTENSIONS OFF INTERFACE) # Disallow compiler-specific extensions (pure standard C++)

    # 2. Strict Error and Warning Flags for GCC
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
            
            # --- GCC 15+ Advanced Safety Analytics ---
            -fanalyzer       # Turns on GCC's deep static analyzer (catches complex lifetime/null issues)
        )
    endif()

    # 3. Optional: Treat Warnings as Errors in Debug Mode
    # This prevents you from ignoring warnings while actively writing code.
    if(CMAKE_BUILD_TYPE STREQUAL "Debug" OR NOT CMAKE_BUILD_TYPE)
        if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
            target_compile_options(project_warnings INTERFACE -Werror)
        endif()
    endif()

endif()
