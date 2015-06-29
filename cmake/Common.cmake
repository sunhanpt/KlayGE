IF((CMAKE_GENERATOR MATCHES Xcode) AND (XCODE_VERSION VERSION_GREATER 4.3))
	CMAKE_MINIMUM_REQUIRED(VERSION 2.8.8 FATAL_ERROR)
ELSEIF((CMAKE_SYSTEM_NAME MATCHES WindowsStore) OR (CMAKE_SYSTEM_NAME MATCHES WindowsPhone))
	CMAKE_MINIMUM_REQUIRED(VERSION 3.1 FATAL_ERROR)
ELSE()
	CMAKE_MINIMUM_REQUIRED(VERSION 2.8.6 FATAL_ERROR)
ENDIF()

SET(CMAKE_DEBUG_POSTFIX "_d" CACHE STRING "Add a postfix, usually _d on windows")
SET(CMAKE_RELEASE_POSTFIX "" CACHE STRING "Add a postfix, usually empty on windows")
SET(CMAKE_RELWITHDEBINFO_POSTFIX "" CACHE STRING "Add a postfix, usually empty on windows")
SET(CMAKE_MINSIZEREL_POSTFIX "" CACHE STRING "Add a postfix, usually empty on windows")

FIND_PACKAGE(PythonInterp)
IF (PYTHONINTERP_FOUND)
	IF (${PYTHON_VERSION_STRING} VERSION_LESS "2.7.0")
		MESSAGE(FATAL_ERROR "Unsupported Python version. Please install Python 2.7.0 or up.")
	ENDIF()
ELSE()
	MESSAGE(FATAL_ERROR "Could NOT find Python. Please install Python 2.7.0 or up first.")
ENDIF()

FUNCTION(ADD_POST_BUILD TARGET_NAME SUBFOLDER)
	IF(SUBFOLDER STREQUAL "")
		SET(TARGET_FOLDER ${KLAYGE_BIN_DIR})
	ELSE()
		SET(TARGET_FOLDER ${KLAYGE_BIN_DIR}/${SUBFOLDER})
	ENDIF()

	ADD_CUSTOM_COMMAND(TARGET ${TARGET_NAME}
		POST_BUILD
		COMMAND ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE_DIR:${TARGET_NAME}>/$<TARGET_FILE_NAME:${TARGET_NAME}> ${TARGET_FOLDER})
ENDFUNCTION()

FUNCTION(ADD_PRECOMPILED_HEADER TARGET_NAME PRECOMPILED_HEADER PRECOMPILED_HEADER_PATH PRECOMPILED_SOURCE)
	IF(MSVC)
		ADD_MSVC_PRECOMPILED_HEADER(${TARGET_NAME} ${PRECOMPILED_HEADER} ${PRECOMPILED_SOURCE})
	ELSEIF(NOT (CMAKE_C_COMPILER_ID STREQUAL "Clang"))
		ADD_GCC_PRECOMPILED_HEADER(${TARGET_NAME} ${PRECOMPILED_HEADER} ${PRECOMPILED_HEADER_PATH})
	ENDIF()
ENDFUNCTION()

FUNCTION(ADD_MSVC_PRECOMPILED_HEADER TARGET_NAME PRECOMPILED_HEADER PRECOMPILED_SOURCE)
	IF(MSVC)
		GET_FILENAME_COMPONENT(PRECOMPILED_BASE_NAME ${PRECOMPILED_HEADER} NAME_WE)
		SET(PCHOUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_CFG_INTDIR}/${PRECOMPILED_BASE_NAME}.pch")

		SET_TARGET_PROPERTIES(${TARGET_NAME} PROPERTIES COMPILE_FLAGS "/Yu\"${PRECOMPILED_HEADER}\" /Fp\"${PCHOUTPUT}\"" OBJECT_DEPENDS "${PCHOUTPUT}")
		SET_SOURCE_FILES_PROPERTIES(${PRECOMPILED_SOURCE} PROPERTIES COMPILE_FLAGS "/Yc\"${PRECOMPILED_HEADER}\" /Fp\"${PCHOUTPUT}\"" OBJECT_OUTPUTS "${PCHOUTPUT}")
	ENDIF()
ENDFUNCTION()

FUNCTION(ADD_GCC_PRECOMPILED_HEADER TARGET_NAME PRECOMPILED_HEADER PRECOMPILED_HEADER_PATH)
	SET(CXX_COMPILE_FLAGS ${CMAKE_CXX_FLAGS})

	SET(HEADER "${PRECOMPILED_HEADER_PATH}/${PRECOMPILED_HEADER}")
	GET_FILENAME_COMPONENT(PRECOMPILED_HEADER_NAME ${HEADER} NAME)
	GET_FILENAME_COMPONENT(PRECOMPILED_HEADER_PATH ${HEADER} PATH)

	SET(OUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/${PRECOMPILED_HEADER_NAME}.gch")
	IF(CMAKE_BUILD_TYPE)
		SET(PCH_OUTPUT "${OUT_DIR}/${CMAKE_BUILD_TYPE}.c++")
		STRING(TOUPPER ${CMAKE_BUILD_TYPE} UPPER_CMAKE_BUILD_TYPE)
		LIST(APPEND CXX_COMPILE_FLAGS ${CMAKE_CXX_FLAGS_${UPPER_CMAKE_BUILD_TYPE}})
	ELSE()
		SET(PCH_OUTPUT "${OUT_DIR}/default.c++")
	ENDIF()

	ADD_CUSTOM_COMMAND(OUTPUT ${OUT_DIR}
		COMMAND ${CMAKE_COMMAND} -E make_directory ${OUT_DIR}
	)

	GET_DIRECTORY_PROPERTY(DIRECTORY_FLAGS INCLUDE_DIRECTORIES)

	SET(CURRENT_BINARY_DIR_INCLUDED_BEFORE_PATH FALSE)
	FOREACH(item ${DIRECTORY_FLAGS})
		IF(${item} STREQUAL ${PRECOMPILED_HEADER_PATH} AND NOT CURRENT_BINARY_DIR_INCLUDED_BEFORE_PATH)
			MESSAGE(FATAL_ERROR
				"This is the ADD_GCC_PRECOMPILED_HEADER function. "
				"CMAKE_CURREN_BINARY_DIR has to mentioned at INCLUDE_DIRECTORIES's argument list before ${PRECOMPILED_HEADER_PATH}, where ${PRECOMPILED_HEADER_NAME} is located"
			)
		ENDIF()

		IF(${item} STREQUAL ${CMAKE_CURRENT_BINARY_DIR})
			SET(CURRENT_BINARY_DIR_INCLUDED_BEFORE_PATH TRUE)
		ENDIF()

		LIST(APPEND CXX_COMPILE_FLAGS "-I\"${item}\"")
	ENDFOREACH(item)

	GET_DIRECTORY_PROPERTY(DIRECTORY_FLAGS DEFINITIONS)
	LIST(APPEND CXX_COMPILE_FLAGS ${DIRECTORY_FLAGS})

	SEPARATE_ARGUMENTS(CXX_COMPILE_FLAGS)

	ADD_CUSTOM_COMMAND(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${PRECOMPILED_HEADER_NAME}
		COMMAND ${CMAKE_COMMAND} -E copy ${HEADER} ${CMAKE_CURRENT_BINARY_DIR}/${PRECOMPILED_HEADER_NAME}
	)

	SET(PCHOUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${PRECOMPILED_HEADER_NAME})
	
	ADD_CUSTOM_COMMAND(OUTPUT ${PCH_OUTPUT}
		COMMAND ${CMAKE_CXX_COMPILER} ${CXX_COMPILE_FLAGS} -x c++-header -o ${PCH_OUTPUT} ${HEADER} DEPENDS ${HEADER} ${OUT_DIR} ${CMAKE_CURRENT_BINARY_DIR}/${PRECOMPILED_HEADER_NAME}
	)
	ADD_CUSTOM_TARGET(${TARGET_NAME}_gch
		DEPENDS ${PCH_OUTPUT}
	)
	ADD_DEPENDENCIES(${TARGET_NAME} ${TARGET_NAME}_gch)

	SET_TARGET_PROPERTIES(${TARGET_NAME} PROPERTIES COMPILE_FLAGS "-fpic -include ${PRECOMPILED_HEADER_NAME} -Winvalid-pch" OBJECT_DEPENDS "${PCHOUTPUT}")
ENDFUNCTION()

FUNCTION(DOWNLOAD_FILE_URL RELATIVE_PATH URL)
	SET(DEST ${KLAYGE_ROOT_DIR}/${RELATIVE_PATH})
	IF(NOT EXISTS ${DEST})
		MESSAGE(STATUS "Downloading ${URL}...")
		FILE(DOWNLOAD ${URL} ${DEST} SHOW_PROGRESS STATUS ERR)
		LIST(GET ERR 0 ERR_CODE)
		IF(ERR_CODE)
			FILE(REMOVE ${DEST})
			LIST(GET ERR 1 ERR_MSG)
			MESSAGE(FATAL_ERROR "Failed to download file ${URL}: ${ERR_MSG}")
		ENDIF()
	ENDIF()
ENDFUNCTION()

FUNCTION(DOWNLOAD_FILE RELATIVE_PATH COMMIT)
	DOWNLOAD_FILE_URL(${RELATIVE_PATH} "https://raw.githubusercontent.com/gongminmin/KlayGEDependencies/${COMMIT}/${RELATIVE_PATH}")
ENDFUNCTION()
