# CMake script to build GSLIB dependency
# Called with: cmake -P build_gslib.cmake
# Variables expected:
# - GSLIB_SOURCE_DIR: Path to GSLIB source directory
# - GSLIB_INSTALL_DIR_SER: Installation prefix for serial build
# - GSLIB_INSTALL_DIR_PAR: Installation prefix for parallel build (optional)
# - CC_COMMAND: C compiler command
# - MPICC_COMMAND: MPI C compiler command (for parallel build)
# - BUILD_SERIAL: Whether to build serial version (optional, defaults to ON)
# - BUILD_PARALLEL: Whether to build parallel version (optional, defaults to OFF)

if(NOT DEFINED GSLIB_SOURCE_DIR)
    message(FATAL_ERROR "Required variable not set: GSLIB_SOURCE_DIR")
endif()

if(NOT DEFINED CC_COMMAND AND BUILD_SERIAL)
    message(FATAL_ERROR "Required variable not set: CC_COMMAND (needed for serial build)")
endif()

if(NOT DEFINED MPICC_COMMAND AND BUILD_PARALLEL)
    message(FATAL_ERROR "Required variable not set: MPICC_COMMAND (needed for parallel build)")
endif()

set(gslib_dir ${GSLIB_SOURCE_DIR})

# Set default values
if(NOT DEFINED BUILD_SERIAL)
    set(BUILD_SERIAL ON)
endif()

if(NOT DEFINED BUILD_PARALLEL)
    set(BUILD_PARALLEL OFF)
endif()

message(STATUS "Building GSLIB at ${gslib_dir}")

if(NOT EXISTS ${gslib_dir})
    message(FATAL_ERROR "GSLIB source not found at ${gslib_dir}")
endif()

# Clean any previous build
execute_process(
    COMMAND make clean
    WORKING_DIRECTORY ${gslib_dir}
    RESULT_VARIABLE clean_result
    ERROR_QUIET
)

# Build serial version if requested
if(BUILD_SERIAL AND DEFINED GSLIB_INSTALL_DIR_SER)
    message(STATUS "Building GSLIB serial version")
    message(STATUS "Installing GSLIB serial to: ${GSLIB_INSTALL_DIR_SER}")
    
    # Build serial gslib
    execute_process(
        COMMAND make CC=${CC_COMMAND} MPI=0 "CFLAGS=$ENV{CFLAGS}"
        WORKING_DIRECTORY ${gslib_dir}
        RESULT_VARIABLE build_result
    )
    
    if(NOT build_result EQUAL "0")
        message(FATAL_ERROR "Failed to build GSLIB (serial)")
    endif()
    
    # Install serial gslib
    execute_process(
        COMMAND make MPI=0 DESTDIR=${GSLIB_INSTALL_DIR_SER}
        WORKING_DIRECTORY ${gslib_dir}
        RESULT_VARIABLE install_result
    )
    
    if(NOT install_result EQUAL "0")
        message(FATAL_ERROR "Failed to install GSLIB (serial)")
    endif()
    
    message(STATUS "Successfully built and installed GSLIB (serial)")
    
    # Clean for parallel build if needed
    if(BUILD_PARALLEL AND DEFINED GSLIB_INSTALL_DIR_PAR)
        execute_process(
            COMMAND make clean
            WORKING_DIRECTORY ${gslib_dir}
            RESULT_VARIABLE clean_result
            ERROR_QUIET
        )
    endif()
endif()

# Build parallel version if requested
if(BUILD_PARALLEL AND DEFINED GSLIB_INSTALL_DIR_PAR AND DEFINED MPICC_COMMAND)
    message(STATUS "Building GSLIB parallel version")
    message(STATUS "Installing GSLIB parallel to: ${GSLIB_INSTALL_DIR_PAR}")
    
    # Build parallel gslib
    execute_process(
        COMMAND make CC=${MPICC_COMMAND} "CFLAGS=$ENV{CFLAGS}"
        WORKING_DIRECTORY ${gslib_dir}
        RESULT_VARIABLE build_result
    )
    
    if(NOT build_result EQUAL "0")
        message(FATAL_ERROR "Failed to build GSLIB (parallel)")
    endif()
    
    # Install parallel gslib
    execute_process(
        COMMAND make DESTDIR=${GSLIB_INSTALL_DIR_PAR}
        WORKING_DIRECTORY ${gslib_dir}
        RESULT_VARIABLE install_result
    )
    
    if(NOT install_result EQUAL "0")
        message(FATAL_ERROR "Failed to install GSLIB (parallel)")
    endif()
    
    message(STATUS "Successfully built and installed GSLIB (parallel)")
endif()

message(STATUS "Built GSLIB")