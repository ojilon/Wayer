# =============================================================================
# build_odin.cmake — helper script run by the custom command in CMakeLists.txt
#
# This is NOT a normal CMakeLists. It is invoked with:
#   cmake -P build_odin.cmake   (plus -D variables from the parent)
#
# What it does, step by step:
#   1. Make sure the output directory exists
#   2. Delete any old .o files from a previous run
#   3. Call the Odin compiler → produces one or more .o files
#   4. Pack those .o files into a static archive (.a) with llvm-ar
#
# All the hard decisions (target, subtarget, paths) are passed in as
# -D variables so this script stays simple.
# =============================================================================

# --- sanity check: every required variable must be set -----------------------
foreach(_var
        ODIN_EXECUTABLE
        ODIN_SOURCE_DIR
        ODIN_OUTPUT_PREFIX
        ODIN_ARCHIVE
        LLVM_AR)
    if(NOT DEFINED ${_var})
        message(FATAL_ERROR "build_odin.cmake: missing required variable ${_var}")
    endif()
endforeach()

# --- 1. create the directory where Odin will write object files --------------
get_filename_component(ODIN_OUTPUT_DIR "${ODIN_OUTPUT_PREFIX}" DIRECTORY)
file(MAKE_DIRECTORY "${ODIN_OUTPUT_DIR}")

# --- 2. remove stale objects from a previous build ---------------------------
# (so a deleted .odin file cannot leave a leftover .o inside the archive)
file(GLOB _old_objects "${ODIN_OUTPUT_PREFIX}-*.o")
if(_old_objects)
    file(REMOVE ${_old_objects})
endif()

# --- 3. run the Odin compiler ------------------------------------------------
# -build-mode:obj   → produce object files, not a final executable/so
# -reloc-mode:pic   → position-independent code (required for Android .so)
# -no-entry-point   → we are a library, not a program with main()
# -target / -subtarget → choose the right Android (or desktop) triple
message(STATUS "-----------------------------------------------------------")
message(STATUS "Odin executable : ${ODIN_EXECUTABLE}")
message(STATUS "Odin source dir : ${ODIN_SOURCE_DIR}")
message(STATUS "Android NDK     : ${ANDROID_NDK_ROOT}")
message(STATUS "Target          : ${ODIN_TARGET} ${ODIN_SUBTARGET_ARGS}")
message(STATUS "Output prefix   : ${ODIN_OUTPUT_PREFIX}")
message(STATUS "-----------------------------------------------------------")

# Build the command as a list so empty SUBTARGET_ARGS does not become "".
set(_odin_cmd
    "${ODIN_EXECUTABLE}" build "${ODIN_SOURCE_DIR}"
    -build-mode:obj
    -target:${ODIN_TARGET}
    -reloc-mode:pic
    -no-entry-point
    "-out:${ODIN_OUTPUT_PREFIX}"
)
# Only append the subtarget flag when it is non-empty.
if(ODIN_SUBTARGET_ARGS)
    list(APPEND _odin_cmd ${ODIN_SUBTARGET_ARGS})
endif()

execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env
        "ODIN_ANDROID_NDK=${ANDROID_NDK_ROOT}"
        ${_odin_cmd}
    WORKING_DIRECTORY "${ODIN_SOURCE_DIR}"
    RESULT_VARIABLE _odin_result
    OUTPUT_VARIABLE _odin_stdout
    ERROR_VARIABLE  _odin_stderr
)

message(STATUS "Odin stdout:\n${_odin_stdout}")
if(_odin_stderr)
    message(STATUS "Odin stderr:\n${_odin_stderr}")
endif()

if(NOT _odin_result EQUAL 0)
    message(FATAL_ERROR
        "Odin compilation failed (exit code ${_odin_result}).\n"
        "Check that 'odin' is the latest monthly release and that the\n"
        "package under ${ODIN_SOURCE_DIR} compiles cleanly.")
endif()

# --- 4. discover the .o files Odin just wrote --------------------------------
file(GLOB _odin_objects "${ODIN_OUTPUT_PREFIX}-*.o")
if(NOT _odin_objects)
    # Some Odin versions emit a single file without the -N suffix.
    file(GLOB _odin_objects "${ODIN_OUTPUT_PREFIX}.o")
endif()
if(NOT _odin_objects)
    message(FATAL_ERROR
        "Odin produced no object files matching\n"
        "  ${ODIN_OUTPUT_PREFIX}-*.o  or  ${ODIN_OUTPUT_PREFIX}.o")
endif()
message(STATUS "Odin objects: ${_odin_objects}")

# --- 5. pack them into a static archive --------------------------------------
# Always delete the old archive first so removed objects cannot linger.
file(REMOVE "${ODIN_ARCHIVE}")

execute_process(
    COMMAND "${LLVM_AR}" rcs "${ODIN_ARCHIVE}" ${_odin_objects}
    RESULT_VARIABLE _ar_result
)
if(NOT _ar_result EQUAL 0)
    message(FATAL_ERROR "llvm-ar failed (exit code ${_ar_result})")
endif()

message(STATUS "Created Odin archive: ${ODIN_ARCHIVE}")