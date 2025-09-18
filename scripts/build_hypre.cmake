# CMake script to build HYPRE dependency
# Called with: cmake -P build_hypre.cmake
# Variables expected:
# - HYPRE_SOURCE_DIR: Path to HYPRE source directory
# - HYPRE_INSTALL_DIR: Installation prefix
# - MPICC_COMMAND: MPI C compiler command
# - CMAKE_BUILD_PARALLEL_LEVEL: Number of parallel jobs
# - LIB_EXTENSION: Library extension (so/dylib)
# - ENABLE_CUDA: Whether CUDA is enabled (optional)
# - CUDA_PREFIX: CUDA installation path (optional)
# - CUDA_ARCH: CUDA compute capability (optional)

if(NOT DEFINED HYPRE_SOURCE_DIR OR NOT DEFINED HYPRE_INSTALL_DIR OR NOT DEFINED MPICC_COMMAND)
    message(FATAL_ERROR "Required variables not set: HYPRE_SOURCE_DIR, HYPRE_INSTALL_DIR, MPICC_COMMAND")
endif()

set(hypre_dir ${HYPRE_SOURCE_DIR})
set(hypre_build_dir ${hypre_dir}/src/cmbuild)
set(hypre_install_dir ${HYPRE_INSTALL_DIR})

message(STATUS "Building HYPRE at ${hypre_dir}")
message(STATUS "Installing HYPRE at ${hypre_install_dir}")

if(NOT EXISTS ${hypre_dir})
    message(FATAL_ERROR "HYPRE source not found at ${hypre_dir}")
endif()

# Create build directory
file(MAKE_DIRECTORY ${hypre_build_dir})

# Configure HYPRE with CMake (matching setup_legacy.py configuration)
set(HYPRE_CMAKE_ARGS
    -DCMAKE_BUILD_TYPE=Release
    -DBUILD_SHARED_LIBS=ON
    -DHYPRE_INSTALL_PREFIX=${hypre_install_dir}
    -DHYPRE_ENABLE_SHARED=ON
    -DCMAKE_C_FLAGS=$ENV{CFLAGS}
    -DCMAKE_INSTALL_PREFIX=${hypre_install_dir}
    -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
)

if(APPLE)
    list(APPEND HYPRE_CMAKE_ARGS -DCMAKE_INSTALL_NAME_DIR=${hypre_install_dir}/lib)
endif()

# HYPRE 2.28 is not compatible with CUDA 12, so disable CUDA for HYPRE
# Always use MPI compiler and disable CUDA for HYPRE
list(APPEND HYPRE_CMAKE_ARGS
    -DHYPRE_WITH_CUDA=OFF
    -DCMAKE_C_COMPILER=${MPICC_COMMAND}
)

execute_process(
    COMMAND ${CMAKE_COMMAND} ${HYPRE_CMAKE_ARGS} ..
    WORKING_DIRECTORY ${hypre_build_dir}
    RESULT_VARIABLE config_result
)

if(NOT config_result EQUAL "0")
    message(FATAL_ERROR "Failed to configure HYPRE")
endif()

# Build HYPRE
execute_process(
    COMMAND ${CMAKE_COMMAND} --build . --parallel
    WORKING_DIRECTORY ${hypre_build_dir}
    RESULT_VARIABLE build_result
)

if(NOT build_result EQUAL "0")
    message(FATAL_ERROR "Failed to build HYPRE")
endif()

# Install HYPRE
execute_process(
    COMMAND ${CMAKE_COMMAND} --build . --target install
    WORKING_DIRECTORY ${hypre_build_dir}
    RESULT_VARIABLE install_result
)

if(install_result EQUAL "0")
    message(STATUS "Successfully built and installed HYPRE")
else()
    message(FATAL_ERROR "Failed to install HYPRE")
endif()

message(STATUS "Built HYPRE")