cmake_minimum_required(VERSION 4.0)

# Project setup
project(PyMFEM LANGUAGES C CXX)

# Set policies for modern CMake behavior
# cmake_policy(SET CMP0148 OLD)  # For FindPythonInterp compatibility

# Find Python and SWIG
find_package(Python REQUIRED COMPONENTS Interpreter Development.Module)
find_package(SWIG REQUIRED)
include(UseSWIG)

# CMake utilities for downloading dependencies
# (Using direct file operations instead of FetchContent to avoid CMake configuration issues)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Set position independent code for all builds to ensure shared library compatibility
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Also set CFLAGS environment variable to ensure -fPIC is used for Makefile-based builds
set(ENV{CFLAGS} "-fPIC $ENV{CFLAGS}")
set(ENV{CXXFLAGS} "-fPIC $ENV{CXXFLAGS}")
message(STATUS "Set global -fPIC flags for shared library compatibility")

# Set parallel build level for make commands
include(ProcessorCount)
ProcessorCount(N)
if(N EQUAL 0)
    set(CMAKE_BUILD_PARALLEL_LEVEL 1)
else()
    math(EXPR CMAKE_BUILD_PARALLEL_LEVEL "${N} - 1")
    if(CMAKE_BUILD_PARALLEL_LEVEL LESS 1)
        set(CMAKE_BUILD_PARALLEL_LEVEL 1)
    endif()
endif()

# Enable verbose output for debugging
set(CMAKE_VERBOSE_MAKEFILE ON)
set(CMAKE_MESSAGE_LOG_LEVEL TRACE)
message(STATUS "PyMFEM: CMake build starting")
message(STATUS "PyMFEM: CMAKE_CXX_COMPILER = ${CMAKE_CXX_COMPILER}")
message(STATUS "PyMFEM: CMAKE_BUILD_TYPE = ${CMAKE_BUILD_TYPE}")
message(STATUS "PyMFEM: Python_EXECUTABLE = ${Python_EXECUTABLE}")
message(STATUS "PyMFEM: Python_VERSION = ${Python_VERSION}")
message(STATUS "PyMFEM: Python_VERSION_MAJOR = ${Python_VERSION_MAJOR}")
message(STATUS "PyMFEM: Python_VERSION_MINOR = ${Python_VERSION_MINOR}")
message(STATUS "PyMFEM: Python_INCLUDE_DIRS = ${Python_INCLUDE_DIRS}")
message(STATUS "PyMFEM: Python_LIBRARIES = ${Python_LIBRARIES}")
message(STATUS "PyMFEM: Python_SOABI = ${Python_SOABI}")
message(VERBOSE "PyMFEM: CMAKE_MESSAGE_LOG_LEVEL = ${CMAKE_MESSAGE_LOG_LEVEL}")
message(VERBOSE "PyMFEM: CMAKE_VERBOSE_MAKEFILE = ${CMAKE_VERBOSE_MAKEFILE}")

# Platform-specific settings
if(APPLE)
    set(CMAKE_MACOSX_RPATH ON)
    # Handle macOS SIP and Python frameworks
    set(CMAKE_INSTALL_RPATH "@loader_path")
    set(LIB_EXTENSION "dylib")
endif()

if(UNIX AND NOT APPLE)
    set(CMAKE_INSTALL_RPATH "$ORIGIN")
    set(LIB_EXTENSION "so")
endif()

# Configuration options from original setup.py
option(BUILD_PARALLEL "Build parallel version" OFF)
option(BUILD_METIS "Build METIS library" OFF)
option(BUILD_HYPRE "Build HYPRE library" OFF)
option(BUILD_HDF5 "Build parallel HDF5 library" OFF)
option(BUILD_LIBCEED "Build libCEED library" OFF)
option(BUILD_GSLIB "Build gslib library" OFF)
option(PYMFEM_REUSE_EXTERNAL
       "Reuse external sources and build artifacts for an incremental local build"
       OFF)
option(ENABLE_CUDA "Enable CUDA support" OFF)

# LAPACK will be auto-detected from system or built from source if ENABLE_LAPACK is ON
option(ENABLE_LAPACK "Enable LAPACK" OFF)

# x86 vectorization option
option(ENABLE_X86_SIMD "Enable x86 SIMD optimizations (SSE4, AVX, AVX2)" OFF)

# Not supported yet
# option(ENABLE_SUITESPARSE "Enable SuiteSparse" OFF)
# option(ENABLE_PUMI "Enable PUMI" OFF)
# option(ENABLE_STRUMPACK "Enable STRUMPACK" OFF)

# Path configurations
# If EXT_PREFIX is empty or not set, use a default location
if(NOT EXT_PREFIX OR EXT_PREFIX STREQUAL "")
    set(EXT_PREFIX ${CMAKE_CURRENT_BINARY_DIR}/external CACHE PATH "External libraries prefix" FORCE)
endif()

# Ensure EXT_PREFIX is absolute
if(NOT IS_ABSOLUTE ${EXT_PREFIX})
    get_filename_component(EXT_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/${EXT_PREFIX}" ABSOLUTE)
endif()

# Find mpi4py include directory if we're doing a parallel build.
# This has to be done in the top level directory to find the uv venv correctly.
if(BUILD_PARALLEL)
    # Find mpi4py include directory
    execute_process(
        COMMAND ${Python_EXECUTABLE} -c "import mpi4py; print(mpi4py.get_include())"
        OUTPUT_VARIABLE MPI4PY_INCLUDE_DIR
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    message(STATUS "PYMFEM: MPI4PY_INCLUDE_DIR = ${MPI4PY_INCLUDE_DIR}")
endif()

set(MFEM_SOURCE ${CMAKE_CURRENT_SOURCE_DIR}/external/mfem CACHE PATH "MFEM source directory")

message(STATUS "PyMFEM: EXT_PREFIX = ${EXT_PREFIX} (absolute)")

# Compiler configurations (can be overridden by environment)
set(CC_COMMAND "cc" CACHE STRING "C compiler command")
set(CXX_COMMAND "c++" CACHE STRING "C++ compiler command") 
set(MPICC_COMMAND "mpicc" CACHE STRING "MPI C compiler command")
set(MPICXX_COMMAND "mpic++" CACHE STRING "MPI C++ compiler command")
set(CUDA_ARCH "" CACHE STRING "CUDA compute capability")

# Update from environment if set
if(DEFINED ENV{CC})
    set(CC_COMMAND $ENV{CC})
endif()
if(DEFINED ENV{CXX})
    set(CXX_COMMAND $ENV{CXX})
endif()
if(DEFINED ENV{MPICC})
    set(MPICC_COMMAND $ENV{MPICC})
endif()
if(DEFINED ENV{MPICXX})
    set(MPICXX_COMMAND $ENV{MPICXX})
endif()

# Set vectorization flags for x86/x64 targets
if(ENABLE_X86_SIMD AND CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64|i386|i686")
    set(VECTORIZATION_FLAGS "")
    message(STATUS "Setting x86 vectorization flags")

    if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
        list(APPEND VECTORIZATION_FLAGS "-msse4.1" "-mavx" "-mavx2")
    elseif(CMAKE_CXX_COMPILER_ID MATCHES "MSVC")
        list(APPEND VECTORIZATION_FLAGS "/arch:AVX2")
    endif()

    # Apply vectorization flags via environment variables (like -fPIC) to ensure they propagate to all builds
    if(VECTORIZATION_FLAGS)
        string(JOIN " " VECTORIZATION_FLAGS_STR ${VECTORIZATION_FLAGS})
        set(ENV{CFLAGS} "${VECTORIZATION_FLAGS_STR} $ENV{CFLAGS}")
        set(ENV{CXXFLAGS} "${VECTORIZATION_FLAGS_STR} $ENV{CXXFLAGS}")
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${VECTORIZATION_FLAGS_STR}")
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${VECTORIZATION_FLAGS_STR}")
        message(STATUS "Enabled x86 SIMD optimizations via environment and CMake flags: ${VECTORIZATION_FLAGS_STR}")
    else()
        message(STATUS "Unable to set x86 vectorization flags for unexpected CXX compiler: ${CMAKE_CXX_COMPILER_ID}")
    endif()
else()
    message(STATUS "Skipping x86 vectorization flags with ENABLE_X86_SIMD=${ENABLE_X86_SIMD} and CMAKE_SYSTEM_PROCESSOR=${CMAKE_SYSTEM_PROCESSOR}" )
endif()

# Find MPI if building parallel
if(BUILD_PARALLEL)
    find_package(MPI REQUIRED)
    if(NOT MPI_FOUND)
        message(FATAL_ERROR "MPI not found but required for parallel build")
    endif()
endif()

# Include directories
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/headers)

# Find numpy include directory
execute_process(
    COMMAND ${Python_EXECUTABLE} -c "import numpy; print(numpy.get_include())"
    OUTPUT_VARIABLE NUMPY_INCLUDE_DIR
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
include_directories(${NUMPY_INCLUDE_DIR})

# Custom functions for MFEM specific tasks
function(generate_header_defines MFEM_SOURCE_DIR OUTPUT_FILE)
    # Generate existing_mfem_headers.i similar to original setup.py
    file(GLOB_RECURSE MFEM_HEADERS "${MFEM_SOURCE_DIR}/*.hpp")
    set(HEADER_DEFINES "")
    
    foreach(HEADER ${MFEM_HEADERS})
        # Convert header path to define name
        file(RELATIVE_PATH REL_PATH ${MFEM_SOURCE_DIR} ${HEADER})
        string(REPLACE "/" "_" DEFINE_NAME ${REL_PATH})
        string(REPLACE ".hpp" "" DEFINE_NAME ${DEFINE_NAME})
        string(REPLACE "-" "_" DEFINE_NAME ${DEFINE_NAME})
        string(TOUPPER ${DEFINE_NAME} DEFINE_NAME)
        set(DEFINE_NAME "FILE_EXISTS_${DEFINE_NAME}")
        set(HEADER_DEFINES "${HEADER_DEFINES}#define ${DEFINE_NAME}\n")
    endforeach()
    
    file(WRITE ${OUTPUT_FILE} ${HEADER_DEFINES})
endfunction()


# External dependency handling
# Automatically download external dependencies if they don't exist

# Define external dependency URLs and versions (matching setup_legacy.py)
set(MFEM_GIT_URL "https://github.com/mfem/mfem.git")
set(MFEM_GIT_SHA "c8ef9676e83c93a9037dbdf3bf0f2d741321e632")  # MFEM v4.9.1 with VTKHDF output

set(HYPRE_URL "https://github.com/hypre-space/hypre/archive/v2.28.0.tar.gz")
set(HDF5_URL "https://github.com/HDFGroup/hdf5/archive/refs/tags/hdf5_1.14.6.tar.gz")
set(METIS_URL "https://github.com/mfem/tpls/raw/gh-pages/metis-5.1.0.tar.gz")
set(LIBCEED_URL "https://github.com/CEED/libCEED/archive/refs/tags/v0.12.0.tar.gz")
set(GSLIB_URL "https://github.com/Nek5000/gslib/archive/refs/tags/v1.0.8.tar.gz")
set(LAPACK_URL "https://github.com/Reference-LAPACK/lapack/archive/v3.12.1.tar.gz")

# Function to download MFEM via git clone
function(download_mfem)
    if(NOT EXISTS ${MFEM_SOURCE})
        message(STATUS "MFEM not found at ${MFEM_SOURCE}, downloading...")
        
        # Ensure external directory exists
        file(MAKE_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/external)
        
        # Fetch only the pinned commit. The wheel build starts from a clean
        # source tree, so downloading the full MFEM history adds no value.
        find_package(Git QUIET)
        if(GIT_FOUND)
            file(MAKE_DIRECTORY ${MFEM_SOURCE})
            execute_process(
                COMMAND ${GIT_EXECUTABLE} init
                WORKING_DIRECTORY ${MFEM_SOURCE}
                RESULT_VARIABLE init_result
            )
            execute_process(
                COMMAND ${GIT_EXECUTABLE} remote add origin ${MFEM_GIT_URL}
                WORKING_DIRECTORY ${MFEM_SOURCE}
                RESULT_VARIABLE remote_result
            )

            if(init_result EQUAL "0" AND remote_result EQUAL "0")
                execute_process(
                    COMMAND ${GIT_EXECUTABLE} fetch --depth 1 origin ${MFEM_GIT_SHA}
                    WORKING_DIRECTORY ${MFEM_SOURCE}
                    RESULT_VARIABLE fetch_result
                )
                execute_process(
                    COMMAND ${GIT_EXECUTABLE} checkout --detach FETCH_HEAD
                    WORKING_DIRECTORY ${MFEM_SOURCE}
                    RESULT_VARIABLE checkout_result
                )

                if(fetch_result EQUAL "0" AND checkout_result EQUAL "0")
                    message(STATUS "Successfully downloaded MFEM to ${MFEM_SOURCE}")
                else()
                    message(FATAL_ERROR "Failed to fetch MFEM SHA: ${MFEM_GIT_SHA}")
                endif()
            else()
                message(FATAL_ERROR "Failed to initialize MFEM checkout from ${MFEM_GIT_URL}")
            endif()
        else()
            message(FATAL_ERROR "Git not found. Cannot download MFEM automatically.")
        endif()
    else()
        message(STATUS "MFEM found at ${MFEM_SOURCE}")
    endif()
endfunction()

# Function to download external tarball dependencies  
function(download_external_tarball name url)
    set(external_dir ${CMAKE_CURRENT_SOURCE_DIR}/external/${name})
    if(NOT EXISTS ${external_dir})
        message(STATUS "${name} not found at ${external_dir}, downloading...")
        
        file(MAKE_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/external)
        
        # Download tarball directly
        get_filename_component(tarball_name ${url} NAME)
        set(tarball_path ${CMAKE_CURRENT_SOURCE_DIR}/external/${tarball_name})
        
        file(DOWNLOAD ${url} ${tarball_path}
             SHOW_PROGRESS
             STATUS download_status
        )
        
        list(GET download_status 0 download_result)
        if(NOT download_result EQUAL 0)
            message(FATAL_ERROR "Failed to download ${name} from ${url}")
        endif()
        
        # Extract tarball to temporary location and move contents
        set(temp_extract_dir ${CMAKE_CURRENT_SOURCE_DIR}/external/temp_${name})
        file(MAKE_DIRECTORY ${temp_extract_dir})

        execute_process(
            COMMAND ${CMAKE_COMMAND} -E tar xzf ${tarball_path}
            WORKING_DIRECTORY ${temp_extract_dir}
            RESULT_VARIABLE extract_result
        )

        if(NOT extract_result EQUAL 0)
            message(FATAL_ERROR "Failed to extract ${tarball_name}")
        endif()

        # Find the extracted directory and move its contents to the target location
        file(GLOB extracted_items "${temp_extract_dir}/*")
        if(extracted_items)
            list(GET extracted_items 0 extracted_dir)
            if(IS_DIRECTORY ${extracted_dir})
                file(RENAME ${extracted_dir} ${external_dir})
            else()
                # If multiple items, move them all to target directory
                file(MAKE_DIRECTORY ${external_dir})
                file(GLOB all_items "${temp_extract_dir}/*")
                foreach(item ${all_items})
                    get_filename_component(item_name ${item} NAME)
                    file(RENAME ${item} ${external_dir}/${item_name})
                endforeach()
            endif()
        endif()

        # Clean up temporary directory
        file(REMOVE_RECURSE ${temp_extract_dir})
        
        # Clean up tarball
        file(REMOVE ${tarball_path})
        
        message(STATUS "Successfully downloaded ${name} to ${external_dir}")
    else()
        message(STATUS "${name} found at ${external_dir}")
    endif()
endfunction()




# Function to build MFEM using CMake
function(build_mfem_serial)
    set(mfem_build_dir ${MFEM_SOURCE}/build)

    message(STATUS "Building MFEM at ${MFEM_SOURCE}")
    
    # Create build directory
    file(MAKE_DIRECTORY ${mfem_build_dir})
    
    # Configure MFEM with CMake (serial version matching legacy setup.py)
    set(MFEM_SER_CMAKE_ARGS
        -DCMAKE_BUILD_TYPE=Release
        -DBUILD_SHARED_LIBS=ON
        -DMFEM_ENABLE_EXAMPLES=OFF
        -DMFEM_ENABLE_MINIAPPS=OFF
        -DMFEM_USE_ZLIB=ON
        -DMFEM_USE_MPI=OFF
        -DMFEM_USE_EXCEPTIONS=ON
        -DMFEM_THREAD_SAFE=ON
        -DMFEM_USE_OPENMP=OFF
        -DMFEM_USE_SUITESPARSE=OFF
        -DCMAKE_CXX_STANDARD=17
        -DCMAKE_CXX_STANDARD_REQUIRED=ON
        -DCMAKE_CXX_EXTENSIONS=OFF
        # The wheel copies this installed library into ``mfem/_ser/.dylibs``.
        # Resolve its bundled dependencies relative to that final location
        # instead of retaining paths to the temporary dependency build tree.
        -DCMAKE_INSTALL_RPATH=${CMAKE_INSTALL_RPATH}
        -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
        -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=OFF
        -DCMAKE_INSTALL_PREFIX=${mfem_build_dir}/install
    )

    # Add libCEED support if enabled
    if(BUILD_LIBCEED)
        list(APPEND MFEM_SER_CMAKE_ARGS 
            -DMFEM_USE_CEED=ON
            -DCEED_DIR=${EXT_PREFIX}
        )
    endif()
    
    # GSLIB is not supported in serial builds (requires MPI)
    
    # Add LAPACK support if enabled (use system libraries)
    if(ENABLE_LAPACK)
        list(APPEND MFEM_SER_CMAKE_ARGS -DMFEM_USE_LAPACK=ON)
        # Platform-specific BLAS/LAPACK hints
        if(APPLE)
            list(APPEND MFEM_SER_CMAKE_ARGS -DBLA_VENDOR=Apple)
        elseif(UNIX)
            list(APPEND MFEM_SER_CMAKE_ARGS -DBLA_VENDOR=OpenBLAS)
        endif()
    else()
        list(APPEND MFEM_SER_CMAKE_ARGS -DMFEM_USE_LAPACK=OFF)
    endif()
    
    # Add CUDA support if enabled (local builds only)
    if(ENABLE_CUDA)
        list(APPEND MFEM_SER_CMAKE_ARGS -DMFEM_USE_CUDA=ON)
        if(CUDA_ARCH)
            list(APPEND MFEM_SER_CMAKE_ARGS -DCMAKE_CUDA_ARCHITECTURES=${CUDA_ARCH})
        endif()
    endif()
    
    execute_process(
        COMMAND ${CMAKE_COMMAND} ${MFEM_SER_CMAKE_ARGS} ${MFEM_SOURCE}
        WORKING_DIRECTORY ${mfem_build_dir}
        RESULT_VARIABLE config_result
    )
    
    if(NOT config_result EQUAL "0")
        message(FATAL_ERROR "Failed to configure MFEM")
    endif()
    
    # Build MFEM
    execute_process(
        COMMAND ${CMAKE_COMMAND} --build . --parallel
        WORKING_DIRECTORY ${mfem_build_dir}
        RESULT_VARIABLE build_result
    )
    
    if(NOT build_result EQUAL "0")
        message(FATAL_ERROR "Failed to build MFEM")
    endif()
    
    # Install MFEM
    execute_process(
        COMMAND ${CMAKE_COMMAND} --build . --target install
        WORKING_DIRECTORY ${mfem_build_dir}
        RESULT_VARIABLE install_result
    )
    
    if(install_result EQUAL "0")
        message(STATUS "Successfully built and installed MFEM")
        # Update MFEM_SOURCE to point to the installed location for headers
        set(MFEM_BUILD_INSTALL_DIR ${mfem_build_dir}/install PARENT_SCOPE)
    else()
        message(FATAL_ERROR "Failed to install MFEM")
    endif()
endfunction()

# Function to build parallel MFEM using CMake
function(build_mfem_parallel)
    set(mfem_build_dir ${MFEM_SOURCE}/build_par)

    message(STATUS "Building parallel MFEM at ${MFEM_SOURCE}")
    message(STATUS "Looking for MFEM lib deps at ${EXT_PREFIX}/lib")

    # Verify required dependencies exist before building
    if(BUILD_HYPRE)
        set(HYPRE_LIB_PATH "${EXT_PREFIX}/lib/libHYPRE.${LIB_EXTENSION}")
        if(NOT EXISTS ${HYPRE_LIB_PATH})
            message(FATAL_ERROR "HYPRE library not found at ${HYPRE_LIB_PATH}. HYPRE must be built before parallel MFEM.")
        endif()
        message(STATUS "Found HYPRE library at ${HYPRE_LIB_PATH}")
    endif()

    if(BUILD_METIS)
        set(METIS_LIB_PATH "${EXT_PREFIX}/lib/libmetis.${LIB_EXTENSION}")
        if(NOT EXISTS ${METIS_LIB_PATH})
            message(FATAL_ERROR "METIS library not found at ${METIS_LIB_PATH}. METIS must be built before parallel MFEM.")
        endif()
        message(STATUS "Found METIS library at ${METIS_LIB_PATH}")
    endif()

    # Create build directory
    file(MAKE_DIRECTORY ${mfem_build_dir})
    
    # Configure parallel MFEM with CMake (matching legacy setup.py configuration)
    # Use platform-appropriate library extensions
    set(HYPRE_LIB_PATH "${EXT_PREFIX}/lib/libHYPRE.${LIB_EXTENSION}")
    set(METIS_LIB_PATH "${EXT_PREFIX}/lib/libmetis.${LIB_EXTENSION}")
    
    set(MFEM_PAR_CMAKE_ARGS
        -DCMAKE_BUILD_TYPE=Release
        -DBUILD_SHARED_LIBS=ON
        -DMFEM_ENABLE_EXAMPLES=OFF
        -DMFEM_ENABLE_MINIAPPS=OFF
        -DMFEM_USE_ZLIB=ON
        -DMFEM_USE_MPI=ON
        -DMFEM_USE_EXCEPTIONS=ON
        -DMFEM_THREAD_SAFE=ON
        -DMFEM_USE_OPENMP=OFF
        -DMFEM_USE_SUITESPARSE=OFF
        -DCMAKE_CXX_STANDARD=17
        -DCMAKE_CXX_STANDARD_REQUIRED=ON
        -DCMAKE_CXX_EXTENSIONS=OFF
        # HYPRE, METIS, and libCEED are packaged beside libmfem in
        # ``mfem/_par/.dylibs``. Keep the nested MFEM install relocatable so
        # those libraries remain resolvable after the build tree is removed.
        -DCMAKE_INSTALL_RPATH=${CMAKE_INSTALL_RPATH}
        -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
        -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=OFF
        # Parallel-specific flags
        -DCMAKE_CXX_COMPILER=${MPICXX_COMMAND}
        -DCMAKE_INSTALL_PREFIX=${mfem_build_dir}/install
        -DHYPRE_DIR=${EXT_PREFIX}
        -DHYPRE_INCLUDE_DIRS=${EXT_PREFIX}/include
        -DHYPRE_LIBRARIES=${HYPRE_LIB_PATH}
        -DMFEM_USE_METIS_5=ON
        -DMETIS_DIR=${EXT_PREFIX}
        -DMETIS_INCLUDE_DIRS=${CMAKE_CURRENT_SOURCE_DIR}/external/metis/include
        -DMETIS_LIBRARIES=${METIS_LIB_PATH}
    )

    if(BUILD_HDF5)
        list(APPEND MFEM_PAR_CMAKE_ARGS
            -DMFEM_USE_HDF5=ON
            -DHDF5_DIR=${EXT_PREFIX}
            -DHDF5_USE_STATIC_LIBRARIES=ON
        )
    endif()
    
    # Add libCEED support if enabled
    if(BUILD_LIBCEED)
        list(APPEND MFEM_PAR_CMAKE_ARGS 
            -DMFEM_USE_CEED=ON
            -DCEED_DIR=${EXT_PREFIX}
        )
    endif()
    
    # Add GSLIB support if enabled (parallel only)
    if(BUILD_GSLIB AND BUILD_PARALLEL)
        list(APPEND MFEM_PAR_CMAKE_ARGS 
            -DMFEM_USE_GSLIB=ON
            -DGSLIB_DIR=${EXT_PREFIX}
            -DGSLIB_INCLUDE_DIRS=${EXT_PREFIX}/include
            -DGSLIB_LIBRARIES=${EXT_PREFIX}/lib/libgs.a
        )
    endif()
    
    # Add LAPACK support if enabled (use system libraries)
    if(ENABLE_LAPACK)
        list(APPEND MFEM_PAR_CMAKE_ARGS -DMFEM_USE_LAPACK=ON)
        # Platform-specific BLAS/LAPACK hints
        if(APPLE)
            list(APPEND MFEM_PAR_CMAKE_ARGS -DBLA_VENDOR=Apple)
        elseif(UNIX)
            list(APPEND MFEM_PAR_CMAKE_ARGS -DBLA_VENDOR=OpenBLAS)
        endif()
    else()
        list(APPEND MFEM_PAR_CMAKE_ARGS -DMFEM_USE_LAPACK=OFF)
    endif()
    
    # Add CUDA support if enabled (local builds only)
    if(ENABLE_CUDA)
        list(APPEND MFEM_PAR_CMAKE_ARGS -DMFEM_USE_CUDA=ON)
        if(CUDA_ARCH)
            list(APPEND MFEM_PAR_CMAKE_ARGS -DCMAKE_CUDA_ARCHITECTURES=${CUDA_ARCH})
        endif()
    endif()
    
    execute_process(
        COMMAND ${CMAKE_COMMAND} ${MFEM_PAR_CMAKE_ARGS} ${MFEM_SOURCE}
        WORKING_DIRECTORY ${mfem_build_dir}
        RESULT_VARIABLE config_result
    )
    
    if(NOT config_result EQUAL "0")
        message(FATAL_ERROR "Failed to configure parallel MFEM")
    endif()
    
    # Build parallel MFEM
    execute_process(
        COMMAND ${CMAKE_COMMAND} --build . --parallel
        WORKING_DIRECTORY ${mfem_build_dir}
        RESULT_VARIABLE build_result
    )
    
    if(NOT build_result EQUAL "0")
        message(FATAL_ERROR "Failed to build parallel MFEM")
    endif()
    
    # Install parallel MFEM
    execute_process(
        COMMAND ${CMAKE_COMMAND} --build . --target install
        WORKING_DIRECTORY ${mfem_build_dir}
        RESULT_VARIABLE install_result
    )
    
    if(install_result EQUAL "0")
        message(STATUS "Successfully built and installed parallel MFEM")
        # Copy data for testing (matching setup_legacy.py behavior)
        if(EXISTS ${MFEM_SOURCE}/data)
            execute_process(
                COMMAND ${CMAKE_COMMAND} -E copy_directory ${MFEM_SOURCE}/data ${mfem_build_dir}/install/data
            )
        endif()
        set(MFEM_PAR_BUILD_INSTALL_DIR ${mfem_build_dir}/install PARENT_SCOPE)
    else()
        message(FATAL_ERROR "Failed to install parallel MFEM")
    endif()
endfunction()

# Download and build dependencies in correct order
# Isolated wheel builds start from clean third-party sources. Developers can
# opt into reuse when iterating in a persistent scikit-build directory.
if(PYMFEM_REUSE_EXTERNAL)
    message(STATUS "Reusing external/ directory for incremental local build")
else()
    message(STATUS "Cleaning up any existing external/ directory from previous builds")
    file(REMOVE_RECURSE ${CMAKE_CURRENT_SOURCE_DIR}/external)
endif()

# Download all required external dependencies
if(BUILD_PARALLEL OR BUILD_METIS)
    download_external_tarball(metis ${METIS_URL})
endif()

if(BUILD_PARALLEL OR BUILD_HYPRE)
    download_external_tarball(hypre ${HYPRE_URL})
endif()

if(BUILD_HDF5)
    download_external_tarball(hdf5 ${HDF5_URL})
endif()

if(BUILD_LIBCEED)
    download_external_tarball(libceed ${LIBCEED_URL})
endif()

if(BUILD_GSLIB AND BUILD_PARALLEL)
    download_external_tarball(gslib ${GSLIB_URL})
endif()

# Download MFEM source
download_mfem()

# Build dependencies in order (parallel dependencies must be built before parallel MFEM)
if(BUILD_PARALLEL OR BUILD_METIS)
    message(STATUS "Building METIS dependency for parallel MFEM")
    execute_process(
        COMMAND ${CMAKE_COMMAND}
            -DMETIS_SOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}/external/metis
            -DMETIS_INSTALL_DIR=${EXT_PREFIX}
            -DMETIS_CC_COMMAND=${CC_COMMAND}
            -DCMAKE_BUILD_PARALLEL_LEVEL=${CMAKE_BUILD_PARALLEL_LEVEL}
            -DLIB_EXTENSION=${LIB_EXTENSION}
            -DCMAKE_POLICY_VERSION_MINIMUM=3.5
            -P ${CMAKE_CURRENT_SOURCE_DIR}/scripts/build_metis.cmake
        RESULT_VARIABLE metis_result
    )
    if(NOT metis_result EQUAL "0")
        message(FATAL_ERROR "Failed to build METIS")
    endif()
    message(STATUS "METIS build completed successfully")
endif()

if(BUILD_PARALLEL OR BUILD_HYPRE)
    message(STATUS "Building HYPRE dependency for parallel MFEM")
    execute_process(
        COMMAND ${CMAKE_COMMAND}
            -DHYPRE_SOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}/external/hypre
            -DHYPRE_INSTALL_DIR=${EXT_PREFIX}
            -DMPICC_COMMAND=${MPICC_COMMAND}
            -DCMAKE_BUILD_PARALLEL_LEVEL=${CMAKE_BUILD_PARALLEL_LEVEL}
            -DLIB_EXTENSION=${LIB_EXTENSION}
            -DENABLE_CUDA=${ENABLE_CUDA}
            -DCUDA_PREFIX=${CUDA_PREFIX}
            -DCUDA_ARCH=${CUDA_ARCH}
            -P ${CMAKE_CURRENT_SOURCE_DIR}/scripts/build_hypre.cmake
        RESULT_VARIABLE hypre_result
    )
    if(NOT hypre_result EQUAL "0")
        message(FATAL_ERROR "Failed to build HYPRE")
    endif()
    message(STATUS "HYPRE build completed successfully")
endif()

if(BUILD_HDF5)
    message(STATUS "Building parallel HDF5 dependency")
    execute_process(
        COMMAND ${CMAKE_COMMAND}
            -DHDF5_SOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}/external/hdf5
            -DHDF5_INSTALL_DIR=${EXT_PREFIX}
            -DMPICC_COMMAND=${MPICC_COMMAND}
            -DCMAKE_BUILD_PARALLEL_LEVEL=${CMAKE_BUILD_PARALLEL_LEVEL}
            -P ${CMAKE_CURRENT_SOURCE_DIR}/scripts/build_hdf5.cmake
        RESULT_VARIABLE hdf5_result
    )
    if(NOT hdf5_result EQUAL "0")
        message(FATAL_ERROR "Failed to build HDF5")
    endif()
    message(STATUS "HDF5 build completed successfully")
endif()

if(BUILD_LIBCEED)
    message(STATUS "Building libCEED dependency")
    execute_process(
        COMMAND ${CMAKE_COMMAND}
            -DLIBCEED_SOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}/external/libceed
            -DLIBCEED_INSTALL_DIR=${EXT_PREFIX}
            -DCMAKE_BUILD_PARALLEL_LEVEL=${CMAKE_BUILD_PARALLEL_LEVEL}
            -DLIB_EXTENSION=${LIB_EXTENSION}
            -DENABLE_CUDA=${ENABLE_CUDA}
            -DCUDA_PREFIX=${CUDA_PREFIX}
            -P ${CMAKE_CURRENT_SOURCE_DIR}/scripts/build_libceed.cmake
        RESULT_VARIABLE libceed_result
    )
    if(NOT libceed_result EQUAL "0")
        message(FATAL_ERROR "Failed to build libCEED")
    endif()
    message(STATUS "libCEED build completed successfully")
endif()

if(BUILD_GSLIB AND BUILD_PARALLEL)
    message(STATUS "Building GSLIB dependency for parallel MFEM")
    execute_process(
        COMMAND ${CMAKE_COMMAND}
            -DGSLIB_SOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}/external/gslib
            -DGSLIB_INSTALL_DIR_PAR=${EXT_PREFIX}
            -DMPICC_COMMAND=${MPICC_COMMAND}
            -DBUILD_SERIAL=OFF
            -DBUILD_PARALLEL=ON
            -P ${CMAKE_CURRENT_SOURCE_DIR}/scripts/build_gslib.cmake
        RESULT_VARIABLE gslib_result
    )
    if(NOT gslib_result EQUAL "0")
        message(FATAL_ERROR "Failed to build GSLIB")
    endif()
    message(STATUS "GSLIB build completed successfully")
endif()

# LAPACK/BLAS: Let MFEM use system libraries (Apple Accelerate, OpenBLAS, MKL, etc.)
if(ENABLE_LAPACK)
    message(STATUS "LAPACK enabled - MFEM will use system LAPACK/BLAS libraries")
endif()

# Build MFEM (serial first, then parallel if requested)
# All dependencies are now guaranteed to be built and installed
message(STATUS "All dependencies built successfully, proceeding with MFEM builds")
build_mfem_serial()

# Build parallel MFEM if requested - all dependencies are now available
if(BUILD_PARALLEL)
    message(STATUS "Building parallel MFEM (dependencies are ready)")
    build_mfem_parallel()
endif()

# Generate MFEM header defines
generate_header_defines(${MFEM_SOURCE} ${CMAKE_CURRENT_SOURCE_DIR}/mfem/common/existing_mfem_headers.i)

# Use python-managed swig
execute_process(
    COMMAND ${Python_EXECUTABLE} -c "import swig; import os; print(os.path.join(swig.BIN_DIR, \"swig\"))"
    OUTPUT_VARIABLE SWIG_EXECUTABLE
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

execute_process(
    COMMAND ${Python_EXECUTABLE} -c "import swig; print(swig.SWIG_LIB_ENV[\"SWIG_LIB\"])"
    OUTPUT_VARIABLE SWIG_LIB_DIR
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

# Match legacy setup.py SWIG flags: '-Wall -c++ -python -fastproxy -olddefs -keyword'
# Note: Excluding -python here since CMake's swig_add_library(LANGUAGE python) already adds it
set(CMAKE_SWIG_FLAGS -Wall -c++ -fastproxy -olddefs -keyword)
set(CMAKE_SWIG_OUTDIR ${CMAKE_CURRENT_BINARY_DIR})
set(UseSWIG_TARGET_NAME_PREFERENCE STANDARD)

message(VERBOSE "PyMFEM: CMAKE_SWIG_FLAGS = ${CMAKE_SWIG_FLAGS}")
message(VERBOSE "PyMFEM: CMAKE_SWIG_OUTDIR = ${CMAKE_SWIG_OUTDIR}")
message(VERBOSE "PyMFEM: SWIG_EXECUTABLE = ${SWIG_EXECUTABLE}")
message(VERBOSE "PyMFEM: SWIG_LIB_DIR = ${SWIG_LIB_DIR}")

# Force SWIG to generate C++ files with .cxx extension
set(SWIG_CXX_EXTENSION "cxx")
set_property(GLOBAL PROPERTY SWIG_CXX_EXTENSION "cxx")

# Add subdirectories for serial and parallel builds
add_subdirectory(mfem/_ser)
if(BUILD_PARALLEL)
    add_subdirectory(mfem/_par)
endif()

# Main mfem package installation
install(FILES mfem/__init__.py DESTINATION mfem/)
install(FILES mfem/ser.py DESTINATION mfem/)
if(BUILD_PARALLEL)
    install(FILES mfem/par.py DESTINATION mfem/)
endif()

# Install common files
install(DIRECTORY mfem/common/ DESTINATION mfem/common/
        FILES_MATCHING PATTERN "*.py")

# Install data and examples
install(DIRECTORY data/ DESTINATION share/mfem/data)
install(DIRECTORY examples/ DESTINATION share/mfem/examples
            FILES_MATCHING PATTERN "*.py"
            PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)

# Clean source-tree dependencies after isolated builds, while retaining them
# when a developer explicitly requests an incremental local build.
if(NOT PYMFEM_REUSE_EXTERNAL)
    install(CODE "
        message(STATUS \"Removing external/ directory after installation\")
        execute_process(COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_CURRENT_SOURCE_DIR}/external)
    ")
endif()
