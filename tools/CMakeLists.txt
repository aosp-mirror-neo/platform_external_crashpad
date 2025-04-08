crashpad_library(TARGET crashpad_tool_support SRC tool_support.cc
                 DEPS crashpad_compat crashpad_internal)

crashpad_binary(
  TARGET crashpad_database_util SRC crashpad_database_util.cc
  DEPS ${ZLIB_TARGET} crashpad_client crashpad_compat crashpad_internal
       crashpad_tool_support crashpad_util)
