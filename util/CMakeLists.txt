# --- Platform-Specific Sources and Headers ---

crashpad_library(
  TARGET crashpad_util
  SRC file/delimited_file_reader.cc
      file/file_helper.cc
      file/file_io.cc
      file/file_reader.cc
      file/file_seeker.cc
      file/file_seeker.h
      file/file_writer.cc
      file/output_stream_file_writer.cc
      file/scoped_remove_file.cc
      file/string_file.cc
      misc/initialization_state_dcheck.cc
      misc/lexing.cc
      misc/lexing.h
      misc/metrics.cc
      misc/pdb_structures.cc
      misc/random_string.cc
      misc/range_set.cc
      misc/reinterpret_bytes.cc
      misc/scoped_forbid_return.cc
      misc/symbolic_constants_common.h
      misc/time.cc
      misc/uuid.cc
      misc/zlib.cc
      net/http_body.cc
      net/http_body_gzip.cc
      net/http_multipart_builder.cc
      net/http_transport.cc
      net/url.cc
      numeric/checked_address_range.cc
      process/process_memory.cc
      process/process_memory_range.cc
      stdlib/aligned_allocator.cc
      stdlib/string_number_conversion.cc
      stdlib/strlcpy.cc
      stdlib/strnlen.cc
      stream/base94_output_stream.cc
      stream/file_encoder.cc
      stream/file_output_stream.cc
      stream/log_output_stream.cc
      stream/zlib_output_stream.cc
      string/split_string.cc
      thread/thread.cc
      thread/thread_log_messages.cc
      thread/worker_thread.cc
  WIN32 file/directory_reader_win.cc
        file/file_io_win.cc
        file/filesystem_win.cc
        misc/clock_win.cc
        misc/paths_win.cc
        misc/time_win.cc
        process/process_memory_win.cc
        process/process_memory_win.h
        synchronization/semaphore_win.cc
        thread/thread_win.cc
        win/command_line.cc
        win/command_line.h
        win/critical_section_with_debug_info.cc
        win/critical_section_with_debug_info.h
        win/exception_handler_server.cc
        win/exception_handler_server.h
        win/get_function.cc
        win/get_function.h
        win/get_module_information.cc
        win/get_module_information.h
        win/handle.cc
        win/handle.h
        win/initial_client_data.cc
        win/initial_client_data.h
        win/loader_lock.cc
        win/loader_lock.h
        win/module_version.cc
        win/module_version.h
        win/nt_internals.cc
        win/nt_internals.h
        win/ntstatus_logging.cc
        win/ntstatus_logging.h
        win/process_info.cc
        win/process_info.h
        win/registration_protocol_win.cc
        win/registration_protocol_win.h
        win/scoped_handle.cc
        win/scoped_handle.h
        win/scoped_local_alloc.cc
        win/scoped_local_alloc.h
        win/scoped_process_suspend.cc
        win/scoped_process_suspend.h
        win/scoped_registry_key.h
        win/scoped_set_event.cc
        win/scoped_set_event.h
        win/session_end_watcher.cc
        win/session_end_watcher.h
  APPLE mac/launchd.mm
        mac/mac_util.cc
        mac/service_management.cc
        mac/sysctl.cc
        mac/xattr.cc
        mach/bootstrap.cc
        mach/child_port_handshake.cc
        mach/child_port_server.cc
        mach/composite_mach_message_server.cc
        mach/exc_client_variants.cc
        mach/exc_server_variants.cc
        mach/exception_behaviors.cc
        mach/exception_ports.cc
        mach/exception_types.cc
        mach/mach_extensions.cc
        mach/mach_message.cc
        mach/mach_message_server.cc
        mach/notify_server.cc
        mach/scoped_task_suspend.cc
        mach/symbolic_constants_mach.cc
        mach/task_for_pid.cc
        misc/clock_mac.cc
        misc/paths_mac.cc
        posix/process_info_mac.cc
        process/process_memory_mac.cc
        synchronization/semaphore_mac.cc
  LINUX linux/auxiliary_vector.cc
        linux/direct_ptrace_connection.cc
        linux/exception_handler_client.cc
        linux/exception_handler_protocol.cc
        linux/memory_map.cc
        linux/pac_helper.cc
        linux/proc_stat_reader.cc
        linux/proc_task_reader.cc
        linux/ptrace_broker.cc
        linux/ptrace_client.cc
        linux/ptracer.cc
        linux/scoped_pr_set_dumpable.cc
        linux/scoped_pr_set_ptracer.cc
        linux/scoped_ptrace_attach.cc
        linux/socket.cc
        linux/thread_info.cc
        misc/capture_context_linux.S
        misc/paths_linux.cc
        misc/time_linux.cc
        net/http_transport_socket.cc
        posix/process_info_linux.cc
        process/process_memory_linux.cc
        process/process_memory_sanitized.cc
  POSIX file/directory_reader_posix.cc
        file/file_io_posix.cc
        file/filesystem_posix.cc
        misc/clock_posix.cc
        posix/close_multiple.cc
        posix/close_stdio.cc
        posix/drop_privileges.cc
        posix/scoped_dir.cc
        posix/scoped_mmap.cc
        posix/signals.cc
        posix/spawn_subprocess.cc
        posix/symbolic_constants_posix.cc
        synchronization/semaphore_posix.cc
        thread/thread_posix.cc
  DEPS ${ZLIB_TARGET} crashpad_compat crashpad_internal mini_chromium)

target_compile_definitions(crashpad_util PRIVATE ZLIB_CONST
                           PUBLIC CRASHPAD_ZLIB_SOURCE_SYSTEM)

if(WIN32)
  crashpad_library(TARGET crashpad_util_win SRC misc/capture_context_win.asm
                                                win/safe_terminate_process.asm)
  if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(arm|ARM|aarch64)")
    target_sources(crashpad_util_win PRIVATE misc/capture_context_win_arm64.asm)
  endif()
  target_link_libraries(
    crashpad_util PRIVATE user32::user32 winhttp::winhttp version::version
                          crashpad_util_win)
elseif(APPLE)
  android_add_library(TARGET crashpad_util_mac_asm LICENSE "Apache-2.0"
                      SRC misc/capture_context_mac.S)
  target_compile_definitions(crashpad_util
                             PRIVATE CRASHPAD_FLOCK_ALWAYS_SUPPORTED)
  target_compile_options(
    crashpad_util
    PRIVATE "-Wno-deprecated-declarations"
            "-Wno-arc-bridge-casts-disallowed-in-nonarc"
            "-Wno-deprecated-declarations" "-Wno-vla")
  target_link_libraries(
    crashpad_util PRIVATE "-framework CoreFoundation" "-framework Foundation"
                          "-framework IOKit" crashpad_util_mac_asm)
elseif(LINUX)
  target_compile_options(crashpad_util PRIVATE "-Wno-attributes" "-Wno-vla")
  target_compile_definitions(crashpad_util PUBLIC CRASHPAD_LSS_SOURCE_EMBEDDED
                             PRIVATE CRASHPAD_FLOCK_ALWAYS_SUPPORTED)
  target_link_libraries(crashpad_util PRIVATE crypto ssl)
endif()

if(APPLE)
  mig_lib(
    TARGET crashpad_macos_mig
    SRC ${CMAKE_OSX_SYSROOT}/usr/include/mach/exc.defs
        ${CMAKE_OSX_SYSROOT}/usr/include/mach/mach_exc.defs
        ${CMAKE_OSX_SYSROOT}/usr/include/mach/notify.defs mach/child_port.defs)

  target_link_libraries(
    crashpad_util PRIVATE crashpad_macos_mig "-framework CoreFoundation"
                          "-framework Foundation" "-framework IOKit" bsm)

endif()

crashpad_library(
  TARGET crashpad_net
  SRC net/http_body.cc net/http_body_gzip.cc net/http_multipart_builder.cc
      net/http_transport.cc net/url.cc
  LINUX net/http_transport_socket.cc
  WIN32 net/http_transport_win.cc
  DEPS ${ZLIB_TARGET} crashpad_internal crashpad_util mini_chromium)
if(APPLE)
  crashpad_library(TARGET net_apple SRC net/http_transport_mac.mm
                   DEPS crashpad_internal crashpad_util)
  target_compile_options(
    net_apple PRIVATE "-fobjc-arc" "-fno-objc-arc-exceptions"
                      "-Wno-shorten-64-to-32")
  target_link_libraries(crashpad_net PRIVATE net_apple crypto)
elseif(LINUX)
  target_link_libraries(crashpad_net PRIVATE crypto)
endif()

target_compile_definitions(crashpad_net PRIVATE CRASHPAD_USE_BORINGSSL)

crashpad_binary(
  TARGET http_transport_test_server SRC net/http_transport_test_server.cc
  DEPS cpp-httplib crashpad_internal crashpad_net crashpad_tool_support
       crashpad_util mini_chromium)

crashpad_binary(
  TARGET crashpad_util_test
  SRC file/delimited_file_reader_test.cc
      file/directory_reader_test.cc
      file/file_io_test.cc
      file/file_reader_test.cc
      file/filesystem_test.cc
      file/string_file_test.cc
      misc/arraysize_test.cc
      misc/capture_context_test.cc
      misc/capture_context_test_util.h
      misc/clock_test.cc
      misc/from_pointer_cast_test.cc
      misc/initialization_state_dcheck_test.cc
      misc/initialization_state_test.cc
      misc/no_cfi_icall_test.cc
      misc/paths_test.cc
      misc/random_string_test.cc
      misc/range_set_test.cc
      misc/reinterpret_bytes_test.cc
      misc/scoped_forbid_return_test.cc
      misc/time_test.cc
      misc/uuid_test.cc
      net/http_body_gzip_test.cc
      net/http_body_test.cc
      net/http_body_test_util.cc
      net/http_body_test_util.h
      net/http_multipart_builder_test.cc
      net/http_transport_test.cc
      net/url_test.cc
      numeric/checked_address_range_test.cc
      numeric/checked_range_test.cc
      numeric/in_range_cast_test.cc
      numeric/int128_test.cc
      stdlib/aligned_allocator_test.cc
      stdlib/map_insert_test.cc
      stdlib/string_number_conversion_test.cc
      stdlib/strlcpy_test.cc
      stdlib/strnlen_test.cc
      stdlib/thread_safe_vector_test.cc
      stream/base94_output_stream_test.cc
      stream/file_encoder_test.cc
      stream/log_output_stream_test.cc
      stream/test_output_stream.cc
      stream/test_output_stream.h
      stream/zlib_output_stream_test.cc
      string/split_string_test.cc
      synchronization/scoped_spin_guard_test.cc
      synchronization/semaphore_test.cc
      thread/thread_log_messages_test.cc
      thread/thread_test.cc
      thread/worker_thread_test.cc
  POSIX posix/process_info_test.cc posix/scoped_mmap_test.cc
        posix/signals_test.cc posix/symbolic_constants_posix_test.cc
  APPLE mac/launchd_test.mm
        mac/mac_util_test.mm
        mac/service_management_test.mm
        mac/sysctl_test.cc
        mac/xattr_test.cc
        mach/bootstrap_test.cc
        mach/child_port_handshake_test.cc
        mach/child_port_server_test.cc
        mach/composite_mach_message_server_test.cc
        mach/exc_client_variants_test.cc
        mach/exc_server_variants_test.cc
        mach/exception_behaviors_test.cc
        mach/exception_ports_test.cc
        mach/exception_types_test.cc
        mach/mach_extensions_test.cc
        mach/mach_message_server_test.cc
        mach/mach_message_test.cc
        mach/notify_server_test.cc
        mach/scoped_task_suspend_test.cc
        mach/symbolic_constants_mach_test.cc
        misc/capture_context_test_util_mac.cc
        process/process_memory_mac_test.cc
  LINUX linux/auxiliary_vector_test.cc
        linux/memory_map_test.cc
        linux/proc_stat_reader_test.cc
        linux/proc_task_reader_test.cc
        linux/ptrace_broker_test.cc
        linux/ptracer_test.cc
        linux/scoped_ptrace_attach_test.cc
        linux/socket_test.cc
        misc/capture_context_test_util_linux.cc
        process/process_memory_sanitized_test.cc
  WIN32 misc/capture_context_test_util_win.cc
        win/command_line_test.cc
        win/critical_section_with_debug_info_test.cc
        win/exception_handler_server_test.cc
        win/get_function_test.cc
        win/handle_test.cc
        win/initial_client_data_test.cc
        win/loader_lock_test.cc
        win/process_info_test.cc
        win/registration_protocol_win_test.cc
        win/safe_terminate_process_test.cc
        win/scoped_process_suspend_test.cc
        win/session_end_watcher_test.cc
  DEPS ${ZLIB_TARGET}
       crashpad_compat
       crashpad_compat
       crashpad_googletest_main
       crashpad_internal
       crashpad_net
       crashpad_test
       crashpad_util
       gmock
       gtest
       mini_chromium)

if(WIN32)
  target_link_libraries(crashpad_util_test PRIVATE dbghelp::dbghelp
                                                   rpcrt4::rpcrt4)

  crashpad_binary(TARGET crashpad_util_test_process_info_test_child
                  SRC win/process_info_test_child.cc)

  crashpad_binary(TARGET crashpad_util_test_safe_terminate_process_test_child
                  SRC win/safe_terminate_process_test_child.cc)

  crashpad_test_module(
    TARGET crashpad_util_test_loader_lock_test SRC win/loader_lock_test_dll.cc
    DEPS crashpad_internal crashpad_util TEST crashpad_util_test)
endif()
add_test(NAME crashpad_util_test COMMAND crashpad_util_test
                                         "${CRASHPAD_UTIL_PARAMS}"
         WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
set_property(
  TEST crashpad_util_test APPEND
  PROPERTY ENVIRONMENT "CRASHPAD_TEST_DATA_ROOT=${CRASHPAD_TEST_DATA_ROOT}")
