# Copyright 2018 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""MIG related actions.

This file defines the `mig` rule, which generates and processes Mach Interface
Generator (MIG) files for inter-process communication on macOS/iOS. It uses `mig`
(from Xcode) to generate code from `.defs` files and then `mig_fix` to post-process
the generated files.
"""

load("@build_bazel_apple_support//lib:apple_support.bzl", "apple_support")
load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")

_mig_suffixes = {
    "user": "User.c",
    "server": "Server.c",
    "header": ".h",
    "sheader": "Server.h",
}

_migfix_order = ["user", "server", "header", "sheader"]

_migfix_fixed_parameters = {
    "user": "--fixed_user_c",
    "server": "--fixed_server_c",
    "header": "--fixed_user_h",
    "sheader": "--fixed_server_h",
}

def _mig_generate(ctx, defs_file, defs_path = None):
    """Generates MIG code from a .defs file.

    Args:
        ctx: The rule context.
        defs_file: The .defs input file as a File object. Mutually exclusive with defs_path.
        defs_path: The path to the .defs input file as a string. Mutually exclusive with defs_file.

    Returns:
        A dictionary mapping MIG output file types (user, server, header, sheader) to
        corresponding File objects.
    """
    if (defs_file and defs_path) or (defs_file == None and defs_path == None):
        fail("_mig_generate accepts exactly one of |defs_file| and |defs_path|; " +
             "%s and %s were provided." % (defs_file, defs_path))
    if defs_path == None:
        defs_path = defs_file.path
        basename = defs_file.basename
    else:
        basename = paths.basename(defs_path)

    raw_interface = {}
    target_interface = {}

    args = ["mig"]

    arch = None
    cpu = find_cpp_toolchain(ctx).cpu
    if cpu.endswith("arm64"):
        arch = "arm64"
    elif cpu.endswith("armv7"):
        arch = "armv7"
    elif cpu.endswith("x86_64"):
        arch = "x86_64"
    else:
        fail("Could not identify CPU architecture: " + cpu)
    args.extend(["-arch", arch])

    defs_name = paths.split_extension(basename)[0]

    for target, suffix in _mig_suffixes.items():
        filename = defs_name + suffix
        raw_interface[target] = ctx.actions.declare_file("raw_" + filename)
        if ctx.attr.output_dir:
            filename = paths.join(ctx.attr.output_dir, filename)
        target_interface[target] = ctx.actions.declare_file(filename)

        args.extend(["-" + target, raw_interface[target].path])

    args.extend(["-isysroot", apple_common.apple_toolchain().sdk_dir()])
    args.extend(["-I" + ctx.expand_location(include, ctx.attr.deps) for include in ctx.attr.include_dirs])
    args.append(defs_path)

    if defs_file:
        inputs = [defs_file]
    else:
        inputs = []
    apple_support.run(
        actions = ctx.actions,
        apple_fragment = ctx.fragments.apple,
        arguments = args,
        executable = "xcrun",
        execution_requirements = {"no-sandbox": "1"},
        inputs = inputs + ctx.files.included_srcs,
        mnemonic = "GenerateMachInterface",
        outputs = raw_interface.values(),
        progress_message = "Generating Mach interface: %s" % basename,
        xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
        xcode_path_resolve_level = apple_support.xcode_path_resolve_level.args,
    )

    args = [ctx.executable._migfix.path]
    for target in _migfix_order:
        args.append(raw_interface[target].path)
    for target, parameter in _migfix_fixed_parameters.items():
        args.extend([parameter, target_interface[target].path])

    ctx.actions.run_shell(
        inputs = raw_interface.values(),
        outputs = target_interface.values(),
        progress_message = "Fixing generated interface: %s" % basename,
        command = " ".join(args),
        tools = [ctx.executable._migfix],
    )

    return target_interface

def _mig_impl(ctx):
    output_files = []

    src_files = []
    hdr_files = []
    client_files = []
    server_files = []

    defs_files = depset(transitive = [src.files for src in ctx.attr.srcs])

    for defs_file in defs_files.to_list():
        result_files = _mig_generate(ctx, defs_file)
        output_files.extend(result_files.values())
        for target, result_file in result_files.items():
            if target.endswith("header"):
                hdr_files.append(result_file)
            else:
                src_files.append(result_file)

            if target.startswith("s"):
                server_files.append(result_file)
            else:
                client_files.append(result_file)
    for sdk_defs in ctx.attr.sdk_srcs:
        defs_path = "{}/{}".format(
            apple_common.apple_toolchain().sdk_dir(),
            sdk_defs,
        )
        result_files = _mig_generate(ctx, None, defs_path)
        output_files.extend(result_files.values())
        for target, result_file in result_files.items():
            if target.endswith("header"):
                hdr_files.append(result_file)
            else:
                src_files.append(result_file)

            if target.startswith("s"):
                server_files.append(result_file)
            else:
                client_files.append(result_file)

    return [
        DefaultInfo(
            files = depset(output_files),
        ),
        OutputGroupInfo(
            src_files = depset(src_files),
            hdr_files = depset(hdr_files),
            client_files = depset(client_files),
            server_files = depset(server_files),
        ),
    ]

mig = rule(
    doc = """Generates and processes MIG files.

    This rule takes MIG definition files (.defs) as input and generates C/C++ source and
    header files using the `mig` tool. It then post-processes the generated files
    using the `mig_fix` tool.

    The generated files are organized into output groups for easy access in other rules:
    - `src_files`: Contains all generated source files.
    - `hdr_files`: Contains all generated header files.
    - `client_files`: Contains generated client-side source and header files.
    - `server_files`: Contains generated server-side source and header files.


    Attributes:
        srcs: A list of MIG definition files (.defs).
        included_srcs: Additional MIG definition files (.defs). These are passed to the MIG tool,
            but are not considered outputs of this rule. This is useful for including definitions from other MIG rules.
        include_dirs: A list of include directories for the MIG tool.
        output_dir: An optional output directory for generated files. If not specified, files are placed
             in the default genfiles directory.
        deps: Dependencies required for include headers.
        sdk_srcs: A list of MIG definition files relative to the macOS SDK. This allows using system-provided
            MIG definitions.
        _cc_toolchain: The C++ toolchain to use. This is automatically determined.
        _migfix:  The mig_fix executable. This is usually provided by Crashpad.
    """,
    attrs = dicts.add(apple_support.action_required_attrs(), {
        "srcs": attr.label_list(
            allow_files = True,
            mandatory = True,
        ),
        "included_srcs": attr.label_list(
            allow_files = True,
            mandatory = False,
        ),
        "include_dirs": attr.string_list(mandatory = False),
        "output_dir": attr.string(default = ""),
        "deps": attr.label_list(mandatory = False),
        "sdk_srcs": attr.string_list(mandatory = False),
        "_cc_toolchain": attr.label(
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain"),
        ),
        "_migfix": attr.label(
            cfg = "exec",
            executable = True,
            default = Label("//util:mig_fix"),
        ),
    }),
    fragments = ["apple", "cpp"],
    implementation = _mig_impl,
    output_to_genfiles = True,
    toolchains = [
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
)
