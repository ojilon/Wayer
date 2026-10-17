
if(NOT DEFINED ODIN_EXECUTABLE
   OR NOT DEFINED ODIN_SOURCE_DIR
   OR NOT DEFINED ODIN_OUTPUT_PREFIX
   OR NOT DEFINED ODIN_ARCHIVE
   OR NOT DEFINED LLVM_AR)
    message(FATAL_ERROR "Missing required Odin build arguments")
endif()

#create the directory wheere Odinwrites its object files
get_filename_component(
    ODIN_OUTPUT_DIR
    "${ODIN_OUTPUT_PREFIX}"
    DIRECTORY
)

file(MAKE_DIRECTORY "${ODIN_OUTPUT_DIR}")

# Remove stale objects before compiling.
file(GLOB old_objects "${ODIN_OUTPUT_PREFIX}-*.o")
if(old_objects)
    file(REMOVE ${old_objects})
endif()

execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env
        "ODIN_ANDROID_NDK=${ANDROID_NDK_ROOT}"
        "${ODIN_EXECUTABLE}" build "${ODIN_SOURCE_DIR}"
        -build-mode:obj
        -target:${ODIN_TARGET}
        ${ODIN_SUBTARGET_ARGS}
        -reloc-mode:pic
        -no-entry-point
        "-out:${ODIN_OUTPUT_PREFIX}"
    WORKING_DIRECTORY "${ODIN_SOURCE_DIR}"
    RESULT_VARIABLE odin_result
    OUTPUT_VARIABLE odin_stdout
    ERROR_VARIABLE odin_stderr
)
message(STATUS "Odin stdout: ${odin_stdout}")
message(STATUS "Odin stderr: ${odin_stderr}")

message(STATUS "Odin executable: ${ODIN_EXECUTABLE}")
message(STATUS "Odin source: ${ODIN_SOURCE_DIR}")
message(STATUS "Android NDK: ${ANDROID_NDK_ROOT}")
message(STATUS "NDK exists: ${ANDROID_NDK_ROOT}")
message(STATUS "Odin output: ${ODIN_OUTPUT_PREFIX}")

if(NOT odin_result EQUAL 0)
    message(FATAL_ERROR "Odin compilation failed: ${odin_result}")
endif()

# Discover objects after Odin has generated them.
file(GLOB odin_objects "${ODIN_OUTPUT_PREFIX}-*.o")

if(NOT odin_objects)
    message(FATAL_ERROR "Odin generated no object files")
endif()

# Recreate the archive so removed objects cannot remain in it.
file(REMOVE "${ODIN_ARCHIVE}")

execute_process(
    COMMAND "${LLVM_AR}" rcs "${ODIN_ARCHIVE}" ${odin_objects}
    RESULT_VARIABLE archive_result
)

if(NOT archive_result EQUAL 0)
    message(FATAL_ERROR "Odin archive creation failed: ${archive_result}")
endif()

message(STATUS "Created Odin archive: ${ODIN_ARCHIVE}")
