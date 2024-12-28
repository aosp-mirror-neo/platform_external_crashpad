# Create the crashpad_compat library
crashpad_library(
  TARGET crashpad_compat LINUX linux/sys/mman_memfd_create.cc
  WIN32 win/strings.cc win/time.cc APPLE mac/empty.c DEPS crashpad_internal)

if(LINUX)
  target_link_libraries(crashpad_compat PUBLIC -ldl)
  target_include_directories(crashpad_compat PUBLIC non_mac non_win linux)
elseif(WIN32)
  target_include_directories(crashpad_compat PUBLIC non_mac win)
elseif(APPLE)
  target_include_directories(crashpad_compat PUBLIC non_win)
endif()
