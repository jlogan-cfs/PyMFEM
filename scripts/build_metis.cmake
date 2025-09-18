# CMake script to build METIS dependency
# Called with: cmake -P build_metis.cmake
# Variables expected:
# - METIS_SOURCE_DIR: Path to METIS source directory
# - METIS_INSTALL_DIR: Installation prefix
# - METIS_CC_COMMAND: C compiler command
# - CMAKE_BUILD_PARALLEL_LEVEL: Number of parallel jobs
# - LIB_EXTENSION: Library extension (so/dylib)

if(NOT DEFINED METIS_SOURCE_DIR OR NOT DEFINED METIS_INSTALL_DIR OR NOT DEFINED METIS_CC_COMMAND)
    message(FATAL_ERROR "Required variables not set: METIS_SOURCE_DIR, METIS_INSTALL_DIR, METIS_CC_COMMAND")
endif()

set(metis_dir ${METIS_SOURCE_DIR})
set(metis_install_dir ${METIS_INSTALL_DIR})

message(STATUS "Building METIS at ${metis_dir}")
message(STATUS "METIS will be installed to: ${metis_install_dir}")

if(NOT EXISTS ${metis_dir})
    message(FATAL_ERROR "METIS source not found at ${metis_dir}")
endif()

# Ensure install directories exist
file(MAKE_DIRECTORY ${metis_install_dir})
file(MAKE_DIRECTORY ${metis_install_dir}/lib)
file(MAKE_DIRECTORY ${metis_install_dir}/include)

# Create build directory  
file(MAKE_DIRECTORY ${metis_dir}/build)

# Configure METIS build (matching setup_legacy.py configuration)
# Force cmake to use Unix Makefiles generator (not Ninja) since METIS expects Makefile
set(ENV{CMAKE_GENERATOR} "Unix Makefiles")

# Extract base compiler command without flags for METIS config
string(REGEX REPLACE " .*" "" BASE_CC_COMMAND "${METIS_CC_COMMAND}")
if(NOT BASE_CC_COMMAND)
    set(BASE_CC_COMMAND "${METIS_CC_COMMAND}")
endif()

message(STATUS "Configuring METIS with: make config shared=1 prefix=${metis_install_dir} cc=${BASE_CC_COMMAND} CMAKE_POLICY_VERSION_MINIMUM=${CMAKE_POLICY_VERSION_MINIMUM}")
execute_process(
    COMMAND make config shared=1 prefix=${metis_install_dir} cc=${BASE_CC_COMMAND} CMAKE_POLICY_VERSION_MINIMUM=${CMAKE_POLICY_VERSION_MINIMUM}
    WORKING_DIRECTORY ${metis_dir}
    RESULT_VARIABLE config_result
    OUTPUT_VARIABLE config_output
    ERROR_VARIABLE config_error
)

message(STATUS "METIS config result: ${config_result}")
if(config_output)
    message(STATUS "METIS config output: ${config_output}")
endif()
if(config_error)
    message(STATUS "METIS config error: ${config_error}")
endif()

# Check if build directory and Makefile were created by config
file(GLOB metis_build_dirs "${metis_dir}/build/*")
if(metis_build_dirs)
    list(GET metis_build_dirs 0 actual_build_dir)
    message(STATUS "METIS build directory created: ${actual_build_dir}")
    
    if(EXISTS "${actual_build_dir}/Makefile")
        message(STATUS "METIS build Makefile exists - config succeeded")
    else()
        message(STATUS "METIS build Makefile MISSING - config failed")
        # List what files are in the build directory
        file(GLOB build_contents "${actual_build_dir}/*")
        message(STATUS "Contents of build directory: ${build_contents}")
    endif()
else()
    message(STATUS "No METIS build directory created - config completely failed")
endif()

if(NOT config_result EQUAL "0")
    message(FATAL_ERROR "Failed to configure METIS")
endif()

# Build METIS
if(CMAKE_BUILD_PARALLEL_LEVEL)
    set(make_jobs "-j${CMAKE_BUILD_PARALLEL_LEVEL}")
else()
    set(make_jobs "-j4")  # Default to 4 parallel jobs
endif()

message(STATUS "Building METIS with: make all ${make_jobs}")
execute_process(
    COMMAND make all ${make_jobs}
    WORKING_DIRECTORY ${metis_dir}
    RESULT_VARIABLE build_result
    OUTPUT_VARIABLE build_output
    ERROR_VARIABLE build_error
)

message(STATUS "METIS build result: ${build_result}")
if(build_output)
    message(STATUS "METIS build output: ${build_output}")
endif()
if(build_error)
    message(STATUS "METIS build error: ${build_error}")
endif()

if(NOT build_result EQUAL "0")
    message(FATAL_ERROR "Failed to build METIS")
endif()

# Install METIS
message(STATUS "Installing METIS with: make install")
execute_process(
    COMMAND make install
    WORKING_DIRECTORY ${metis_dir}
    RESULT_VARIABLE install_result
    OUTPUT_VARIABLE install_output
    ERROR_VARIABLE install_error
)

if(install_error)
    message(STATUS "METIS install error: ${install_error}")
endif()

if(install_result EQUAL "0")
    message(STATUS "Successfully built and installed METIS")
    # Fix library install names on macOS
    if(APPLE)
        execute_process(
            COMMAND install_name_tool -id ${metis_install_dir}/lib/libmetis.${LIB_EXTENSION} ${metis_install_dir}/lib/libmetis.${LIB_EXTENSION}
            RESULT_VARIABLE fix_result
        )
    endif()
else()
    message(FATAL_ERROR "Failed to install METIS")
endif()

message(STATUS "Built METIS")