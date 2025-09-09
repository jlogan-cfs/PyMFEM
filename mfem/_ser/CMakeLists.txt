# Serial MFEM Python wrapper
set(SWIG_MODULE_NAME "_ser")

# Enforce C++11 standard
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Enable verbose logging for debugging
message(STATUS "PyMFEM _ser: Starting serial module build")
message(STATUS "PyMFEM _ser: CMAKE_CURRENT_SOURCE_DIR = ${CMAKE_CURRENT_SOURCE_DIR}")
message(STATUS "PyMFEM _ser: CMAKE_CURRENT_BINARY_DIR = ${CMAKE_CURRENT_BINARY_DIR}")
message(STATUS "PyMFEM _ser: MFEM_SOURCE = ${MFEM_SOURCE}")
message(STATUS "PyMFEM _ser: SWIG_EXECUTABLE = ${SWIG_EXECUTABLE}")
message(STATUS "PyMFEM _ser: SWIG_LIB_DIR = ${SWIG_LIB_DIR}")

# Find required packages
find_package(PkgConfig REQUIRED)

# Set SWIG properties
# set_property(SOURCE ${CMAKE_CURRENT_SOURCE_DIR}/*.i PROPERTY CPLUSPLUS ON)
# set_property(SOURCE ${CMAKE_CURRENT_SOURCE_DIR}/*.i PROPERTY SWIG_MODULE_NAME ${SWIG_MODULE_NAME})

# Ensure all SWIG interface files are treated as C++
# foreach(SWIG_INTERFACE ${SWIG_INTERFACES})
#     set_property(SOURCE ${SWIG_INTERFACE} PROPERTY CPLUSPLUS ON)
# endforeach()

# SWIG flags inherited from parent CMakeLists.txt

# Get list of SWIG interface files
file(GLOB SWIG_INTERFACES "${CMAKE_CURRENT_SOURCE_DIR}/*.i")
list(LENGTH SWIG_INTERFACES SWIG_COUNT)
message(STATUS "PyMFEM _ser: Found ${SWIG_COUNT} SWIG interface files")
foreach(INTERFACE ${SWIG_INTERFACES})
    message(STATUS "PyMFEM _ser: SWIG interface: ${INTERFACE}")
endforeach()

# Remove problematic interfaces for serial build
# list(FILTER SWIG_INTERFACES EXCLUDE REGEX ".*/(communication|hypre|pfespace|pgridfunc|pbilinearform|plinearform|pmesh|pncmesh|pnonlinearform|prestriction|psubmesh|ptransfermap|dist_solver|enzyme|gslib|pumi|strumpack|schwarz|sidredatacollection)\.i$")

# Include directories for serial build
# Include both MFEM source (for .hpp files) and build directory (for config.hpp)
include_directories(
    ${Python_INCLUDE_DIRS}
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
message(STATUS "PyMFEM _ser: NUMPY_INCLUDE_DIR = ${NUMPY_INCLUDE_DIR}")
message(STATUS "PyMFEM _ser: Python_INCLUDE_DIRS = ${Python_INCLUDE_DIRS}")

# Check what Python version info we can get
execute_process(
    COMMAND ${Python_EXECUTABLE} -c "import sys; print(sys.version_info[:2])"
    OUTPUT_VARIABLE PYTHON_VERSION_INFO
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
execute_process(
    COMMAND ${Python_EXECUTABLE} -c "import sysconfig; print(sysconfig.get_path('include'))"
    OUTPUT_VARIABLE PYTHON_SYSCONFIG_INCLUDE
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
message(STATUS "PyMFEM _ser: Python version from executable: ${PYTHON_VERSION_INFO}")
message(STATUS "PyMFEM _ser: Python sysconfig include path: ${PYTHON_SYSCONFIG_INCLUDE}")

include_directories(${NUMPY_INCLUDE_DIR})

# Create SWIG modules for each interface
foreach(SWIG_INTERFACE ${SWIG_INTERFACES})
    get_filename_component(MODULE_NAME ${SWIG_INTERFACE} NAME_WE)
    message(STATUS "PyMFEM _ser: Processing SWIG module: ${MODULE_NAME}")
    
    # Note: lininteg and bilininteg need post-processing but we'll handle them normally for now
    
    # Set C++ properties before creating the library
    set_property(SOURCE ${SWIG_INTERFACE} PROPERTY CPLUSPLUS ON)
    
    # Add SWIG include directories for this interface
    set_property(SOURCE ${SWIG_INTERFACE} PROPERTY SWIG_FLAGS "-I${SWIG_LIB_DIR}/python")
    
    message(VERBOSE "PyMFEM _ser: Creating SWIG library for ${MODULE_NAME}")
    message(VERBOSE "PyMFEM _ser: SWIG interface source: ${SWIG_INTERFACE}")
    message(VERBOSE "PyMFEM _ser: CMAKE_SWIG_FLAGS: ${CMAKE_SWIG_FLAGS}")
    message(VERBOSE "PyMFEM _ser: SWIG_LIB_DIR: ${SWIG_LIB_DIR}")

    swig_add_library(${MODULE_NAME}
        TYPE MODULE
        LANGUAGE python
        SOURCES ${SWIG_INTERFACE}
    )
    
    message(VERBOSE "PyMFEM _ser: SWIG library ${MODULE_NAME} created")
    
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
    
    # Add preprocessor definitions matching legacy setup.py
    target_compile_definitions(${MODULE_NAME} PRIVATE
        SWIG_TYPE_TABLE=PyMFEM
        TARGET_PY3=1
        NPY_NO_DEPRECATED_API=NPY_1_7_API_VERSION
    )
    
    # Disable compiler warnings to focus on errors and ensure C++11 standard
    # target_compile_options(${MODULE_NAME} PRIVATE -std=c++11)
    
    # Debug: Show what include directories are being used for this target
    get_target_property(TARGET_INCLUDE_DIRS ${MODULE_NAME} INCLUDE_DIRECTORIES)
    message(VERBOSE "PyMFEM _ser ${MODULE_NAME}: Target include directories: ${TARGET_INCLUDE_DIRS}")
    
    # Debug: Show what compile definitions are being used
    get_target_property(TARGET_COMPILE_DEFS ${MODULE_NAME} COMPILE_DEFINITIONS)
    message(VERBOSE "PyMFEM _ser ${MODULE_NAME}: Target compile definitions: ${TARGET_COMPILE_DEFS}")
    
    # Ensure SWIG-generated files are compiled as C++
    set_source_files_properties(${SWIG_INTERFACE} PROPERTIES CPLUSPLUS ON)
    
    # Force all C files in this target to be compiled as C++
    get_target_property(TARGET_SOURCES ${MODULE_NAME} SOURCES)
    foreach(SOURCE_FILE ${TARGET_SOURCES})
        if(SOURCE_FILE MATCHES ".*\\.c$")
            set_source_files_properties(${SOURCE_FILE} PROPERTIES LANGUAGE CXX)
        endif()
    endforeach()
    
    # Link against Python and MFEM shared library
    # Platform-specific library extensions
    if(APPLE)
        set(MFEM_LIB "${MFEM_SOURCE}/build/install/lib/libmfem.dylib")
    else()
        set(MFEM_LIB "${MFEM_SOURCE}/build/install/lib/libmfem.so")
    endif()
    
    target_link_libraries(${MODULE_NAME} 
        Python::Module
        ${MFEM_LIB}
    )
    
    # Set RPATH for Linux to find libraries in .dylibs directory
    if(UNIX AND NOT APPLE)
        set_target_properties(${MODULE_NAME} PROPERTIES
            BUILD_RPATH_USE_ORIGIN ON
            INSTALL_RPATH "$ORIGIN/../.dylibs"
            BUILD_WITH_INSTALL_RPATH ON
        )
    endif()
    
    # Install the compiled module
    install(TARGETS ${MODULE_NAME} 
            LIBRARY DESTINATION mfem/_ser)
    
    # Install the generated Python wrapper file (SWIG generates these in the main build directory)
    install(FILES ${CMAKE_BINARY_DIR}/${MODULE_NAME}.py
            DESTINATION mfem/_ser)
endforeach()

# Post-process lininteg and bilininteg modules (similar to legacy setup.py)
# Use symlinks to avoid copying files to source directory
add_custom_command(TARGET lininteg POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E create_symlink ${CMAKE_BINARY_DIR}/lininteg.py ${CMAKE_CURRENT_SOURCE_DIR}/../common/../_ser/lininteg.py
    COMMAND ${Python_EXECUTABLE} generate_lininteg_ext.py
    COMMAND ${CMAKE_COMMAND} -E remove ${CMAKE_CURRENT_SOURCE_DIR}/../common/../_ser/lininteg.py
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../common
    COMMENT "Generating lininteg extensions"
)

add_custom_command(TARGET bilininteg POST_BUILD  
    COMMAND ${CMAKE_COMMAND} -E create_symlink ${CMAKE_BINARY_DIR}/bilininteg.py ${CMAKE_CURRENT_SOURCE_DIR}/../common/../_ser/bilininteg.py
    COMMAND ${Python_EXECUTABLE} generate_bilininteg_ext.py
    COMMAND ${CMAKE_COMMAND} -E remove ${CMAKE_CURRENT_SOURCE_DIR}/../common/../_ser/bilininteg.py
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../common
    COMMENT "Generating bilininteg extensions"
)

# Install Python files
file(GLOB PYTHON_FILES "${CMAKE_CURRENT_SOURCE_DIR}/*.py")
install(FILES ${PYTHON_FILES} DESTINATION mfem/_ser)

# Fix RPATHs for all installed shared libraries on macOS
if(APPLE)
    # Fix RPATH for all .so files to look in the .dylibs directory
    install(CODE "
        file(GLOB_RECURSE SHARED_LIBS \"\${CMAKE_INSTALL_PREFIX}/mfem/_ser/*.so\")
        foreach(LIB \${SHARED_LIBS})
            execute_process(COMMAND install_name_tool -add_rpath @loader_path/../.dylibs \${LIB})
            execute_process(COMMAND install_name_tool -change ${MFEM_SOURCE}/build/install/lib/libmfem.dylib @rpath/libmfem.dylib \${LIB})
        endforeach()
    ")
endif()