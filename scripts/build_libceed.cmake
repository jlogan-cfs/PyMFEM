# CMake script to build libCEED dependency
# Called with: cmake -P build_libceed.cmake
# Variables expected:
# - LIBCEED_SOURCE_DIR: Path to libCEED source directory
# - LIBCEED_INSTALL_DIR: Installation prefix
# - CMAKE_BUILD_PARALLEL_LEVEL: Number of parallel jobs
# - LIB_EXTENSION: Library extension (so/dylib)
# - ENABLE_CUDA: Whether CUDA is enabled (optional)
# - CUDA_PREFIX: CUDA installation path (optional)

if(NOT DEFINED LIBCEED_SOURCE_DIR OR NOT DEFINED LIBCEED_INSTALL_DIR)
    message(FATAL_ERROR "Required variables not set: LIBCEED_SOURCE_DIR, LIBCEED_INSTALL_DIR")
endif()

set(libceed_dir ${LIBCEED_SOURCE_DIR})
set(libceed_install_dir ${LIBCEED_INSTALL_DIR})

# Check if libCEED is already built
if(EXISTS ${libceed_install_dir}/lib/libceed.a OR EXISTS ${libceed_install_dir}/lib/libceed.${LIB_EXTENSION})
    message(STATUS "libCEED already built at ${libceed_install_dir}")
    return()
endif()

message(STATUS "Building libCEED at ${libceed_dir}")
message(STATUS "Installing libCEED at ${libceed_install_dir}")

if(NOT EXISTS ${libceed_dir})
    message(FATAL_ERROR "libCEED source not found at ${libceed_dir}")
endif()

# Clean any previous build
execute_process(
    COMMAND make clean
    WORKING_DIRECTORY ${libceed_dir}
    RESULT_VARIABLE clean_result
    ERROR_QUIET
)

# Configure libCEED with CUDA if enabled
if(ENABLE_CUDA)
    execute_process(
        COMMAND make configure CUDA_DIR=${CUDA_PREFIX}
        WORKING_DIRECTORY ${libceed_dir}
        RESULT_VARIABLE config_result
    )
    
    if(NOT config_result EQUAL "0")
        message(FATAL_ERROR "Failed to configure libCEED with CUDA")
    endif()
endif()

# Build libCEED
if(CMAKE_BUILD_PARALLEL_LEVEL)
    set(make_jobs "-j${CMAKE_BUILD_PARALLEL_LEVEL}")
else()
    set(make_jobs "-j4")  # Default to 4 parallel jobs
endif()

execute_process(
    COMMAND make ${make_jobs}
    WORKING_DIRECTORY ${libceed_dir}
    RESULT_VARIABLE build_result
)

if(NOT build_result EQUAL "0")
    message(FATAL_ERROR "Failed to build libCEED")
endif()

# Install libCEED
execute_process(
    COMMAND make install prefix=${libceed_install_dir}
    WORKING_DIRECTORY ${libceed_dir}
    RESULT_VARIABLE install_result
)

if(install_result EQUAL "0")
    message(STATUS "Successfully built and installed libCEED")
else()
    message(FATAL_ERROR "Failed to install libCEED")
endif()

message(STATUS "Built libCEED")