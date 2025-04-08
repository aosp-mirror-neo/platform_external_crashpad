# Add the crashpad_test library
crashpad_library(
  TARGET crashpad_test
  SRC errors.cc
      file.cc
      filesystem.cc
      hex_string.cc
      main_arguments.cc
      multiprocess_exec.cc
      process_type.cc
      scoped_module_handle.cc
      scoped_temp_dir.cc
      test_paths.cc
  APPLE mac/dyld.cc
        mac/exception_swallower.cc
        mac/mach_errors.cc
        mac/mach_multiprocess.cc
        multiprocess_exec_posix.cc # posix version on macOS
        multiprocess_posix.cc # posix version on macOS
        scoped_guarded_page_posix.cc # posix version on macOS
        scoped_set_thread_name_posix.cc # posix version on macOS
        scoped_temp_dir_posix.cc # posix version on macOS
  LINUX linux/fake_ptrace_connection.cc
        linux/get_tls.cc
        multiprocess_exec_posix.cc
        multiprocess_posix.cc
        scoped_guarded_page_posix.cc
        scoped_set_thread_name_posix.cc
        scoped_temp_dir_posix.cc
  WIN32 multiprocess_exec_win.cc
        scoped_guarded_page_win.cc
        scoped_set_thread_name_win.cc
        scoped_temp_dir_win.cc
        win/child_launcher.cc
        win/win_child_process.cc
        win/win_multiprocess.cc
        win/win_multiprocess_with_temp_dir.cc
  DEPS crashpad_compat crashpad_handler_lib crashpad_internal crashpad_util
       gtest mini_chromium)

# Link options and dependencies (note the change to target_link_libraries)
if(APPLE)
  target_link_libraries(crashpad_test PRIVATE "-framework IOKit" "-lbsm")
endif()

file(COPY "test_paths_test_data_root.txt"
     DESTINATION "${CMAKE_CURRENT_BINARY_DIR}/test")

crashpad_library(
  TARGET crashpad_googletest_main SRC gtest_main.cc
  DEPS crashpad_compat crashpad_internal crashpad_test gmock gtest
       mini_chromium)

target_compile_definitions(crashpad_googletest_main
                           PRIVATE CRASHPAD_TEST_LAUNCHER_GOOGLETEST)

crashpad_binary(
  TARGET crashpad_test_test_multiprocess_exec_test_child
  SRC multiprocess_exec_test_child.cc DEPS crashpad_compat crashpad_internal
                                           mini_chromium)

crashpad_binary(
  TARGET crashpad_test_test
  SRC hex_string_test.cc main_arguments_test.cc multiprocess_exec_test.cc
      scoped_guarded_page_test.cc scoped_temp_dir_test.cc test_paths_test.cc
  POSIX multiprocess_posix_test.cc
  DEPS crashpad_compat crashpad_googletest_main crashpad_internal crashpad_test
       gtest)
add_dependencies(crashpad_test_test
                 crashpad_test_test_multiprocess_exec_test_child)

add_test(NAME crashpad_test_test COMMAND crashpad_test_test
         WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
