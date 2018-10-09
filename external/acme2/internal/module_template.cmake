############################################################################
#
# Copyright (C) 2014 BMW Car IT GmbH
#
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
############################################################################

SET(TARGET_CONTENT
    ${ACME_FILES_PRIVATE_HEADER}
    ${ACME_FILES_SOURCE}
    ${ACME_FILES_RESOURCE}
)

IF (TARGET ${ACME_NAME})
    ACME_ERROR("Target ${ACME_NAME} already exists")
ENDIF()

IF("${TARGET_CONTENT}" STREQUAL "")
    ACME_ERROR("Target ${ACME_NAME} has no files")
ENDIF()

#==============================================================================================
IF("${ACME_TYPE}" STREQUAL "STATIC_LIBRARY")
    #==============================================================================================
    ADD_LIBRARY(${ACME_NAME} STATIC ${TARGET_CONTENT})
    IF(ACME_ENABLE_INSTALL)
        INSTALL(TARGETS ${ACME_NAME} DESTINATION ${ACME_INSTALL_STATIC_LIB} COMPONENT "${ACME_PACKAGE_NAME}-devel")
        if (MSVC)
            SET_TARGET_PROPERTIES(${ACME_NAME} PROPERTIES COMPILE_PDB_NAME ${ACME_NAME})
            INSTALL(FILES $<TARGET_FILE_DIR:${ACME_NAME}>/${ACME_NAME}.pdb DESTINATION ${ACME_INSTALL_STATIC_LIB} CONFIGURATIONS Debug RelWithDebInfo)
        endif()
    ENDIF()

    #==============================================================================================
ELSEIF("${ACME_TYPE}" STREQUAL "BINARY")
    #==============================================================================================
    ADD_EXECUTABLE(${ACME_NAME} ${TARGET_CONTENT})
    set_target_properties(${ACME_NAME} PROPERTIES VS_DEBUGGER_WORKING_DIRECTORY "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")
    IF(ACME_ENABLE_INSTALL)
        INSTALL(TARGETS ${ACME_NAME} DESTINATION ${ACME_INSTALL_BINARY} COMPONENT "${ACME_PACKAGE_NAME}")
        if (MSVC)
            INSTALL(FILES $<TARGET_PDB_FILE:${ACME_NAME}> DESTINATION ${ACME_INSTALL_BINARY} CONFIGURATIONS Debug RelWithDebInfo)
        endif()
    ENDIF()

    #==============================================================================================
ELSEIF("${ACME_TYPE}" STREQUAL "TEST")
    #==============================================================================================
    LIST(FIND ACME_ALLOWED_TEST_SUFFIXES ${ACME_TEST_SUFFIX} _INDEX_OF_SUFFIX)
    IF(${_INDEX_OF_SUFFIX} EQUAL -1)
        ACME_ERROR("Your test module has invalid suffix: '${ACME_TEST_SUFFIX}'")
    ENDIF()

    ADD_EXECUTABLE(${ACME_NAME} ${TARGET_CONTENT})
    set_target_properties(${ACME_NAME} PROPERTIES VS_DEBUGGER_WORKING_DIRECTORY "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")

    ADD_TEST(
        NAME "${ACME_NAME}_${ACME_TEST_SUFFIX}"
        COMMAND ${ACME_NAME} --gtest_output=xml:TestResult_${ACME_NAME}.xml
        WORKING_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}
        )

    # TODO(tobias) stay compatible: tests are always installed when they are built
    INSTALL(TARGETS ${ACME_NAME} DESTINATION ${ACME_INSTALL_BINARY} COMPONENT "${ACME_PACKAGE_NAME}")
    if (MSVC)
        INSTALL(FILES $<TARGET_PDB_FILE:${ACME_NAME}> DESTINATION ${ACME_INSTALL_BINARY} CONFIGURATIONS Debug RelWithDebInfo)
    endif()

    #==============================================================================================
ELSEIF("${ACME_TYPE}" STREQUAL "SHARED_LIBRARY")
    #==============================================================================================
    ADD_LIBRARY(${ACME_NAME} SHARED ${TARGET_CONTENT})
    IF(ACME_ENABLE_INSTALL)
        INSTALL(TARGETS ${ACME_NAME} DESTINATION ${ACME_INSTALL_SHARED_LIB} COMPONENT "${ACME_PACKAGE_NAME}")
        if (MSVC)
            INSTALL(FILES $<TARGET_PDB_FILE:${ACME_NAME}> DESTINATION ${ACME_INSTALL_SHARED_LIB} CONFIGURATIONS Debug RelWithDebInfo)
        endif()
    ENDIF()

    #==============================================================================================
ELSEIF()
    #==============================================================================================
    ACME_ERROR("Your module has invalid type '${ACME_TYPE}'")
ENDIF()

#==============================================================================================
# set common ACME2 project properties
#==============================================================================================
IF(TARGET ${ACME_NAME})
    SET_PROPERTY(TARGET ${ACME_NAME} PROPERTY LINKER_LANGUAGE     CXX)
    SET_PROPERTY(TARGET ${ACME_NAME} PROPERTY VERSION             ${ACME_VERSION})

    # extract and set folder name from path
    STRING(REGEX REPLACE "${CMAKE_SOURCE_DIR}/" "" ACME_relative_path "${CMAKE_CURRENT_SOURCE_DIR}")
    STRING(REGEX REPLACE "/[^/]*$" "" ACME_folder_path "${ACME_relative_path}")
    SET_PROPERTY(TARGET ${ACME_NAME} PROPERTY FOLDER "${ACME_folder_path}")
ENDIF()

#==============================================================================================
# set folders for files
#==============================================================================================
FOREACH(file_iter ${TARGET_CONTENT})
    STRING(REPLACE "${CMAKE_CURRENT_SOURCE_DIR}/" "" tmp1 "${file_iter}")
    STRING(REGEX REPLACE "/[^/]*$" "" tmp2 "${tmp1}")
    STRING(REPLACE "/" "\\" module_internal_path "${tmp2}")
    SOURCE_GROUP(${module_internal_path} FILES ${file_iter})
ENDFOREACH()

#==============================================================================================
IF(DEFINED ACME_FILES_RESOURCE)
#==============================================================================================
    IF(${ACME_ENABLE_INSTALL} OR "${ACME_TYPE}" STREQUAL "TEST")
        INSTALL(FILES ${ACME_FILES_RESOURCE} DESTINATION ${ACME_INSTALL_RESOURCE} COMPONENT "${ACME_PACKAGE_NAME}")
    ENDIF()

    SET(FILES_RESOURCE_BINARYDIR "")

    FOREACH(FILE_FROM_USER ${ACME_FILES_RESOURCE})
        GET_FILENAME_COMPONENT(file "${FILE_FROM_USER}" ABSOLUTE)
        GET_FILENAME_COMPONENT(ONLY_FILENAME "${file}" NAME)

        # check if target already copied resource to this dir
        set(MUST_ADD_COPY_COMMAND TRUE)
        get_property(RESOURCE_NAMES_IN_DIRECTORY DIRECTORY "${PROJECT_BASE_DIR}" PROPERTY ACME_COPIED_RESOURCE_NAMES_TO_DIRECTORY)
        list(FIND RESOURCE_NAMES_IN_DIRECTORY "${ONLY_FILENAME}" FOUND_RES_IDX)
        if (NOT FOUND_RES_IDX EQUAL -1)
            set(MUST_ADD_COPY_COMMAND FALSE)
        endif()

        SET(TARGET_FILEPATH "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/res/${ONLY_FILENAME}")
        if (MUST_ADD_COPY_COMMAND)
            # no copy command yet, add one
            set_property(DIRECTORY "${PROJECT_BASE_DIR}" APPEND PROPERTY ACME_COPIED_RESOURCE_NAMES_TO_DIRECTORY "${ONLY_FILENAME}")
            set_property(DIRECTORY "${PROJECT_BASE_DIR}" APPEND PROPERTY ACME_COPIED_RESOURCE_PATHS_TO_DIRECTORY "${file}")

            add_custom_command(
                OUTPUT ${TARGET_FILEPATH}
                COMMAND ${CMAKE_COMMAND} -E copy_if_different "${file}" "${TARGET_FILEPATH}"
                DEPENDS "${file}"
                COMMENT "Copying ${file} -> ${TARGET_FILEPATH}"
                )
        else()
            # already copied, ensure it is the same full path and not a different file with same name
            get_property(RESOURCE_PATHS_IN_DIRECTORY DIRECTORY "${PROJECT_BASE_DIR}" PROPERTY ACME_COPIED_RESOURCE_PATHS_TO_DIRECTORY)
            list(FIND RESOURCE_PATHS_IN_DIRECTORY "${file}" FOUND_RES_IDX)
            if (FOUND_RES_IDX EQUAL -1)
                ACME_ERROR("Error: Trying to copy resource with name ${ONLY_FILENAME} from multiple different source pathes (seconds one is ${file})")
            endif()
        endif()

        LIST(APPEND FILES_RESOURCE_BINARYDIR "${TARGET_FILEPATH}")
    ENDFOREACH()

    # files are only copied if a target depends on them
    add_custom_target(RESCOPY_${ACME_NAME} DEPENDS
        ${FILES_RESOURCE_BINARYDIR}
        COMMENT "copy resource files to build folder (if changed)"
    )
    ADD_DEPENDENCIES(${ACME_NAME} RESCOPY_${ACME_NAME})

    SET_PROPERTY(TARGET RESCOPY_${ACME_NAME} PROPERTY FOLDER "CMakePredefinedTargets/ACME2_COPY_RESOURCES")
ENDIF()

#==============================================================================================
# add include dirs
#==============================================================================================
if (NOT "${ACME_INCLUDE_BASE}" STREQUAL "")
    target_include_directories(${ACME_NAME} PUBLIC "${ACME_INCLUDE_BASE}")
endif()

#==============================================================================================
# find and link dependencies
#==============================================================================================
FOREACH(DEPENDENCY ${ACME_DEPENDENCIES})

    IF(TARGET ${DEPENDENCY})
        # link target directly
        IF ("${ACME_TYPE}" STREQUAL "SHARED_LIBRARY")
            TARGET_LINK_LIBRARIES(${ACME_NAME} PRIVATE ${DEPENDENCY})
        ELSE()
            TARGET_LINK_LIBRARIES(${ACME_NAME} PUBLIC ${DEPENDENCY})
        ENDIF()

    ELSE()
        # search via find script if not _FOUND
        if (NOT ${DEPENDENCY}_FOUND)
            FIND_PACKAGE(${DEPENDENCY} QUIET)
            if (NOT ${DEPENDENCY}_FOUND)
                ACME_ERROR("required dependency '${DEPENDENCY}' not found!")
            endif()
        endif()

        # link includes and libs from vars
        if (${DEPENDENCY}_INCLUDE_DIRS)
            target_include_directories(${ACME_NAME} PUBLIC ${${DEPENDENCY}_INCLUDE_DIRS})
        endif()

        if(${DEPENDENCY}_LIBRARIES)
            target_link_libraries(${ACME_NAME} PUBLIC ${${DEPENDENCY}_LIBRARIES})
        endif()
    ENDIF()

ENDFOREACH()