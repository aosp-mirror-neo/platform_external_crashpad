# Copyright 2024 - The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the',  help='License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an',  help='AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Common compiler options and functions to compile crashpad.."""

# Keep in sync with config("unicode") from Chromium's build/config/win/BUILD.gn:
# https://source.chromium.org/chromium/chromium/src/+/main:build/config/win/BUILD.gn;l=570;drc=804d5a91d49d0ad79d3d5529e6ba2610225cfe55
CRASHPAD_WINDOWS_UNICODE_COPTS = [
    "-DUNICODE",
    "-D_UNICODE",
]

# Keep in sync with config("winver") from Chromium's build/config/win/BUILD.gn:
# https://source.chromium.org/chromium/chromium/src/+/main:build/config/win/BUILD.gn;l=287;drc=804d5a91d49d0ad79d3d5529e6ba2610225cfe55
CRASHPAD_WINDOWS_WINVER_COPTS = [
    "-DNTDDI_VERSION=0x0A000006",
    "-D_WIN32_WINNT=0x0A00",
    "-DWINVER=0x0A00",
]

# Keep in sync with config("nominmax") from Chromium's build/config/win/BUILD.gn:
# https://source.chromium.org/chromium/chromium/src/+/main:build/config/win/BUILD.gn;l=592;drc=804d5a91d49d0ad79d3d5529e6ba2610225cfe55
CRASHPAD_WINDOWS_NOMINMAX_COPTS = [
    "-DNOMINMAX",
]

# Keep in sync with config("lean_and_mean") from Chromium's build/config/win/BUILD.gn:
# https://source.chromium.org/chromium/chromium/src/+/main:build/config/win/BUILD.gn;l=582;drc=804d5a91d49d0ad79d3d5529e6ba2610225cfe55
CRASHPAD_WINDOWS_LEAN_AND_MEAN_COPTS = [
    "-DWIN32_LEAN_AND_MEAN",
]

# Keep in sync with config("runtime_library") from Chromium's build/config/win/BUILD.gn:
# https://source.chromium.org/chromium/chromium/src/+/main:build/config/win/BUILD.gn;l=216;drc=804d5a91d49d0ad79d3d5529e6ba2610225cfe55
CRASHPAD_WINDOWS_RUNTIME_LIBRARY_COPTS = [
    "-D__STD_C",
    "-D_CRT_RAND_S",
    "-D_CRT_SECURE_NO_DEPRECATE",
    "-D_SCL_SECURE_NO_DEPRECATE",
    "-D_ATL_NO_OPENGL",
    "-D_WINDOWS",
    "-DCERT_CHAIN_PARA_HAS_EXTRA_FIELDS",
    "-DPSAPI_VERSION=2",
    "-DWIN32",
    "-D_SECURE_ATL",
    "-DWINAPI_FAMILY=WINAPI_FAMILY_DESKTOP_APP",
]

# Keep in sync with config("no_exceptions") from Chromium's build/config/compiler/BUILD.gn:
# https://source.chromium.org/chromium/chromium/src/+/main:build/config/compiler/BUILD.gn;l=1862;drc=cf59bae1055c82caefd5c5f95250ee5f3b4ee05b
CRASHPAD_WINDOWS_NO_EXCEPTIONS_COPTS = [
    "-D_HAS_EXCEPTIONS=0",
]

WINDOWS_COPTS = CRASHPAD_WINDOWS_UNICODE_COPTS + CRASHPAD_WINDOWS_WINVER_COPTS + CRASHPAD_WINDOWS_NOMINMAX_COPTS + CRASHPAD_WINDOWS_LEAN_AND_MEAN_COPTS + CRASHPAD_WINDOWS_RUNTIME_LIBRARY_COPTS + CRASHPAD_WINDOWS_NO_EXCEPTIONS_COPTS + ["-DCRASHPAD_FLOCK_ALWAYS_SUPPORTED", "/std:c++20"]
LINUX_COPTS = [
    "-fno-rtti",
    "-fno-strict-aliasing",
    "-fstack-protector-all",
    "-fvisibility-inlines-hidden",
    "-fPIC",
    "-fdata-sections",
    "-ffunction-sections",
    "-std=c++20",
    "-Wno-non-virtual-dtor",
    "-fno-exceptions",
]

DEFAULT_COPTS = [
    "-Wa,--noexecstack",
    "-Wall",
    "-Wendif-labels",
    "-Wextra",
    "-Wextra-semi",
    "-Wno-missing-field-initializers",
    "-Wno-unused-parameter",
    "-Wsign-compare",
    "-Wvla",
    "-Wno-multichar",
]

CRASHPAD_COMMON_COPTS_SELECTOR = {
    "@platforms//os:windows": WINDOWS_COPTS,
    "@platforms//os:linux": DEFAULT_COPTS + LINUX_COPTS,
    "@platforms//os:macos": DEFAULT_COPTS + [
        "-std=c++20",
        "-Wno-non-virtual-dtor",
        "-fno-exceptions",
    ],
    "//conditions:default": DEFAULT_COPTS + ["-std=c++20"],
}

CRASHPAD_COMMON_COPTS = select(CRASHPAD_COMMON_COPTS_SELECTOR) + ["-DCRASHPAD_ZLIB_SOURCE_EXTERNAL"]

def cc_crashpad_test_module(name, **kwargs):
    """Builds a test module for Crashpad, handling platform-specific output.

    This rule creates a shared library suitable for loading as a test module
    into Crashpad test harnesses. It handles the platform-specific naming
    conventions for shared libraries (e.g., .so, .dll) and ensures the
    correct output is available via an alias rule that selects the appropriate
    output based on the current platform.

    Args:
        name: The name of the test module target.
        **kwargs: Additional arguments passed directly to the underlying
            `cc_binary` rule.  This allows you to specify `srcs`, `deps`,
            `copts`, etc.

    Example:

        cc_crashpad_test_module(
            name = "my_crashpad_test",
            srcs = ["my_test.cc"],
            deps = ["//some/dependency:target"],
        )
    """
    dll_name = "_%s_dll" % name
    native.cc_binary(
        name = dll_name,
        testonly = True,
        linkshared = True,
        copts = CRASHPAD_COMMON_COPTS,
        **kwargs
    )

    native.genrule(
        name = name + "_so",
        srcs = [dll_name],
        outs = [name + ".so"],
        testonly = True,
        cmd = "cp $< $(OUTS)",
        cmd_bat = "copy $< $(OUTS)",
    )

    native.genrule(
        name = name + "_dll",
        srcs = [dll_name],
        outs = [name + ".dll"],
        testonly = True,
        cmd = "cp $< $(OUTS)",
        cmd_bat = "copy $< $(OUTS)",
    )

    native.alias(
        name = name,
        actual = select({
            "@platforms//os:windows": ":" + name + "_dll",
            "//conditions:default": ":" + name + "_so",
        }),
    )

def _collect_plugins_impl(ctx):
    """Collects the location of all plugins and creates symlinks to them from an output directory.

    This function takes a list of plugin targets as input and creates symbolic
    links to their output files in the specified output directory. This allows
    the launcher to easily access the plugins without having to know their exact
    locations.

    For example:

    The plugins:
        "//external/qemu:hw-display-virtio-vga",
        "//hardware/generic/goldfish/emulator/plugin/sample",

    And output directory "plugins" will create the links:

    plugins/hw-display-virtio-vga-> //external/qemu:hw-display-virtio-vga
    plugins/sample -> //hardware/generic/goldfish/emulator/plugin/sample

    Args:
        ctx: The Bazel context object.

    Returns:
        A DefaultInfo object containing the list of symbolic links created.
    """
    deps = []
    for dep in ctx.attr.plugins:
        output_files = dep.files.to_list()
        for output in output_files:
            # Create a symbolic link for each output file in the plugins directory
            link = ctx.actions.declare_file(
                ctx.attr.output_dir + "/" + output.basename,
            )
            deps.append(link)
            ctx.actions.symlink(
                output = link,
                target_file = output,
            )

    return DefaultInfo(files = depset(deps))

collect_plugins = rule(
    implementation = _collect_plugins_impl,
    attrs = {
        "plugins": attr.label_list(
            allow_files = True,
            providers = ["files"],
            doc = "A list of plugin targets to collect. Each target should provide the 'files' provider.",
        ),
        "output_dir": attr.string(
            mandatory = True,
            doc = "The directory where the symbolic links to the plugins will be created.",
        ),
    },
    doc = """
    Collects the location of all plugins and creates symlinks to them from an output directory.

    This rule takes a list of plugin targets as input and creates symbolic
    links to their output files in the specified output directory. This allows
    the launcher to easily access the plugins without having to know their exact
    locations.

    For example:

    The plugins:
        "//external/qemu:hw-display-virtio-vga",
        "//hardware/generic/goldfish/emulator/plugin/sample",

    And output directory "plugins" will create the links:

    plugins/hw-display-virtio-vga-> //external/qemu:hw-display-virtio-vga
    plugins/sample -> //hardware/generic/goldfish/emulator/plugin/sample
    """,
)
