# Serial MFEM Python wrapper
set(SWIG_MODULE_NAME "_ser")

# Enforce the C++17 standard required by MFEM 4.9.
set(CMAKE_CXX_STANDARD 17)
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

# Get list of SWIG interface files
file(GLOB SWIG_INTERFACES "${CMAKE_CURRENT_SOURCE_DIR}/*.i")
list(LENGTH SWIG_INTERFACES SWIG_COUNT)
message(STATUS "PyMFEM _ser: Found ${SWIG_COUNT} SWIG interface files")
foreach(INTERFACE ${SWIG_INTERFACES})
    message(STATUS "PyMFEM _ser: SWIG interface: ${INTERFACE}")
endforeach()

# Include directories for serial build
# Always use serial build directories for serial modules
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

# Add libCEED include directory if enabled
if(BUILD_LIBCEED)
    include_directories(${EXT_PREFIX}/include)
endif()

# Create SWIG modules for each interface
foreach(SWIG_INTERFACE ${SWIG_INTERFACES})
    get_filename_component(MODULE_NAME ${SWIG_INTERFACE} NAME_WE)
    message(STATUS "PyMFEM _ser: Processing SWIG module: ${MODULE_NAME}")
    
    # Note: lininteg and bilininteg need post-processing but we'll handle them normally for now
    
    # Set C++ properties before creating the library
    set_property(SOURCE ${SWIG_INTERFACE} PROPERTY CPLUSPLUS ON)
    
    # Add SWIG include directories for this interface
    set(SWIG_INCLUDE_FLAGS "-I${SWIG_LIB_DIR}/python")
    
    # Add libCEED include directory if enabled
    if(BUILD_LIBCEED)
        list(APPEND SWIG_INCLUDE_FLAGS "-I${EXT_PREFIX}/include")
    endif()
    
    set_property(SOURCE ${SWIG_INTERFACE} PROPERTY SWIG_FLAGS ${SWIG_INCLUDE_FLAGS})
    
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
        CXX_STANDARD 17
        CXX_STANDARD_REQUIRED ON
        CXX_EXTENSIONS OFF
    )
    
    # Add preprocessor definitions matching legacy setup.py
    target_compile_definitions(${MODULE_NAME} PRIVATE
        SWIG_TYPE_TABLE=PyMFEM
        TARGET_PY3=1
        NPY_NO_DEPRECATED_API=NPY_1_7_API_VERSION
    )
    
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
    # We'll update the relative path for linking after install
    set(MFEM_LIB "${MFEM_SOURCE}/build/install/lib/libmfem.${LIB_EXTENSION}")

    set(SER_LINK_LIBS Python::Module ${MFEM_LIB})
    
    # Note: libCEED is linked through libmfem.so, no need to link directly

    target_link_libraries(${MODULE_NAME} ${SER_LINK_LIBS})

    # Set rpath to find MFEM shared library in the installed location
    if(APPLE)
        set_target_properties(${MODULE_NAME} PROPERTIES
            INSTALL_RPATH "@loader_path/.dylibs"
            BUILD_WITH_INSTALL_RPATH ON
        )
    else()
        set_target_properties(${MODULE_NAME} PROPERTIES
            INSTALL_RPATH "$ORIGIN/.dylibs"
            BUILD_WITH_INSTALL_RPATH ON
        )
    endif()

    # Install the compiled module
    install(TARGETS ${MODULE_NAME} LIBRARY DESTINATION mfem/_ser)
    
    # Install the generated Python wrapper file (SWIG generates these in the main build directory)
    install(FILES ${CMAKE_BINARY_DIR}/${MODULE_NAME}.py DESTINATION mfem/_ser)
endforeach()

# Post-process lininteg and bilininteg modules (similar to legacy setup.py)
# Copy files instead of creating symlinks to avoid sdist issues
add_custom_command(TARGET lininteg POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_BINARY_DIR}/lininteg.py ${CMAKE_CURRENT_SOURCE_DIR}/../common/../_ser/lininteg.py
    COMMAND ${Python_EXECUTABLE} generate_lininteg_ext.py
    COMMAND ${CMAKE_COMMAND} -E remove ${CMAKE_CURRENT_SOURCE_DIR}/../common/../_ser/lininteg.py
    # Fix imports in generated lininteg.py to use _ser instead of _par
    COMMAND ${Python_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/../../scripts/fix_ser_imports.py ${CMAKE_BINARY_DIR}/lininteg.py
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../common
    COMMENT "Generating lininteg extensions"
)

add_custom_command(TARGET bilininteg POST_BUILD  
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_BINARY_DIR}/bilininteg.py ${CMAKE_CURRENT_SOURCE_DIR}/../common/../_ser/bilininteg.py
    COMMAND ${Python_EXECUTABLE} generate_bilininteg_ext.py
    COMMAND ${CMAKE_COMMAND} -E remove ${CMAKE_CURRENT_SOURCE_DIR}/../common/../_ser/bilininteg.py
    # Fix imports in generated bilininteg.py to use _ser instead of _par
    COMMAND ${Python_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/../../scripts/fix_ser_imports.py ${CMAKE_BINARY_DIR}/bilininteg.py
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../common
    COMMENT "Generating bilininteg extensions"
)

# Install Python files from source directory (non-generated ones)
install(FILES 
    "${CMAKE_CURRENT_SOURCE_DIR}/__init__.py"
    "${CMAKE_CURRENT_SOURCE_DIR}/setup.py"
    "${CMAKE_CURRENT_SOURCE_DIR}/tmop_modules.py"
    DESTINATION mfem/_ser)

# Install the generated Python wrapper files (SWIG generates these in the build directory)
install(FILES ${CMAKE_BINARY_DIR}/lininteg.py DESTINATION mfem/_ser OPTIONAL)
install(FILES ${CMAKE_BINARY_DIR}/bilininteg.py DESTINATION mfem/_ser OPTIONAL)

# Install the serial MFEM library to serial-specific .dylibs subdirectory
install(DIRECTORY "${MFEM_SOURCE}/build/install/lib/"
        DESTINATION mfem/_ser/.dylibs
        FILES_MATCHING PATTERN "libmfem.*"
        PATTERN "cmake" EXCLUDE)

# Install libCEED library if enabled
if(BUILD_LIBCEED)
    set(LIBCEED_LIB_INSTALL "${EXT_PREFIX}/lib/libceed.${LIB_EXTENSION}")
    install(FILES ${LIBCEED_LIB_INSTALL} DESTINATION mfem/_ser/.dylibs OPTIONAL)
endif()

# LAPACK/BLAS: Using system libraries, no installation needed

# Fix RPATH for MFEM libraries and Python extensions using external script
install(CODE "
    set(LIB_EXTENSION \"${LIB_EXTENSION}\")
    set(CMAKE_INSTALL_RPATH \"${CMAKE_INSTALL_RPATH}\")
    include(${CMAKE_CURRENT_SOURCE_DIR}/../../scripts/fix_rpath.cmake)
")
