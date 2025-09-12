# Parallel MFEM Python wrapper
set(SWIG_MODULE_NAME "_par")

# Enforce C++11 standard
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Enable verbose logging for debugging
message(STATUS "PyMFEM _par: Starting parallel module build")
message(STATUS "PyMFEM _par: CMAKE_CURRENT_SOURCE_DIR = ${CMAKE_CURRENT_SOURCE_DIR}")
message(STATUS "PyMFEM _par: CMAKE_CURRENT_BINARY_DIR = ${CMAKE_CURRENT_BINARY_DIR}")
message(STATUS "PyMFEM _par: MFEM_SOURCE = ${MFEM_SOURCE}")
message(STATUS "PyMFEM _par: EXT_PREFIX = ${EXT_PREFIX}")

# Find required packages
find_package(PkgConfig REQUIRED)
find_package(MPI REQUIRED)

# Set SWIG properties
set_property(SOURCE ${CMAKE_CURRENT_SOURCE_DIR}/*.i PROPERTY CPLUSPLUS ON)
set_property(SOURCE ${CMAKE_CURRENT_SOURCE_DIR}/*.i PROPERTY SWIG_MODULE_NAME ${SWIG_MODULE_NAME})

# Ensure all SWIG interface files are treated as C++
foreach(SWIG_INTERFACE ${SWIG_INTERFACES})
    set_property(SOURCE ${SWIG_INTERFACE} PROPERTY CPLUSPLUS ON)
endforeach()

# SWIG flags inherited from parent CMakeLists.txt

# Get list of SWIG interface files
file(GLOB SWIG_INTERFACES "${CMAKE_CURRENT_SOURCE_DIR}/*.i")

# Include directories for parallel build
# Include both MFEM source (for .hpp files) and build directory (for config.hpp)
# Include METIS and HYPRE for parallel dependencies
include_directories(
    ${Python_INCLUDE_DIRS}
    ${MPI_CXX_INCLUDE_DIRS}
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/../common
    ${MFEM_SOURCE}
    ${MFEM_SOURCE}/build_par
    ${MFEM_SOURCE}/build_par/config
    ${MFEM_SOURCE}/build_par/install/include
    ${EXT_PREFIX}/include
)

# Find numpy include directory
execute_process(
    COMMAND ${Python_EXECUTABLE} -c "import numpy; print(numpy.get_include())"
    OUTPUT_VARIABLE NUMPY_INCLUDE_DIR
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
include_directories(${NUMPY_INCLUDE_DIR})


if(MPI4PY_INCLUDE_DIR)
    include_directories(${MPI4PY_INCLUDE_DIR})
    message(STATUS "PyMFEM _par: MPI4PY_INCLUDE_DIR = ${MPI4PY_INCLUDE_DIR}")
else()
    message(WARNING "PyMFEM _par: mpi4py not found - parallel build may fail")
endif()

# Set a unique output directory for parallel SWIG modules to avoid conflicts with serial
set(CMAKE_SWIG_OUTDIR "${CMAKE_CURRENT_BINARY_DIR}/swig_par")
file(MAKE_DIRECTORY "${CMAKE_SWIG_OUTDIR}")

# Create SWIG modules for each interface
foreach(SWIG_INTERFACE ${SWIG_INTERFACES})
    get_filename_component(MODULE_NAME ${SWIG_INTERFACE} NAME_WE)
    
    # Skip certain modules that require special handling - they're handled separately below
    if(MODULE_NAME MATCHES "^(lininteg|bilininteg)$")
        message(STATUS "PyMFEM _par: Skipping ${MODULE_NAME} - will be handled separately")
        continue()
    endif()
    
    # Skip strumpack if not enabled
    if(MODULE_NAME STREQUAL "strumpack" AND NOT ENABLE_STRUMPACK)
        continue()
    endif()
    
    # Skip schwarz if SuiteSparse is not enabled (schwarz requires UMFPackSolver)
    if(MODULE_NAME STREQUAL "schwarz" AND NOT ENABLE_SUITESPARSE)
        continue()
    endif()
    
    # Skip pumi if not enabled (pumi requires PUMI library)
    if(MODULE_NAME STREQUAL "pumi" AND NOT ENABLE_PUMI)
        continue()
    endif()
    
    # Skip gslib if not enabled (gslib requires GSLib library)
    if(MODULE_NAME STREQUAL "gslib" AND NOT BUILD_GSLIB)
        continue()
    endif()
    
    # Set C++ properties before creating the library
    set_property(SOURCE ${SWIG_INTERFACE} PROPERTY CPLUSPLUS ON)
    
    # Add SWIG include directories for this interface (matching legacy setup.py)
    set_property(SOURCE ${SWIG_INTERFACE} PROPERTY SWIG_FLAGS 
        "-I${SWIG_LIB_DIR}/python"
        "-I${MFEM_SOURCE}"
        "-I${MFEM_SOURCE}/build_par/install/include"
        "-I${EXT_PREFIX}/include"
        "-I${MPI4PY_INCLUDE_DIR}"
    )
    
    message(VERBOSE "PyMFEM _par: Creating SWIG library for ${MODULE_NAME}")
    
    # Add _par suffix to avoid conflicts with serial build targets
    swig_add_library(${MODULE_NAME}_par
        TYPE MODULE
        LANGUAGE python
        SOURCES ${SWIG_INTERFACE}
        OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/swig_par"
    )
    
    # Set target properties
    set_target_properties(${MODULE_NAME}_par PROPERTIES
        OUTPUT_NAME "_${MODULE_NAME}"
        PREFIX ""
        SUFFIX ".${Python_SOABI}.so"
        LINKER_LANGUAGE CXX
        CXX_STANDARD 11
        CXX_STANDARD_REQUIRED ON
        CXX_EXTENSIONS OFF
    )

    # Ensure SWIG-generated files are compiled as C++
    set_source_files_properties(${SWIG_INTERFACE} PROPERTIES CPLUSPLUS ON)
    
    # Force all C files in this target to be compiled as C++
    get_target_property(TARGET_SOURCES ${MODULE_NAME}_par SOURCES)
    foreach(SOURCE_FILE ${TARGET_SOURCES})
        if(SOURCE_FILE MATCHES ".*\\.c$")
            set_source_files_properties(${SOURCE_FILE} PROPERTIES LANGUAGE CXX)
        endif()
    endforeach()
    
    # Add preprocessor definitions matching legacy setup.py
    target_compile_definitions(${MODULE_NAME}_par PRIVATE
        SWIG_TYPE_TABLE=PyMFEM
        TARGET_PY3=1
        NPY_NO_DEPRECATED_API=NPY_1_7_API_VERSION
    )
    
    # Link against Python, MPI, parallel MFEM, and dependencies
    # Use platform-appropriate library extensions
    set(MFEM_LIB "${MFEM_SOURCE}/build_par/install/lib/libmfem.${LIB_EXTENSION}")
    set(HYPRE_LIB "${EXT_PREFIX}/lib/libHYPRE.${LIB_EXTENSION}") 
    set(METIS_LIB "${EXT_PREFIX}/lib/libmetis.${LIB_EXTENSION}")
    
    target_link_libraries(${MODULE_NAME}_par 
        Python::Module 
        ${MPI_CXX_LIBRARIES}
        ${MFEM_LIB}
        ${HYPRE_LIB}
        ${METIS_LIB}
    )
    
    # Install the module
    install(TARGETS ${MODULE_NAME}_par  LIBRARY DESTINATION mfem/_par)

    # Install the generated Python wrapper file (SWIG generates these in the parallel swig directory)
    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/swig_par/${MODULE_NAME}.py
            DESTINATION mfem/_par)
endforeach()

# Post-process lininteg and bilininteg modules (similar to legacy setup.py)
# First, create the modules if they exist in the interface list
file(GLOB LININTEG_INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/lininteg.i")
file(GLOB BILININTEG_INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/bilininteg.i") 

#
# Process lininteg
#
get_filename_component(MODULE_NAME ${LININTEG_INTERFACE} NAME_WE)

# Set C++ properties before creating the library
set_property(SOURCE ${LININTEG_INTERFACE} PROPERTY CPLUSPLUS ON)

# Add SWIG include directories for this interface
set_property(SOURCE ${LININTEG_INTERFACE} PROPERTY SWIG_FLAGS 
    "-I${SWIG_LIB_DIR}/python"
    "-I${MFEM_SOURCE}"
    "-I${MFEM_SOURCE}/build_par/install/include"
    "-I${EXT_PREFIX}/include"
    "-I${MPI4PY_INCLUDE_DIR}"
)

swig_add_library(${MODULE_NAME}_par
    TYPE MODULE
    LANGUAGE python
    SOURCES ${LININTEG_INTERFACE}
    OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/swig_par"
)

# Set target properties
set_target_properties(${MODULE_NAME}_par PROPERTIES
    OUTPUT_NAME "_${MODULE_NAME}"
    PREFIX ""
    SUFFIX ".${Python_SOABI}.so"
    LINKER_LANGUAGE CXX
    CXX_STANDARD 11
    CXX_STANDARD_REQUIRED ON
    CXX_EXTENSIONS OFF
)

# Add preprocessor definitions
target_compile_definitions(${MODULE_NAME}_par PRIVATE
    SWIG_TYPE_TABLE=PyMFEM
    TARGET_PY3=1
    NPY_NO_DEPRECATED_API=NPY_1_7_API_VERSION
)

# Link libraries
target_link_libraries(${MODULE_NAME}_par 
    Python::Module 
    ${MPI_CXX_LIBRARIES}
    ${MFEM_LIB}
    ${HYPRE_LIB}
    ${METIS_LIB}
)


# Install the module and Python wrapper
install(TARGETS ${MODULE_NAME}_par LIBRARY DESTINATION mfem/_par)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/swig_par/${MODULE_NAME}.py DESTINATION mfem/_par)

# Post-process lininteg extensions
add_custom_command(TARGET ${MODULE_NAME}_par POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_BINARY_DIR}/swig_par/${MODULE_NAME}.py ${CMAKE_CURRENT_SOURCE_DIR}/../common/../_par/${MODULE_NAME}.py
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_BINARY_DIR}/swig_par/${MODULE_NAME}.py ${CMAKE_CURRENT_SOURCE_DIR}/../common/../_ser/${MODULE_NAME}.py
    COMMAND ${Python_EXECUTABLE} generate_lininteg_ext.py
    COMMAND ${CMAKE_COMMAND} -E remove ${CMAKE_CURRENT_SOURCE_DIR}/../common/../_par/${MODULE_NAME}.py
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../common
    COMMENT "Generating lininteg extensions for parallel"
)

#
# Process bilininteg
#
get_filename_component(MODULE_NAME ${BILININTEG_INTERFACE} NAME_WE)

# Set C++ properties before creating the library
set_property(SOURCE ${BILININTEG_INTERFACE} PROPERTY CPLUSPLUS ON)

# Add SWIG include directories for this interface
set_property(SOURCE ${BILININTEG_INTERFACE} PROPERTY SWIG_FLAGS 
    "-I${SWIG_LIB_DIR}/python"
    "-I${MFEM_SOURCE}"
    "-I${MFEM_SOURCE}/build_par/install/include"
    "-I${EXT_PREFIX}/include"
    "-I${MPI4PY_INCLUDE_DIR}"
)

swig_add_library(${MODULE_NAME}_par
    TYPE MODULE
    LANGUAGE python
    SOURCES ${BILININTEG_INTERFACE}
    OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/swig_par"
)

# Set target properties
set_target_properties(${MODULE_NAME}_par PROPERTIES
    OUTPUT_NAME "_${MODULE_NAME}"
    PREFIX ""
    SUFFIX ".${Python_SOABI}.so"
    LINKER_LANGUAGE CXX
    CXX_STANDARD 11
    CXX_STANDARD_REQUIRED ON
    CXX_EXTENSIONS OFF
)

# Add preprocessor definitions
target_compile_definitions(${MODULE_NAME}_par PRIVATE
    SWIG_TYPE_TABLE=PyMFEM
    TARGET_PY3=1
    NPY_NO_DEPRECATED_API=NPY_1_7_API_VERSION
)

# Link libraries
target_link_libraries(${MODULE_NAME}_par 
    Python::Module 
    ${MPI_CXX_LIBRARIES}
    ${MFEM_LIB}
    ${HYPRE_LIB}
    ${METIS_LIB}
)

# Install the module and Python wrapper
install(TARGETS ${MODULE_NAME}_par LIBRARY DESTINATION mfem/_par)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/swig_par/${MODULE_NAME}.py DESTINATION mfem/_par)

# Post-process bilininteg extensions
add_custom_command(TARGET ${MODULE_NAME}_par POST_BUILD  
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_BINARY_DIR}/swig_par/${MODULE_NAME}.py ${CMAKE_CURRENT_SOURCE_DIR}/../common/../_par/${MODULE_NAME}.py
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_BINARY_DIR}/swig_par/${MODULE_NAME}.py ${CMAKE_CURRENT_SOURCE_DIR}/../common/../_ser/${MODULE_NAME}.py
    COMMAND ${Python_EXECUTABLE} generate_bilininteg_ext.py
    COMMAND ${CMAKE_COMMAND} -E remove ${CMAKE_CURRENT_SOURCE_DIR}/../common/../_par/${MODULE_NAME}.py
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../common
    COMMENT "Generating bilininteg extensions for parallel"
)

# Install Python files
file(GLOB PYTHON_FILES "${CMAKE_CURRENT_SOURCE_DIR}/*.py")
install(FILES ${PYTHON_FILES} DESTINATION mfem/_par)

# Install required dynamic libraries for wheel distribution
set(MFEM_LIB_INSTALL "${MFEM_SOURCE}/build_par/install/lib/libmfem.${LIB_EXTENSION}")
set(HYPRE_LIB_INSTALL "${EXT_PREFIX}/lib/libHYPRE.${LIB_EXTENSION}") 
set(METIS_LIB_INSTALL "${EXT_PREFIX}/lib/libmetis.${LIB_EXTENSION}")

# Install the parallel libraries to parallel-specific .dylibs subdirectory
install(DIRECTORY "${MFEM_SOURCE}/build_par/install/lib/"
        DESTINATION mfem/_par/.dylibs
        FILES_MATCHING PATTERN "libmfem.*"
        PATTERN "cmake" EXCLUDE)
install(FILES ${HYPRE_LIB_INSTALL} DESTINATION mfem/_par/.dylibs OPTIONAL)  
install(FILES ${METIS_LIB_INSTALL} DESTINATION mfem/_par/.dylibs OPTIONAL)

# Fix RPATH for MFEM libraries and Python extensions using external script  
install(CODE "
    set(LIB_EXTENSION \"${LIB_EXTENSION}\")
    set(CMAKE_INSTALL_RPATH \"${CMAKE_INSTALL_RPATH}\")
    include(${CMAKE_CURRENT_SOURCE_DIR}/../../fix_rpath.cmake)
")