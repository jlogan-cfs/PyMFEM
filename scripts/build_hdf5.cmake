# Build a static, MPI-enabled HDF5 library for MFEM's parallel VTKHDF writer.
# Static linkage keeps HDF5 out of the wheel's runtime dynamic-library graph.

if(NOT DEFINED HDF5_SOURCE_DIR OR
   NOT DEFINED HDF5_INSTALL_DIR OR
   NOT DEFINED MPICC_COMMAND)
    message(FATAL_ERROR
        "Required variables not set: HDF5_SOURCE_DIR, HDF5_INSTALL_DIR, MPICC_COMMAND")
endif()

set(hdf5_build_dir ${HDF5_SOURCE_DIR}/build)
file(MAKE_DIRECTORY ${hdf5_build_dir})

set(HDF5_CMAKE_ARGS
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_C_COMPILER=${MPICC_COMMAND}
    -DCMAKE_INSTALL_PREFIX=${HDF5_INSTALL_DIR}
    -DCMAKE_INSTALL_LIBDIR=lib
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON
    -DBUILD_SHARED_LIBS=OFF
    -DBUILD_TESTING=OFF
    -DHDF5_ENABLE_PARALLEL=ON
    -DHDF5_BUILD_CPP_LIB=OFF
    -DHDF5_BUILD_FORTRAN=OFF
    -DHDF5_BUILD_HL_LIB=ON
    -DHDF5_BUILD_TOOLS=OFF
    -DHDF5_BUILD_EXAMPLES=OFF
    -DHDF5_ENABLE_SZIP_SUPPORT=OFF
    -DHDF5_ENABLE_Z_LIB_SUPPORT=ON
)

execute_process(
    COMMAND ${CMAKE_COMMAND} ${HDF5_CMAKE_ARGS} ${HDF5_SOURCE_DIR}
    WORKING_DIRECTORY ${hdf5_build_dir}
    RESULT_VARIABLE config_result
)
if(NOT config_result EQUAL "0")
    message(FATAL_ERROR "Failed to configure HDF5")
endif()

execute_process(
    COMMAND ${CMAKE_COMMAND} --build . --parallel
    WORKING_DIRECTORY ${hdf5_build_dir}
    RESULT_VARIABLE build_result
)
if(NOT build_result EQUAL "0")
    message(FATAL_ERROR "Failed to build HDF5")
endif()

execute_process(
    COMMAND ${CMAKE_COMMAND} --build . --target install
    WORKING_DIRECTORY ${hdf5_build_dir}
    RESULT_VARIABLE install_result
)
if(NOT install_result EQUAL "0")
    message(FATAL_ERROR "Failed to install HDF5")
endif()
