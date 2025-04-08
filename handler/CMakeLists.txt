crashpad_library(
  TARGET crashpad_handler_lib
  SRC handler_main.cc prune_crash_reports_thread.cc user_stream_data_source.cc
  APPLE mac/crash_report_exception_handler.cc mac/exception_handler_server.cc
  LINUX linux/capture_snapshot.cc
        linux/capture_snapshot.h
        linux/crash_report_exception_handler.cc
        linux/cros_crash_report_exception_handler.cc
        linux/exception_handler_server.cc
  WIN32 win/crash_report_exception_handler.cc
  DEPS crashpad_compat
       crashpad_handler_common
       crashpad_internal
       crashpad_minidump
       crashpad_snapshot
       crashpad_tool_support
       crashpad_util)

crashpad_library(
  TARGET crashpad_handler_common
  SRC crash_report_upload_thread.cc minidump_to_upload_parameters.cc
  APPLE mac/file_limit_annotation.cc
  DEPS crashpad_client_common crashpad_compat crashpad_internal
       crashpad_snapshot crashpad_util mini_chromium)

crashpad_binary(
  TARGET crashpad_handler SRC main.cc
  DEPS crashpad_client crashpad_compat crashpad_handler_common
       crashpad_handler_lib crashpad_internal Threads::Threads)

add_custom_command(
  TARGET crashpad_handler POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:crashpad_handler>
          ${CMAKE_BINARY_DIR}/client)

if(CRASHPAD_INSTALL_HANDLER)
  install(TARGETS crashpad_handler RUNTIME DESTINATION .)
endif()

crashpad_binary(
  TARGET crashpad_handler_test
  SRC minidump_to_upload_parameters_test.cc
  WIN32 crashpad_handler_test.cc
  DEPS crashpad_googletest_main crashpad_handler_lib crashpad_internal
       crashpad_snapshot crashpad_snapshot_test_support gmock)

add_test(NAME crashpad_handler_test COMMAND crashpad_handler_test
         WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})

crashpad_binary(
  TARGET crashpad_handler_test_extended_handler
  SRC crashpad_handler_test_extended_handler.cc
  DEPS crashpad_compat crashpad_handler_lib crashpad_internal
       crashpad_minidump_test_support crashpad_tool_support mini_chromium)

if(WIN32)

  crashpad_binary(TARGET fastfail_program SRC win/fastfail_test_program.cc
                  DEPS crashpad_client crashpad_internal crashpad_util)
  target_compile_options(fastfail_program PRIVATE "/EHs-c-")
  crashpad_binary(
    TARGET crashpad_handler_com SRC main.cc
    DEPS crashpad_getopt crashpad_handler_lib crashpad_internal
         crashpad_tool_support crashpad_util)

  set_target_properties(crashpad_handler_com
                        PROPERTIES SUFFIX ".com" OUTPUT_NAME "crashpad_handler")
  target_link_options(crashpad_handler_com PRIVATE "/SUBSYSTEM:CONSOLE")
  add_custom_command(
    TARGET crashpad_handler POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:crashpad_handler_com>
            ${CMAKE_BINARY_DIR}/client)

  crashpad_binary(
    TARGET crash_other_program SRC win/crash_other_program.cc
    DEPS crashpad_client crashpad_internal crashpad_test crashpad_util gtest)

  crashpad_binary(TARGET crashy_program SRC win/crashy_test_program.cc
                  DEPS crashpad_client crashpad_internal)

  crashpad_binary(
    TARGET self_destroying_program SRC win/self_destroying_test_program.cc
    DEPS crashpad_client crashpad_internal crashpad_snapshot)

  crashpad_binary(TARGET crashy_signal SRC win/crashy_signal.cc
                  DEPS crashpad_client crashpad_internal crashpad_util)

  crashpad_binary(
    TARGET fake_handler_that_crashes_at_startup
    SRC win/fake_handler_that_crashes_at_startup.cc DEPS crashpad_internal)

  crashpad_binary(TARGET hanging_program SRC win/hanging_program.cc
                  DEPS crashpad_client crashpad_internal crashpad_util)
endif()
