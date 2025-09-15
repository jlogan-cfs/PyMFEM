# CMake script to fix RPATH for MFEM libraries and Python extensions
# This script is called during installation to fix library paths

message(STATUS "Fixing RPATH for MFEM libraries and Python extensions...")

# Find all MFEM libraries in serial and parallel .dylibs directories
file(GLOB MFEM_LIBS_SER "${CMAKE_INSTALL_PREFIX}/mfem/_ser/.dylibs/libmfem.*")
file(GLOB MFEM_LIBS_PAR "${CMAKE_INSTALL_PREFIX}/mfem/_par/.dylibs/libmfem.*")
set(MFEM_LIBS ${MFEM_LIBS_SER} ${MFEM_LIBS_PAR})

foreach(MFEM_LIB ${MFEM_LIBS})
    get_filename_component(MFEM_LIB_NAME ${MFEM_LIB} NAME)
    message(STATUS "Fixing RPATH for: ${MFEM_LIB_NAME}")
    
    if(APPLE)
        # macOS: Use install_name_tool
        execute_process(
            COMMAND install_name_tool -delete_rpath "${MFEM_SOURCE}/build/install/lib" ${MFEM_LIB}
            ERROR_QUIET
        )
        execute_process(
            COMMAND install_name_tool -delete_rpath "${MFEM_SOURCE}/build_par/install/lib" ${MFEM_LIB}
            ERROR_QUIET
        )
        # Check if CMAKE_INSTALL_RPATH already exists to avoid duplicate error
        execute_process(
            COMMAND otool -l ${MFEM_LIB}
            OUTPUT_VARIABLE OTOOL_L_OUTPUT
        )
        
        if(NOT OTOOL_L_OUTPUT MATCHES ".*${CMAKE_INSTALL_RPATH}.*")
            execute_process(
                COMMAND install_name_tool -add_rpath "${CMAKE_INSTALL_RPATH}" ${MFEM_LIB}
                RESULT_VARIABLE RPATH_RESULT
            )
            message(STATUS "  Added ${CMAKE_INSTALL_RPATH} RPATH")
        else()
            message(STATUS "  ${CMAKE_INSTALL_RPATH} RPATH already exists")
            set(RPATH_RESULT 0)
        endif()
        
        # Get the actual dependency paths from otool and fix them
        execute_process(
            COMMAND otool -L ${MFEM_LIB}
            OUTPUT_VARIABLE OTOOL_OUTPUT
        )
        
        # Debug: show the otool output to see what we're working with
        message(STATUS "  DEBUG: otool -L output:")
        string(REPLACE "\n" "\n    " DEBUG_OUTPUT "${OTOOL_OUTPUT}")
        message(STATUS "    ${DEBUG_OUTPUT}")
        
        # Process each line individually to find HYPRE and METIS dependencies
        string(REPLACE "\n" ";" OTOOL_LINES "${OTOOL_OUTPUT}")
        foreach(LINE ${OTOOL_LINES})
            string(STRIP "${LINE}" LINE)
            
            # Look for HYPRE dependency (not the mfem lib itself)
            if(LINE MATCHES ".*libHYPRE\\.${LIB_EXTENSION}.*" AND NOT LINE MATCHES ".*libmfem.*")
                string(REPLACE " (" ";" HYPRE_PARTS "${LINE}")
                list(GET HYPRE_PARTS 0 HYPRE_FULL_PATH)
                string(STRIP "${HYPRE_FULL_PATH}" HYPRE_FULL_PATH)
                # Remove leading tabs/spaces
                string(REGEX REPLACE "^[\t ]+" "" HYPRE_FULL_PATH "${HYPRE_FULL_PATH}")
                message(STATUS "  Found HYPRE dependency line: '${LINE}'")
                message(STATUS "  Extracted HYPRE path: '${HYPRE_FULL_PATH}'")
                if(NOT HYPRE_FULL_PATH STREQUAL "${CMAKE_INSTALL_RPATH}/libHYPRE.${LIB_EXTENSION}")
                    message(STATUS "  Changing HYPRE path from: '${HYPRE_FULL_PATH}' to '${CMAKE_INSTALL_RPATH}/libHYPRE.${LIB_EXTENSION}'")
                    execute_process(
                        COMMAND install_name_tool -change "${HYPRE_FULL_PATH}" "${CMAKE_INSTALL_RPATH}/libHYPRE.${LIB_EXTENSION}" ${MFEM_LIB}
                        RESULT_VARIABLE HYPRE_RESULT
                    )
                    if(HYPRE_RESULT EQUAL 0)
                        message(STATUS "  ✓ Successfully changed HYPRE path")
                    else()
                        message(STATUS "  ✗ Failed to change HYPRE path (result: ${HYPRE_RESULT})")
                    endif()
                else()
                    message(STATUS "  HYPRE path already correct")
                endif()
            endif()
            
            # Look for METIS dependency (not the mfem lib itself)
            if(LINE MATCHES ".*libmetis\\.${LIB_EXTENSION}.*" AND NOT LINE MATCHES ".*libmfem.*")
                string(REPLACE " (" ";" METIS_PARTS "${LINE}")
                list(GET METIS_PARTS 0 METIS_FULL_PATH)
                string(STRIP "${METIS_FULL_PATH}" METIS_FULL_PATH)
                # Remove leading tabs/spaces
                string(REGEX REPLACE "^[\t ]+" "" METIS_FULL_PATH "${METIS_FULL_PATH}")
                message(STATUS "  Found METIS dependency line: '${LINE}'")
                message(STATUS "  Extracted METIS path: '${METIS_FULL_PATH}'")
                if(NOT METIS_FULL_PATH STREQUAL "${CMAKE_INSTALL_RPATH}/libmetis.${LIB_EXTENSION}")
                    message(STATUS "  Changing METIS path from: '${METIS_FULL_PATH}' to '${CMAKE_INSTALL_RPATH}/libmetis.${LIB_EXTENSION}'")
                    execute_process(
                        COMMAND install_name_tool -change "${METIS_FULL_PATH}" "${CMAKE_INSTALL_RPATH}/libmetis.${LIB_EXTENSION}" ${MFEM_LIB}
                        RESULT_VARIABLE METIS_RESULT
                    )
                    if(METIS_RESULT EQUAL 0)
                        message(STATUS "  ✓ Successfully changed METIS path")
                    else()
                        message(STATUS "  ✗ Failed to change METIS path (result: ${METIS_RESULT})")
                    endif()
                else()
                    message(STATUS "  METIS path already correct")
                endif()
            endif()
        endforeach()
        
        if(RPATH_RESULT EQUAL 0)
            message(STATUS "  ✓ Successfully fixed macOS RPATH for ${MFEM_LIB_NAME}")
        else()
            message(WARNING "  ✗ Failed to fix macOS RPATH for ${MFEM_LIB_NAME}")
        endif()
        
    else()
        # Linux: Use chrpath to replace existing RPATH
        execute_process(
            COMMAND chrpath -r "${CMAKE_INSTALL_RPATH}" ${MFEM_LIB}
            RESULT_VARIABLE RPATH_RESULT
        )
        
        # Check current dependencies with ldd
        execute_process(
            COMMAND ldd ${MFEM_LIB}
            OUTPUT_VARIABLE LDD_OUTPUT
        )
        
        # Debug: show the ldd output to see what we're working with
        message(STATUS "  DEBUG: ldd output:")
        string(REPLACE "\n" "\n    " DEBUG_OUTPUT "${LDD_OUTPUT}")
        message(STATUS "    ${DEBUG_OUTPUT}")
        
        if(RPATH_RESULT EQUAL 0)
            message(STATUS "  ✓ Successfully fixed Linux RPATH for ${MFEM_LIB_NAME}")
        else()
            message(WARNING "  ✗ Failed to fix Linux RPATH for ${MFEM_LIB_NAME}")
        endif()
    endif()
endforeach()

# Fix RPATH for Python extension modules
message(STATUS "Fixing RPATH for Python extension modules...")

# Find all Python extension files in both serial and parallel directories
file(GLOB_RECURSE PYTHON_EXTS_SER "${CMAKE_INSTALL_PREFIX}/mfem/_ser/*.so")
file(GLOB_RECURSE PYTHON_EXTS_PAR "${CMAKE_INSTALL_PREFIX}/mfem/_par/*.so")

# Process all Python extensions
set(ALL_PYTHON_EXTS ${PYTHON_EXTS_SER} ${PYTHON_EXTS_PAR})

foreach(PYTHON_EXT ${ALL_PYTHON_EXTS})
    get_filename_component(EXT_NAME ${PYTHON_EXT} NAME)
    message(STATUS "Fixing Python extension RPATH: ${EXT_NAME}")
    
    # Determine if this is a serial or parallel extension to set appropriate library list
    if(PYTHON_EXT MATCHES ".*/mfem/_ser/.*")
        set(REQUIRED_LIBS "libmfem")  # Serial primarily needs MFEM
        # Add libCEED if it exists (conditional support)
        if(EXISTS "${CMAKE_INSTALL_PREFIX}/mfem/_ser/.dylibs/libceed.${LIB_EXTENSION}")
            list(APPEND REQUIRED_LIBS "libceed")
        endif()
    else()
        set(REQUIRED_LIBS "libmfem" "libHYPRE" "libmetis")  # Parallel needs MFEM, HYPRE, METIS
        # Add libCEED if it exists (conditional support)
        if(EXISTS "${CMAKE_INSTALL_PREFIX}/mfem/_par/.dylibs/libceed.${LIB_EXTENSION}")
            list(APPEND REQUIRED_LIBS "libceed")
        endif()
    endif()
    
    if(APPLE)
        # Add RPATH to appropriate .dylibs directory
        execute_process(COMMAND install_name_tool -add_rpath "${CMAKE_INSTALL_RPATH}/.dylibs" ${PYTHON_EXT} ERROR_QUIET)
        
        # Get actual dependency paths and fix them
        execute_process(COMMAND otool -L ${PYTHON_EXT} OUTPUT_VARIABLE OTOOL_OUT)
        string(REPLACE "\n" ";" OTOOL_LINES "${OTOOL_OUT}")
        
        foreach(LINE ${OTOOL_LINES})
            string(STRIP "${LINE}" LINE)
            
            # Check each required library
            foreach(LIB_BASE ${REQUIRED_LIBS})
                if(LINE MATCHES ".*${LIB_BASE}.*\\.${LIB_EXTENSION}.*" AND NOT LINE MATCHES "@.*path.*")
                    string(REPLACE " (" ";" PARTS "${LINE}")
                    list(GET PARTS 0 OLD_PATH)
                    string(STRIP "${OLD_PATH}" OLD_PATH)
                    string(REGEX REPLACE "^[\t ]+" "" OLD_PATH "${OLD_PATH}")
                    message(STATUS "  Changing ${LIB_BASE} path: ${OLD_PATH} -> ${CMAKE_INSTALL_RPATH}/.dylibs/${LIB_BASE}.${LIB_EXTENSION}")
                    execute_process(COMMAND install_name_tool -change "${OLD_PATH}" "${CMAKE_INSTALL_RPATH}/.dylibs/${LIB_BASE}.${LIB_EXTENSION}" ${PYTHON_EXT})
                endif()
            endforeach()
        endforeach()
    else()
        # Linux RPATH fixing using chrpath
        execute_process(COMMAND chrpath -r "${CMAKE_INSTALL_RPATH}/.dylibs" ${PYTHON_EXT})
        message(STATUS "  Set RPATH to ${CMAKE_INSTALL_RPATH}/.dylibs for ${EXT_NAME}")
    endif()
endforeach()

message(STATUS "RPATH fixing complete.")