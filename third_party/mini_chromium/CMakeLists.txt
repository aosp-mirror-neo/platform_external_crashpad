crashpad_library(
  TARGET mini_chromium
  SRC mini_chromium/base/debug/alias.cc
      mini_chromium/base/files/file_path.cc
      mini_chromium/base/files/scoped_file.cc
      mini_chromium/base/logging.cc
      mini_chromium/base/process/memory.cc
      mini_chromium/base/rand_util.cc
      mini_chromium/base/strings/pattern.cc
      mini_chromium/base/strings/strcat.cc
      mini_chromium/base/strings/string_number_conversions.cc
      mini_chromium/base/strings/stringprintf.cc
      mini_chromium/base/strings/utf_string_conversion_utils.cc
      mini_chromium/base/strings/utf_string_conversions.cc
      mini_chromium/base/synchronization/lock.cc
      mini_chromium/base/third_party/icu/icu_utf.cc
      mini_chromium/base/threading/thread_local_storage.cc
  WIN32 mini_chromium/base/memory/page_size_win.cc
        mini_chromium/base/scoped_clear_last_error_win.cc
        mini_chromium/base/strings/string_util_win.cc
        mini_chromium/base/synchronization/lock_impl_win.cc
        mini_chromium/base/threading/thread_local_storage_win.cc
  POSIX mini_chromium/base/files/file_util_posix.cc
        mini_chromium/base/memory/page_size_posix.cc
        mini_chromium/base/posix/safe_strerror.cc
        mini_chromium/base/synchronization/condition_variable_posix.cc
        mini_chromium/base/synchronization/lock_impl_posix.cc
        mini_chromium/base/threading/thread_local_storage_posix.cc
  APPLE mini_chromium/base/apple/foundation_util.mm
        mini_chromium/base/apple/mach_logging.cc
        mini_chromium/base/apple/scoped_mach_port.cc
        mini_chromium/base/apple/scoped_mach_vm.cc
        mini_chromium/base/apple/scoped_nsautorelease_pool.mm
        mini_chromium/base/mac/close_nocancel.cc
        mini_chromium/base/strings/sys_string_conversions_mac.mm)

target_include_directories(mini_chromium PUBLIC mini_chromium .)
target_link_libraries(mini_chromium PUBLIC absl::str_format)
# Platform-specific configurations
if(WIN32)
  target_link_libraries(mini_chromium PUBLIC advapi32::advapi32)
elseif(APPLE)
  target_compile_options(
    mini_chromium PRIVATE -Wno-arc-bridge-casts-disallowed-in-nonarc
                          -Wno-deprecated-declarations)

  # Link frameworks to base library
  target_link_libraries(
    mini_chromium
    PUBLIC "-framework CoreFoundation" "-framework Foundation"
           "-framework Security" "-framework ApplicationServices"
           "-framework IOKit")
endif()
