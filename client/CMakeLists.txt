#===============================================================================
# Target: crashpad_client_common
#===============================================================================
crashpad_library(
  TARGET crashpad_client_common
  SRC annotation.cc annotation_list.cc crash_report_database.cc crashpad_info.cc
      settings.cc
  APPLE crash_report_database_mac.mm
  LINUX crash_report_database_generic.cc crashpad_info_note.S
        pthread_create_linux.cc
  WIN32 crash_report_database_win.cc
  DEPS crashpad_internal crashpad_net crashpad_util mini_chromium Threads::Threads)

target_compile_definitions(crashpad_client_common
                           PUBLIC CRASHPAD_FLOCK_ALWAYS_SUPPORTED=true)

# ===============================================================================
# Target: crashpad_client
# ===============================================================================
crashpad_library(
  TARGET crashpad_client
  SRC prune_crash_reports.cc
  APPLE crashpad_client_mac.cc simulate_crash_mac.cc
  LINUX client_argv_handling.cc crashpad_client_linux.cc
  WIN32 crashpad_client_win.cc
  DEPS crashpad_client_common crashpad_internal crashpad_util Threads::Threads)

target_link_libraries(crashpad_client PUBLIC mini_chromium crashpad_internal)

if (WIN32)
  target_link_libraries(crashpad_client PRIVATE rpcrt4::rpcrt4)
endif()

# Circular dependency required for crashpad::CrashpadClient::InitializeSignalStackForThread
target_link_libraries(crashpad_client_common PRIVATE crashpad_client)

# ===============================================================================
# Target: crashpad_client_test
# ===============================================================================
crashpad_binary(
  TARGET crashpad_client_test
  SRC annotation_list_test.cc
      annotation_test.cc
      crash_report_database_test.cc
      length_delimited_ring_buffer_test.cc
      prune_crash_reports_test.cc
      settings_test.cc
      simple_address_range_bag_test.cc
      simple_string_dictionary_test.cc
  APPLE simulate_crash_mac_test.cc
  LINUX crashpad_client_linux_test.cc
  WIN32 crashpad_client_win_test.cc
  DEPS crashpad_client
       crashpad_googletest_main
       crashpad_handler_lib
       crashpad_internal
       crashpad_test
       crashpad_util
       gmock)

# ===============================================================================
# Test: crashpad_client_test
# ===============================================================================
add_test(NAME crashpad_client_test COMMAND crashpad_client_test
         WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
