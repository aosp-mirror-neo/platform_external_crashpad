crashpad_library(
  TARGET crashpad_minidump_format SRC minidump_extensions.cc
  DEPS crashpad_compat crashpad_internal crashpad_snapshot crashpad_util)

crashpad_library(
  TARGET crashpad_minidump
  SRC minidump_annotation_writer.cc
      minidump_byte_array_writer.cc
      minidump_context_writer.cc
      minidump_crashpad_info_writer.cc
      minidump_exception_writer.cc
      minidump_file_writer.cc
      minidump_handle_writer.cc
      minidump_memory_info_writer.cc
      minidump_memory_writer.cc
      minidump_misc_info_writer.cc
      minidump_module_crashpad_info_writer.cc
      minidump_module_writer.cc
      minidump_rva_list_writer.cc
      minidump_simple_string_dictionary_writer.cc
      minidump_stream_writer.cc
      minidump_string_writer.cc
      minidump_system_info_writer.cc
      minidump_thread_id_map.cc
      minidump_thread_name_list_writer.cc
      minidump_thread_writer.cc
      minidump_unloaded_module_writer.cc
      minidump_user_extension_stream_data_source.cc
      minidump_user_stream_writer.cc
      minidump_writable.cc
      minidump_writer_util.cc
  DEPS crashpad_compat crashpad_context crashpad_internal
       crashpad_minidump_format crashpad_snapshot crashpad_util)

target_compile_definitions(crashpad_minidump PRIVATE NDEBUG)

crashpad_library(
  TARGET crashpad_minidump_test_support
  SRC test/minidump_byte_array_writer_test_util.cc
      test/minidump_context_test_util.cc
      test/minidump_file_writer_test_util.cc
      test/minidump_memory_writer_test_util.cc
      test/minidump_rva_list_test_util.cc
      test/minidump_string_writer_test_util.cc
      test/minidump_user_extension_stream_util.cc
      test/minidump_writable_test_util.cc
  DEPS crashpad_internal crashpad_minidump crashpad_snapshot crashpad_test
       crashpad_util gmock)

crashpad_binary(
  TARGET crashpad_minidump_test
  SRC minidump_annotation_writer_test.cc
      minidump_byte_array_writer_test.cc
      minidump_context_writer_test.cc
      minidump_crashpad_info_writer_test.cc
      minidump_exception_writer_test.cc
      minidump_file_writer_test.cc
      minidump_handle_writer_test.cc
      minidump_memory_info_writer_test.cc
      minidump_memory_writer_test.cc
      minidump_misc_info_writer_test.cc
      minidump_module_crashpad_info_writer_test.cc
      minidump_module_writer_test.cc
      minidump_rva_list_writer_test.cc
      minidump_simple_string_dictionary_writer_test.cc
      minidump_string_writer_test.cc
      minidump_system_info_writer_test.cc
      minidump_thread_id_map_test.cc
      minidump_thread_name_list_writer_test.cc
      minidump_thread_writer_test.cc
      minidump_unloaded_module_writer_test.cc
      minidump_user_stream_writer_test.cc
      minidump_writable_test.cc
  DEPS crashpad_googletest_main
       crashpad_handler_lib
       crashpad_internal
       crashpad_minidump_test_support
       crashpad_snapshot_test_support
       gmock
       mini_chromium)

add_test(NAME crashpad_minidump_test COMMAND crashpad_minidump_test
         WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
