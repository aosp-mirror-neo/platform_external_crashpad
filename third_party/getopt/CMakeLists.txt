if(WIN32)
  crashpad_library(TARGET crashpad_getopt SRC getopt.cc)
  target_include_directories(crashpad_getopt PUBLIC .)
endif()
