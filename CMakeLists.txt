cmake_minimum_required(VERSION 3.20)
project(com_google_crashpad VERSION 0.8.0 LANGUAGES ASM C CXX)
if(WIN32)
  enable_language(ASM_MASM)
endif()

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

include(Crashpad)
include(CPM)

option(CRASHPAD_INSTALL_HANDLER "Install the crashpad handler" ON)

# Don't fetch BoringSSL  if target `crypto` is already defined.
if(NOT TARGET crypto AND NOT WIN32)
  # Release from 2024-12-09
  cpmaddpackage("gh:google/boringssl#0.20241209.0")
  # BoringSSL targets do not carry include directory info, this fixes it.
  target_include_directories(
    crypto PUBLIC "$<BUILD_INTERFACE:${boringssl_SOURCE_DIR}/src/include>")
else()
  message(STATUS "Using an already declared `crypto` target")
endif()

if(NOT TARGET Threads::Threads)
  find_package(Threads REQUIRED)
endif()

set(ZLIB_TARGET zlib)
if(NOT TARGET ${ZLIB_TARGET})
  find_package(ZLIB)
  if(ZLIB_FOUND)
    set(ZLIB_TARGET ZLIB::ZLIB)
  else()
    cpmaddpackage("gh:madler/zlib@1.2.13")
    # zlib targets do not carry include directory info, this fixes it.
    target_include_directories(
      zlibstatic PUBLIC "$<BUILD_INTERFACE:${zlib_SOURCE_DIR}>"
                        "$<BUILD_INTERFACE:${zlib_BINARY_DIR}>")
    set(ZLIB_TARGET zlibstatic)
  endif()
endif()

# Don't fetch GoogleTest if the target `gtest` is already defined
if(NOT TARGET gtest)
  cpmaddpackage("gh:google/googletest@1.15.2")

  target_include_directories(
    gtest PUBLIC "$<BUILD_INTERFACE:${/googletest_SOURCE_DIR}>"
                 "$<BUILD_INTERFACE:${/googletest_BINARY_DIR}>")
  target_include_directories(
    gmock PUBLIC "$<BUILD_INTERFACE:${/googletest_SOURCE_DIR}>"
                 "$<BUILD_INTERFACE:${/googletest_BINARY_DIR}>")
endif()


if(NOT TARGET absl::str_format)
    CPMAddPackage(
        NAME abseil-cpp
        GIT_REPOSITORY "https://github.com/abseil/abseil-cpp.git"
        GIT_TAG "20250512.1"  # This is the latest LTS release (May 2025)
        OPTIONS
            "BUILD_TESTING OFF"
            "ABSL_BUILD_TESTING OFF"
            "ABSL_ENABLE_INSTALL OFF"
    )
endif()


enable_testing()
set(CRASHPAD_ROOT ${CMAKE_CURRENT_LIST_DIR})
if(WIN32)
  string(REPLACE "/" "\\" CRASHPAD_TEST_DATA_ROOT "${CRASHPAD_ROOT}")
else()
  set(CRASHPAD_TEST_DATA_ROOT "${CRASHPAD_ROOT}")
endif()

add_library(crashpad_internal INTERFACE)
target_include_directories(crashpad_internal INTERFACE .)
target_link_libraries(crashpad_internal INTERFACE mini_chromium
                                                  Threads::Threads)

add_subdirectory(third_party/mini_chromium)
add_subdirectory(third_party/cpp-httplib)
add_subdirectory(third_party/getopt)
add_subdirectory(client)
add_subdirectory(compat)
add_subdirectory(handler)
add_subdirectory(minidump)
add_subdirectory(snapshot)
add_subdirectory(test)
add_subdirectory(tools)
add_subdirectory(util)
