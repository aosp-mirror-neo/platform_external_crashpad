# Copyright 2025 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Crashpad.cmake
#
# Provides functions to create Crashpad libraries and executables.
# This file defines the following functions:
#   - mig_lib: Generates and compiles MIG (Mach Interface Generator) files.
#   - android_add_library: Wrapper for add_library (shim for non-Android builds).
#   - android_add_executable: Wrapper for add_executable (shim for non-Android builds).
#   - crashpad_set_common_properties: Sets common properties for Crashpad targets.
#   - crashpad_library: Creates a Crashpad library target.
#   - crashpad_binary: Creates a Crashpad executable target.
#   - crashpad_test_module: Creates a Crashpad test module (shared library).
#   - masm_compile: Compiles MASM assembly files into object files (Windows-specific).
#   - android_find_windows_library: Wrapper for find_library on Windows.
#

# Generates Mach Interface Generator (MIG) files and compiles them into a library.
#
# This function generates C source and header files from Mach interface
# definitions using the `mig.py` script. It then compiles these generated files
# into a library.
#
# Args:
#   TARGET: The name of the library target (Required).
#   SRC: List of Mach interface definition files (.defs) (Required).
#   GENERATED: (Optional) Output variable to store the list of generated source files.
#
function(mig_lib)
  set(options)
  set(oneValueArgs TARGET)
  set(multiValueArgs SRC GENERATED)
  cmake_parse_arguments(mig "${options}" "${oneValueArgs}" "${multiValueArgs}"
                        ${ARGN})

  if(NOT mig_TARGET)
    message(FATAL_ERROR "mig_lib: TARGET is required.")
  endif()

  if(NOT mig_SRC)
    message(FATAL_ERROR "mig_lib: SRC is required.")
  endif()

  set(mig_OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR}/gen/util/mach)
  file(MAKE_DIRECTORY ${mig_OUTPUT_DIR})

  set(mig_GEN "")
  if(APPLE) # Simplifies platform check
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm64")
      set(mig_AARCH "arm")
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64")
      set(mig_AARCH "x86_64")
    else()
      message(
        FATAL_ERROR "mig_lib: Unsupported architecture on Apple platform.")
    endif()
  else()
    message(
      FATAL_ERROR "mig_lib: Only Apple platforms are currently supported.")
  endif()

  foreach(FIL ${mig_SRC})
    get_filename_component(ABS_FIL ${FIL} ABSOLUTE)
    get_filename_component(FIL_WE ${FIL} NAME_WE)

    set(OUTPUT_FILES
        "${mig_OUTPUT_DIR}/${FIL_WE}User.c"
        "${mig_OUTPUT_DIR}/${FIL_WE}Server.c" "${mig_OUTPUT_DIR}/${FIL_WE}.h"
        "${mig_OUTPUT_DIR}/${FIL_WE}Server.h")

    add_custom_command(
      OUTPUT ${OUTPUT_FILES}
      COMMAND
        ${Python_EXECUTABLE} mach/mig.py "${ABS_FIL}"
        "${mig_OUTPUT_DIR}/${FIL_WE}User.c"
        "${mig_OUTPUT_DIR}/${FIL_WE}Server.c" "${mig_OUTPUT_DIR}/${FIL_WE}.h"
        "${mig_OUTPUT_DIR}/${FIL_WE}Server.h" --sdk ${CMAKE_OSX_SYSROOT}
        --include ../.. --include ../../compat/mac --arch ${mig_AARCH}
      COMMENT "Generating mig files from ${FIL}"
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
      DEPENDS ${ABS_FIL}
      VERBATIM)

    list(APPEND mig_GEN ${OUTPUT_FILES})

    foreach(OUT_FILE ${OUTPUT_FILES})
      set_source_files_properties(${OUT_FILE} PROPERTIES GENERATED TRUE)
    endforeach()
  endforeach()

  crashpad_library(TARGET ${mig_TARGET} SRC ${mig_GEN})
  target_include_directories(${mig_TARGET}
                             PUBLIC ${CMAKE_CURRENT_BINARY_DIR}/gen)
  target_link_libraries(${mig_TARGET} PRIVATE crashpad_compat crashpad_internal)

  if(mig_GENERATED)
    set(${mig_GENERATED}
        ${mig_GEN}
        PARENT_SCOPE)
  endif()
endfunction()


# ===============================================================================
# Wrapper for add_library, a shim when building outside the Android emulator.
#
# Args:
#   TARGET: The name of the target (Required).
#   LICENSE: The license of the target (Required).
#   SHARED: If set, the target will be a shared library.
#   SRC: A list of source files.
#   DEPS: A list of private dependencies.
# ===============================================================================
if(NOT COMMAND android_add_library)
  function(android_add_library)
    set(options SHARED)
    set(oneValueArgs TARGET LICENSE)
    set(multiValueArgs DEPS SRC)
    cmake_parse_arguments(ANDROID_LIB "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    if(NOT DEFINED ANDROID_LIB_TARGET)
      message(FATAL_ERROR "TARGET must be defined for android_add_library.")
    endif()

    if(NOT DEFINED ANDROID_LIB_LICENSE)
      message(FATAL_ERROR "LICENSE must be defined for android_add_library. Target: ${ANDROID_LIB_TARGET}")
    endif()

    if(${ANDROID_LIB_SHARED})
      add_library(${ANDROID_LIB_TARGET} SHARED "")
    else()
      add_library(${ANDROID_LIB_TARGET} "")
    endif()

    if(LINUX)
      target_link_options(${ANDROID_LIB_TARGET} PRIVATE "LINKER:--build-id=sha1")
    endif()

    target_sources(${ANDROID_LIB_TARGET} PRIVATE ${ANDROID_LIB_SRC})
    target_link_libraries(${ANDROID_LIB_TARGET} PRIVATE ${ANDROID_LIB_DEPS})

  endfunction()
endif()

# ===============================================================================
# Wrapper for add_executable, a shim when building outside the Android emulator.
#
# Args:
#   TARGET: The name of the target (Required).
#   LICENSE: The license of the target (Required).
#   SRC: A list of source files.
#   DEPS: A list of private dependencies.
# ===============================================================================
if(NOT COMMAND android_add_executable)
  function(android_add_executable)
    set(options)
    set(oneValueArgs TARGET LICENSE)
    set(multiValueArgs DEPS SRC)
    cmake_parse_arguments(ANDROID_EXE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    if(NOT DEFINED ANDROID_EXE_TARGET)
      message(FATAL_ERROR "TARGET must be defined for android_add_executable.")
    endif()

    if(NOT DEFINED ANDROID_EXE_LICENSE)
      message(FATAL_ERROR "LICENSE must be defined for android_add_executable. Target: ${ANDROID_EXE_TARGET}")
    endif()

    add_executable(${ANDROID_EXE_TARGET} ${ANDROID_EXE_SRC})
    target_link_libraries(${ANDROID_EXE_TARGET} PRIVATE ${ANDROID_EXE_DEPS})

    if(LINUX)
      target_link_options(${ANDROID_EXE_TARGET} PRIVATE "LINKER:--build-id=sha1")
    endif()
  endfunction()
endif()

# ===============================================================================
# Sets common properties for Crashpad targets.
#
# This function sets the following properties:
#   - POSITION_INDEPENDENT_CODE: ON
#   - CXX_STANDARD: 20
#   - CXX_STANDARD_REQUIRED: ON
#   - CXX_EXTENSIONS: OFF
#
# Additionally, it sets platform-specific compile options:
#   - WIN32: Sets various definitions to ensure a clean Windows build.
#   - Other: Adds various warning suppressions and disables exceptions.
#
# Args:
#   target: The name of the target.
# ===============================================================================
function(crashpad_set_common_properties target)
  set_target_properties(${target} PROPERTIES POSITION_INDEPENDENT_CODE ON CXX_STANDARD 20 CXX_STANDARD_REQUIRED ON
                                             CXX_EXTENSIONS OFF)

  if(WIN32)
    target_compile_options(${target} PRIVATE "/EHs-c-")
    target_compile_definitions(
      ${target}
      PRIVATE __STD_C
              _ATL_NO_OPENGL
              _CRT_RAND_S
              _CRT_SECURE_NO_DEPRECATE
              _CRT_SECURE_NO_WARNINGS
              _HAS_EXCEPTIONS=0
              _SCL_SECURE_NO_DEPRECATE
              _SECURE_ATL
              _UNICODE
              _WIN32_WINNT=0x0A00
              _WINDOWS
              CERT_CHAIN_PARA_HAS_EXTRA_FIELDS
              CRASHPAD_ZLIB_SOURCE_EMBEDDED
              NOMINMAX
              NTDDI_VERSION=0x0A000006
              PSAPI_VERSION=2
              UNICODE
              WIN32
              WIN32_LEAN_AND_MEAN
              WINAPI_FAMILY=WINAPI_FAMILY_DESKTOP_APP
              WINVER=0x0A00)

    # Filter out compat layers on windows builds.
    get_target_property(current_link_libs ${target} LINK_LIBRARIES)
    if(current_link_libs)
      list(REMOVE_ITEM current_link_libs msvc-posix-compat)
      set_target_properties(${target} PROPERTIES LINK_LIBRARIES "${current_link_libs}")
      message(STATUS "Removed msvc-posix-compat from target: ${target}")
    endif()
  else()
    target_compile_options(${target} PRIVATE
              -Wno-missing-field-initializers
              -fno-exceptions
              -Wno-multichar
              -Wno-attributes
              -Wno-ignored-attributes
              -Wa,--noexecstack
              -Wno-non-virtual-dtor)
  endif()
endfunction()

# ===============================================================================
# Creates a Crashpad library target.
#
# This function creates a library target with the given name and sources, and
# sets common Crashpad properties using `crashpad_set_common_properties()`.
# It also adds platform-specific sources if the corresponding parameters are
# provided. It links `crashpad_compat` as a public dependency by default.
#
# Args:
#   TARGET: The name of the library target (Required).
#   SRC: A list of common source files.
#   APPLE: A list of Apple-specific source files (Optional).
#   LINUX: A list of Linux-specific source files (Optional).
#   WIN32: A list of Windows-specific source files (Optional).
#   POSIX: A list of POSIX-specific source files (for Linux and Apple) (Optional).
#   DEPS: A list of private dependencies (Optional).
# ===============================================================================
function(crashpad_library)
  cmake_parse_arguments(CRASHPAD_LIB "" "TARGET" "SRC;APPLE;LINUX;WIN32;POSIX;DEPS" ${ARGN})

  if(NOT CRASHPAD_LIB_TARGET)
    message(FATAL_ERROR "TARGET must be specified for crashpad_library")
  endif()

  if(NOT CRASHPAD_LIB_SRC AND NOT CRASHPAD_LIB_APPLE AND NOT CRASHPAD_LIB_LINUX AND NOT CRASHPAD_LIB_WIN32 AND NOT CRASHPAD_LIB_POSIX)
    message(FATAL_ERROR "At least one source file (SRC, APPLE, LINUX, WIN32, or POSIX) must be specified for crashpad_library")
  endif()


  android_add_library(TARGET ${CRASHPAD_LIB_TARGET} LICENSE "Apache-2.0" SRC ${CRASHPAD_LIB_SRC})

  crashpad_set_common_properties(${CRASHPAD_LIB_TARGET})

  if(UNIX)
    target_sources(${CRASHPAD_LIB_TARGET} PRIVATE ${CRASHPAD_LIB_POSIX})
  endif()

  if(APPLE)
    if(CRASHPAD_LIB_APPLE)
      target_sources(${CRASHPAD_LIB_TARGET} PRIVATE ${CRASHPAD_LIB_APPLE})
    endif()
  elseif(LINUX)
    if(CRASHPAD_LIB_LINUX)
      target_sources(${CRASHPAD_LIB_TARGET} PRIVATE ${CRASHPAD_LIB_LINUX})
    endif()
  elseif(WIN32)
    if(CRASHPAD_LIB_WIN32)
      target_sources(${CRASHPAD_LIB_TARGET} PRIVATE ${CRASHPAD_LIB_WIN32})
    endif()
  endif()

  if(NOT ${CRASHPAD_LIB_TARGET} STREQUAL "crashpad_compat")
    target_link_libraries(${CRASHPAD_LIB_TARGET} PUBLIC crashpad_compat)
  endif()

  if(CRASHPAD_LIB_DEPS)
    target_link_libraries(${CRASHPAD_LIB_TARGET} PRIVATE ${CRASHPAD_LIB_DEPS})
  endif()

  target_compile_definitions(${CRASHPAD_LIB_TARGET} PRIVATE DEBUG)
endfunction()

# ===============================================================================
# Creates a Crashpad executable target.
#
# This function creates an executable target with the given name and sources,
# and sets common Crashpad properties using `crashpad_set_common_properties()`.
# It also adds platform-specific sources if the corresponding parameters are
# provided.
#
# Args:
#   TARGET: The name of the executable target (Required).
#   SRC: A list of common source files.
#   APPLE: A list of Apple-specific source files (Optional).
#   LINUX: A list of Linux-specific source files (Optional).
#   WIN32: A list of Windows-specific source files (Optional).
#   POSIX: A list of POSIX-specific source files (for Linux and Apple) (Optional).
#   DEPS: A list of private dependencies (Optional).
# ===============================================================================
function(crashpad_binary)
  cmake_parse_arguments(CRASHPAD_BIN "" "TARGET" "SRC;APPLE;LINUX;WIN32;POSIX;DEPS" ${ARGN})

  if(NOT CRASHPAD_BIN_TARGET)
    message(FATAL_ERROR "TARGET must be specified for crashpad_binary")
  endif()


  if(NOT CRASHPAD_BIN_SRC AND NOT CRASHPAD_BIN_APPLE AND NOT CRASHPAD_BIN_LINUX AND NOT CRASHPAD_BIN_WIN32 AND NOT CRASHPAD_BIN_POSIX)
    message(FATAL_ERROR "At least one source file (SRC, APPLE, LINUX, WIN32, or POSIX) must be specified for crashpad_binary")
  endif()

  android_add_executable(TARGET ${CRASHPAD_BIN_TARGET} LICENSE "Apache-2.0" SRC ${CRASHPAD_BIN_SRC})
  add_custom_command(
    TARGET ${CRASHPAD_BIN_TARGET} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:${CRASHPAD_BIN_TARGET}>
            ${CMAKE_BINARY_DIR})

  crashpad_set_common_properties(${CRASHPAD_BIN_TARGET})

  if(UNIX)
    target_sources(${CRASHPAD_BIN_TARGET} PRIVATE ${CRASHPAD_BIN_POSIX})
  endif()

  if(APPLE)
    if(CRASHPAD_BIN_APPLE)
      target_sources(${CRASHPAD_BIN_TARGET} PRIVATE ${CRASHPAD_BIN_APPLE})
    endif()
  elseif(LINUX)
    if(CRASHPAD_BIN_LINUX)
      target_sources(${CRASHPAD_BIN_TARGET} PRIVATE ${CRASHPAD_BIN_LINUX})
    endif()
  elseif(WIN32)
    # Include getopt
    target_link_libraries(${CRASHPAD_BIN_TARGET} PRIVATE crashpad_getopt)
    if(CRASHPAD_BIN_WIN32)
      target_sources(${CRASHPAD_BIN_TARGET} PRIVATE ${CRASHPAD_BIN_WIN32})
    endif()
  endif()

  if(CRASHPAD_BIN_DEPS)
    target_link_libraries(${CRASHPAD_BIN_TARGET} PRIVATE ${CRASHPAD_BIN_DEPS})
  endif()
endfunction()

#===============================================================================
# Creates a Crashpad test module target.
#
# This function creates a shared library target intended for use in tests.
# It sets the appropriate properties for a test module, including:
# - Shared library type
# - Position independent code
# - C++ standard 20
# - .so suffix and empty prefix (for Unix-like systems)
#
# Args:
#   TARGET: The name of the test module target.
#   TEST: The name of the test target that this module belongs to. The function
#         will automatically add a dependency between the test target and this
#         module (optional).
#   SRC: A list of common source files.
#   APPLE: A list of Apple-specific source files (optional).
#   LINUX: A list of Linux-specific source files (optional).
#   WIN32: A list of Windows-specific source files (optional).
#   POSIX: A list of POSIX-specific source files (Linux and Apple) (optional).
#   DEPS: A list of private dependencies (optional).
#===============================================================================
function(crashpad_test_module)
  cmake_parse_arguments(CRASHPAD_TEST_MOD
    ""
    "TARGET;TEST"
    "SRC;APPLE;LINUX;WIN32;POSIX;DEPS"
    ${ARGN}
  )

  if(NOT CRASHPAD_TEST_MOD_TARGET)
    message(FATAL_ERROR "TARGET must be specified for crashpad_test_module")
  endif()

  if(NOT CRASHPAD_TEST_MOD_SRC AND NOT CRASHPAD_TEST_MOD_APPLE AND NOT CRASHPAD_TEST_MOD_LINUX AND NOT CRASHPAD_TEST_MOD_WIN32 AND NOT CRASHPAD_TEST_MOD_POSIX)
    message(FATAL_ERROR "At least one source file (SRC, APPLE, LINUX, WIN32, or POSIX) must be specified for crashpad_test_module")
  endif()

  # Use android_add_library with SHARED option to create a shared library
  android_add_library(TARGET ${CRASHPAD_TEST_MOD_TARGET} LICENSE "Apache-2.0" SHARED
                      SRC ${CRASHPAD_TEST_MOD_SRC})
  add_custom_command(
    TARGET ${CRASHPAD_TEST_MOD_TARGET} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:${CRASHPAD_TEST_MOD_TARGET}>
            ${CMAKE_BINARY_DIR})

  crashpad_set_common_properties(${CRASHPAD_TEST_MOD_TARGET})

  if (WIN32)
    set_target_properties(${CRASHPAD_TEST_MOD_TARGET} PROPERTIES
      SUFFIX ".dll"
      PREFIX ""
    )
  else()
    set_target_properties(${CRASHPAD_TEST_MOD_TARGET} PROPERTIES
      SUFFIX ".so"
      PREFIX ""
    )
  endif()

  if(CRASHPAD_TEST_MOD_DEPS)
    target_link_libraries(${CRASHPAD_TEST_MOD_TARGET} PRIVATE ${CRASHPAD_TEST_MOD_DEPS})
  endif()

  # Add platform-specific sources
  if(APPLE)
    if(CRASHPAD_TEST_MOD_APPLE)
      target_sources(${CRASHPAD_TEST_MOD_TARGET} PRIVATE ${CRASHPAD_TEST_MOD_APPLE})
    endif()
  elseif(LINUX)
    if(CRASHPAD_TEST_MOD_LINUX)
      target_sources(${CRASHPAD_TEST_MOD_TARGET} PRIVATE ${CRASHPAD_TEST_MOD_LINUX})
    endif()
  elseif(WIN32)
    if(CRASHPAD_TEST_MOD_WIN32)
      target_sources(${CRASHPAD_TEST_MOD_TARGET} PRIVATE ${CRASHPAD_TEST_MOD_WIN32})
    endif()
  endif()

  if(UNIX)
    target_sources(${CRASHPAD_TEST_MOD_TARGET} PRIVATE ${CRASHPAD_TEST_MOD_POSIX})
  endif()

  # Add dependency to the test target if TEST is specified
  if(CRASHPAD_TEST_MOD_TEST)
    add_dependencies(${CRASHPAD_TEST_MOD_TEST} ${CRASHPAD_TEST_MOD_TARGET})
  endif()
endfunction()


if(NOT COMMAND masm_compile)
  # ==============================================================================
  # Compiles MASM assembly files into object files (Windows-specific).
  #
  # This function compiles each source file (.asm) using the Microsoft Assembler
  # (MASM) into an object file (.obj). It then adds the generated object files as
  # private link dependencies to the specified target.
  #
  # Args:
  #   TARGET: The name of the target to which the compiled object files will be
  #           linked (Required).
  #   SRC: A list of MASM assembly source files (.asm) to compile.
  # ==============================================================================
  function(masm_compile)
  set(options)
  set(oneValueArgs TARGET)
  set(multiValueArgs SRC)
  cmake_parse_arguments(MASM "${options}" "${oneValueArgs}" "${multiValueArgs}"
                        ${ARGN})
  target_sources(${MASM_TARGET} PRIVATE ${OBJ_OUTPUT_PATH})
endfunction()
endif()


# ==============================================================================
# Wrapper for find_library, specifically for Windows libraries.
#
# This function serves as a helper, particularly on Windows, to locate a
# specified library and create an imported interface library target for it. This
# simplifies linking against standard Windows libraries. It tries to find a
# library. If found, it generates an interface target that other targets can link
# against.
#
# Args:
#   NAME: The base name of the library to find (e.g., "advapi32" for
#   "advapi32.lib").
# ==============================================================================
if(NOT COMMAND android_find_windows_library)
  function(android_find_windows_library NAME)
    if(NOT TARGET ${NAME}::${NAME})
      message(STATUS "Importing ${NAME}::${NAME}")
      find_library(${NAME}_LIB ${NAME})
      # Create an INTERFACE library that other targets can link against
      add_library(${NAME}::${NAME} INTERFACE IMPORTED GLOBAL)
      set_target_properties(${NAME}::${NAME} PROPERTIES INTERFACE_LINK_LIBRARIES ${${NAME}_LIB})
    endif()
  endfunction()
endif()

if(WIN32)
  set(WINDOWS_LIBS advapi32 dbghelp powrprof rpcrt4 user32 version winhttp)
  foreach(LIB ${WINDOWS_LIBS})
    android_find_windows_library(${LIB})
  endforeach()
endif()
