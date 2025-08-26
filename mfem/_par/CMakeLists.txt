# Parallel MFEM Python wrapper
set(SWIG_MODULE_NAME "_par")

# Enforce C++11 standard
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

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
# Note: Avoiding SWIG_LIB_DIR includes to prevent std_except.i version conflicts
include_directories(
    ${Python_INCLUDE_DIRS}
    ${MPI_CXX_INCLUDE_DIRS}
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/../common
    ${MFEM_SOURCE}
    ${MFEM_SOURCE}/build
    ${MFEM_SOURCE}/build/config
    ${MFEM_SOURCE}/build/install/include
)

# Find numpy include directory
execute_process(
    COMMAND ${Python_EXECUTABLE} -c "import numpy; print(numpy.get_include())"
    OUTPUT_VARIABLE NUMPY_INCLUDE_DIR
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
include_directories(${NUMPY_INCLUDE_DIR})

# Find mpi4py include directory
execute_process(
    COMMAND ${Python_EXECUTABLE} -c "import mpi4py; print(mpi4py.get_include())"
    OUTPUT_VARIABLE MPI4PY_INCLUDE_DIR
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
)
if(MPI4PY_INCLUDE_DIR)
    include_directories(${MPI4PY_INCLUDE_DIR})
endif()

# Create SWIG modules for each interface
foreach(SWIG_INTERFACE ${SWIG_INTERFACES})
    get_filename_component(MODULE_NAME ${SWIG_INTERFACE} NAME_WE)
    
    # Skip certain modules that require special handling
    if(MODULE_NAME MATCHES "^(lininteg|bilininteg)$")
        continue()
    endif()
    
    # Skip strumpack if not enabled
    if(MODULE_NAME STREQUAL "strumpack" AND NOT ENABLE_STRUMPACK)
        continue()
    endif()
    
    # Set C++ properties before creating the library
    set_property(SOURCE ${SWIG_INTERFACE} PROPERTY CPLUSPLUS ON)
    
    swig_add_library(${MODULE_NAME}
        TYPE MODULE
        LANGUAGE python
        SOURCES ${SWIG_INTERFACE}
    )
    
    # Set target properties
    set_target_properties(${MODULE_NAME} PROPERTIES
        OUTPUT_NAME "_${MODULE_NAME}"
        PREFIX ""
        SUFFIX ".${Python_SOABI}.so"
        LINKER_LANGUAGE CXX
        CXX_STANDARD 11
        CXX_STANDARD_REQUIRED ON
        CXX_EXTENSIONS OFF
    )
    
    # Disable compiler warnings to focus on errors
    target_compile_options(${MODULE_NAME} PRIVATE -w)
    
    # Ensure SWIG-generated files are compiled as C++
    set_source_files_properties(${SWIG_INTERFACE} PROPERTIES CPLUSPLUS ON)
    
    # Force all C files in this target to be compiled as C++
    get_target_property(TARGET_SOURCES ${MODULE_NAME} SOURCES)
    foreach(SOURCE_FILE ${TARGET_SOURCES})
        if(SOURCE_FILE MATCHES ".*\\.c$")
            set_source_files_properties(${SOURCE_FILE} PROPERTIES LANGUAGE CXX)
        endif()
    endforeach()
    
    # Link against Python, MPI, and MFEM
    target_link_libraries(${MODULE_NAME} 
        Python::Module 
        ${MPI_CXX_LIBRARIES}
        ${MFEM_SOURCE}/build/libmfem.a
    )
    
    # Install the module
    # Install the compiled module
    install(TARGETS ${MODULE_NAME} 
            LIBRARY DESTINATION mfem/_par)
    
    # Install the generated Python wrapper file (SWIG generates these in the main build directory)
    install(FILES ${CMAKE_BINARY_DIR}/${MODULE_NAME}.py
            DESTINATION mfem/_par)
endforeach()

# Install Python files
file(GLOB PYTHON_FILES "${CMAKE_CURRENT_SOURCE_DIR}/*.py")
install(FILES ${PYTHON_FILES} DESTINATION mfem/_par)