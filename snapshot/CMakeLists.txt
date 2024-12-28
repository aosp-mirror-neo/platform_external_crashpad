crashpad_library(
  TARGET crashpad_snapshot
  SRC annotation_snapshot.cc
      capture_memory.cc
      crashpad_info_client_options.cc
      handle_snapshot.cc
      memory_snapshot.cc
      minidump/exception_snapshot_minidump.cc
      minidump/memory_snapshot_minidump.cc
      minidump/minidump_annotation_reader.cc
      minidump/minidump_context_converter.cc
      minidump/minidump_simple_string_dictionary_reader.cc
      minidump/minidump_string_list_reader.cc
      minidump/minidump_string_reader.cc
      minidump/module_snapshot_minidump.cc
      minidump/process_snapshot_minidump.cc
      minidump/system_snapshot_minidump.cc
      minidump/thread_snapshot_minidump.cc
      unloaded_module_snapshot.cc
  APPLE mac/cpu_context_mac.cc
        mac/exception_snapshot_mac.cc
        mac/mach_o_image_annotations_reader.cc
        mac/mach_o_image_reader.cc
        mac/mach_o_image_segment_reader.cc
        mac/mach_o_image_symbol_table_reader.cc
        mac/module_snapshot_mac.cc
        mac/process_reader_mac.cc
        mac/process_snapshot_mac.cc
        mac/process_types.cc
        mac/process_types/custom.cc
        mac/system_snapshot_mac.cc
        mac/thread_snapshot_mac.cc
        posix/timezone.cc
  WIN32 crashpad_types/crashpad_info_reader.cc
        win/capture_memory_delegate_win.cc
        win/cpu_context_win.cc
        win/exception_snapshot_win.cc
        win/memory_map_region_snapshot_win.cc
        win/module_snapshot_win.cc
        win/pe_image_annotations_reader.cc
        win/pe_image_reader.cc
        win/pe_image_resource_reader.cc
        win/process_reader_win.cc
        win/process_snapshot_win.cc
        win/process_subrange_reader.cc
        win/system_snapshot_win.cc
        win/thread_snapshot_win.cc
        win/thread_snapshot_win.h
  LINUX crashpad_types/crashpad_info_reader.cc
        crashpad_types/image_annotation_reader.cc
        elf/elf_dynamic_array_reader.cc
        elf/elf_image_reader.cc
        elf/elf_symbol_table_reader.cc
        elf/module_snapshot_elf.cc
        linux/capture_memory_delegate_linux.cc
        linux/cpu_context_linux.cc
        linux/debug_rendezvous.cc
        linux/exception_snapshot_linux.cc
        linux/process_reader_linux.cc
        linux/process_snapshot_linux.cc
        linux/system_snapshot_linux.cc
        linux/thread_snapshot_linux.cc
        posix/timezone.cc
        sanitized/memory_snapshot_sanitized.cc
        sanitized/module_snapshot_sanitized.cc
        sanitized/process_snapshot_sanitized.cc
        sanitized/sanitization_information.cc
        sanitized/thread_snapshot_sanitized.cc
  DEPS crashpad_compat crashpad_context crashpad_internal crashpad_util)

if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86|x86_64|amd64|AMD64")
  target_sources(crashpad_snapshot PRIVATE x86/cpuid_reader.cc)
endif()

if(WIN32)
  target_link_libraries(crashpad_snapshot PUBLIC powrprof::powrprof)
  target_compile_options(crashpad_snapshot PRIVATE "/wd4201")
endif()

crashpad_library(TARGET crashpad_context SRC cpu_context.cc
                 DEPS crashpad_internal crashpad_util)

crashpad_library(
  TARGET crashpad_snapshot_test_support
  SRC test/test_cpu_context.cc
      test/test_exception_snapshot.cc
      test/test_memory_map_region_snapshot.cc
      test/test_memory_snapshot.cc
      test/test_module_snapshot.cc
      test/test_process_snapshot.cc
      test/test_system_snapshot.cc
      test/test_thread_snapshot.cc
  DEPS crashpad_internal crashpad_snapshot)

crashpad_binary(
  TARGET crashpad_snapshot_test
  SRC cpu_context_test.cc memory_snapshot_test.cc
      minidump/process_snapshot_minidump_test.cc
  APPLE mac/cpu_context_mac_test.cc
        mac/mach_o_image_annotations_reader_test.cc
        mac/mach_o_image_reader_test.cc
        mac/mach_o_image_segment_reader_test.cc
        mac/process_reader_mac_test.cc
        mac/process_types_test.cc
        mac/system_snapshot_mac_test.cc
        posix/timezone_test.cc
  WIN32 crashpad_types/crashpad_info_reader_test.cc
        win/cpu_context_win_test.cc
        win/exception_snapshot_win_test.cc
        win/extra_memory_ranges_test.cc
        win/module_snapshot_win_test.cc
        win/pe_image_reader_test.cc
        win/process_reader_win_test.cc
        win/process_snapshot_win_test.cc
        win/system_snapshot_win_test.cc
  LINUX crashpad_types/crashpad_info_reader_test.cc
        crashpad_types/image_annotation_reader_test.cc
        elf/elf_image_reader_test.cc
        elf/elf_image_reader_test_note.S
        linux/debug_rendezvous_test.cc
        linux/exception_snapshot_linux_test.cc
        linux/process_reader_linux_test.cc
        linux/system_snapshot_linux_test.cc
        linux/test_modules.cc
        posix/timezone_test.cc
        sanitized/process_snapshot_sanitized_test.cc
        sanitized/sanitization_information_test.cc
  DEPS crashpad_client_common
       crashpad_compat
       crashpad_context
       crashpad_googletest_main
       crashpad_handler_lib
       crashpad_internal
       crashpad_net
       crashpad_snapshot_test_support
       crashpad_test
       crashpad_util
       gmock
       gtest)

if(APPLE)
  target_link_libraries(crashpad_snapshot_test PRIVATE "-framework OpenCL")
elseif(LINUX)
  target_link_libraries(
    crashpad_snapshot_test
    PRIVATE
      "-Wl,--dynamic-list,${CMAKE_CURRENT_LIST_DIR}/elf/test_exported_symbols.sym"
  )
endif()

add_test(NAME crashpad_snapshot_test COMMAND crashpad_snapshot_test
         WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
set_property(
  TEST crashpad_snapshot_test APPEND
  PROPERTY ENVIRONMENT "CRASHPAD_TEST_DATA_ROOT=${CRASHPAD_TEST_DATA_ROOT}")

if(APPLE)
  crashpad_test_module(
    TARGET crashpad_snapshot_test_module_crashy_initializer
    TEST crashpad_snapshot_test
    APPLE mac/mach_o_image_annotations_reader_test_module_crashy_initializer.cc
    DEPS crashpad_compat crashpad_internal)
  crashpad_binary(
    TARGET crashpad_snapshot_test_no_op
    APPLE mac/mach_o_image_annotations_reader_test_no_op.cc
    DEPS crashpad_compat crashpad_internal)
endif()

crashpad_test_module(
  TARGET crashpad_snapshot_test_module TEST crashpad_snapshot_test
  SRC crashpad_info_client_options_test_module.cc DEPS crashpad_client
                                                       crashpad_compat)

crashpad_test_module(
  TARGET crashpad_snapshot_test_module_large TEST crashpad_snapshot_test
  SRC crashpad_info_size_test_module.cc DEPS crashpad_internal crashpad_util
                                             mini_chromium)

target_compile_definitions(crashpad_snapshot_test_module_large
                           PRIVATE CRASHPAD_INFO_SIZE_TEST_MODULE_LARGE)

crashpad_test_module(
  TARGET crashpad_snapshot_test_module_small TEST crashpad_snapshot_test
  SRC crashpad_info_size_test_module.cc LINUX crashpad_info_size_test_note.S
  DEPS crashpad_internal crashpad_util mini_chromium)

target_compile_definitions(crashpad_snapshot_test_module_small
                           PRIVATE CRASHPAD_INFO_SIZE_TEST_MODULE_SMALL)

if(LINUX)
  crashpad_test_module(
    TARGET crashpad_snapshot_test_both_dt_hash_styles
    TEST crashpad_snapshot_test SRC hash_types_test.cc DEPS crashpad_internal
                                                            mini_chromium)

  target_link_libraries(
    crashpad_snapshot_test_both_dt_hash_styles
    PRIVATE # This makes `ld` emit both .hash and .gnu.hash sections.
            "-Wl,--hash-style=both")
endif()

if(WIN32)
  crashpad_binary(
    TARGET crashpad_snapshot_test_annotations
    SRC win/crashpad_snapshot_test_annotations.cc
    DEPS crashpad_client crashpad_internal mini_chromium)

  target_compile_definitions(crashpad_snapshot_test_annotations PRIVATE UNICODE)

  crashpad_binary(
    TARGET crashpad_snapshot_test_crashing_child
    SRC win/crashpad_snapshot_test_crashing_child.cc
    DEPS crashpad_client crashpad_compat crashpad_internal crashpad_util
         mini_chromium)

  crashpad_binary(
    TARGET crashpad_snapshot_test_dump_without_crashing
    SRC win/crashpad_snapshot_test_dump_without_crashing.cc
    DEPS crashpad_client crashpad_compat crashpad_internal crashpad_util
         mini_chromium)

  crashpad_binary(
    TARGET crashpad_snapshot_test_extra_memory_ranges
    SRC win/crashpad_snapshot_test_extra_memory_ranges.cc
    DEPS crashpad_client crashpad_compat crashpad_internal mini_chromium)

  crashpad_binary(
    TARGET crashpad_snapshot_test_image_reader
    SRC win/crashpad_snapshot_test_image_reader.cc
    DEPS crashpad_client crashpad_compat crashpad_internal crashpad_util
         mini_chromium)

  crashpad_test_module(
    TARGET crashpad_snapshot_test_image_reader_module
    SRC win/crashpad_snapshot_test_image_reader_module.cc DEPS crashpad_client
                                                               mini_chromium)
endif()
