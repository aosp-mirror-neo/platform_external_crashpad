// Copyright (C) 2024 The Android Open Source Project
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
#include "test/bazel/bazel_info.h"

#include <iostream>
#include <memory>
#include <string_view>

#include "base/files/file_path.h"
#include "base/strings/strcat.h"
#include "base/strings/utf_string_conversions.h"

#include "tools/cpp/runfiles/runfiles.h"

namespace crashpad {
namespace test {

using ::bazel::tools::cpp::runfiles::Runfiles;

std::vector<std::string> g_argv;
base::FilePath Bazel::runfilesPath(const std::string& path) {
  std::string error;
  std::string location;
  const char* workspace_dir = getenv("TEST_WORKSPACE");

  if (workspace_dir == nullptr || workspace_dir[0] == '\0') {
    std::string arg0 = g_argv.empty() ? "" : g_argv[0];
    std::unique_ptr<Runfiles> runfiles(
        Runfiles::Create(arg0, BAZEL_CURRENT_REPOSITORY, &error));
    if (!runfiles) {
      std::cerr << "Unable to create runfiles: " << error;
    }
    location = runfiles->Rlocation(path);
  } else {
    std::unique_ptr<Runfiles> runfiles(
        Runfiles::CreateForTest(BAZEL_CURRENT_REPOSITORY, &error));
    std::string workspace = workspace_dir;

    // Bazel's `TEST_TARGET` environment variable may contain a canonical label
    // when using `local_repository` to add a subproject. This code extracts the
    // intended workspace name from `TEST_TARGET` if it's in the format
    // "@@<workspace>//<target>".
    //
    // Example:
    //   If a `local_repository` rule like the following is used:
    //     local_repository(
    //       name = "com_google_crashpad",
    //       path = "external/crashpad",
    //     )
    //
    // Then `workspace` should be set to "com_google_crashpad" when using
    // the sibling layout. Unfortunately `TEST_WORKSPACE` will be "_main"
    // and we will not be able to find the proper data files using it.
    // To work around this, we extract the sibling repository name from the
    // `TEST_TARGET` environment variable (which will have the format
    // "@@<workspace>//<target>") when present (i.e. when using `bazel run` and
    // `bazel test`).

    const char* test_target = getenv("TEST_TARGET");
    if (test_target != nullptr) {
      std::string_view test_target_view(test_target);
      if (test_target_view.starts_with("@@")) {
        size_t double_slash_pos = test_target_view.find("//");

        if (double_slash_pos != std::string_view::npos) {
          workspace =
              std::string(test_target_view.substr(2, double_slash_pos - 2));
        }
      }
    }
    location = runfiles->Rlocation(base::StrCat({workspace, "/", path}));
  }
#if !BUILDFLAG(IS_WIN)
  return base::FilePath(base::StrCat({location, "/", ".."}));
#else
  return base::FilePath(base::UTF8ToWide(base::StrCat({location, "\\", ".."})));
#endif
}

void Bazel::storeCommandLineArgs(int argc, char** argv) {
  g_argv.clear();
  for (int i = 0; i < argc; ++i) {
    g_argv.push_back(argv[i]);
  }
}

bool Bazel::inBazel() {
  using namespace std::literals::string_view_literals;
  std::array<std::string_view, 3> markers = {
      "BUILD_WORKING_DIRECTORY"sv,
      "TEST_BINARY"sv,
      "RUNFILES_DIR"sv,
  };

#if !BUILDFLAG(IS_WIN)
  for (const auto& marker : markers) {
    if (getenv(marker.data()) != nullptr) {
      return true;
    }
  }
#else
  for (const auto& marker : markers) {
    std::wstring wideMarker = base::UTF8ToWide(marker);
    if (_wgetenv(wideMarker.c_str()) != nullptr) {
      return true;
    }
  }
#endif

  return false;
}

}  // namespace test
}  // namespace crashpad
