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

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")

_MIG_TOOLCHAIN_TYPE = "@//build/bazel/toolchains/cc/mac_clang:mig_toolchain_type"

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

def _mig_generate(ctx, defs_file, mig, cc, cc_env, cc_toolchain):
    """Generates MIG code from a .defs file.

    Args:
        ctx: The rule context.
        defs_file: The .defs input file as a File object.
        mig: The mig toolchain info.
        cc: The path to c compiler.
        cc_env: Environment variables for the cc action.
        cc_toolchain: The current cc toolchain.

    Returns:
        A dictionary mapping MIG output file types (user, server, header, sheader) to
        corresponding File objects.
    """
    defs_path = defs_file.path
    basename = defs_file.basename

    defs_name = paths.split_extension(basename)[0]

    raw_interface = {}
    target_interface = {}
    for target, suffix in _mig_suffixes.items():
        filename = defs_name + suffix
        raw_interface[target] = ctx.actions.declare_file("raw_" + filename)
        if ctx.attr.output_dir:
            filename = paths.join(ctx.attr.output_dir, filename)
        target_interface[target] = ctx.actions.declare_file(filename)

    args = []
    args.extend(mig.args)
    args.extend(["-cc", cc])
    for target, raw_file in raw_interface.items():
        args.extend(["-" + target, raw_file.path])
    if cc_toolchain.sysroot:
        args.extend(["-isysroot", cc_toolchain.sysroot])
    args.extend(["-I" + ctx.expand_location(include, ctx.attr.deps) for include in ctx.attr.include_dirs])
    args.append(defs_path)

    ctx.actions.run(
        arguments = args,
        executable = mig.executable,
        tools = mig.runfiles + [cc_toolchain.all_files],
        inputs = [defs_file] + ctx.files.included_srcs,
        env = cc_env | mig.env,
        mnemonic = "GenerateMachInterface",
        outputs = raw_interface.values(),
        progress_message = "Generating Mach interface: %s" % basename,
        toolchain = _MIG_TOOLCHAIN_TYPE,
    )

    args = []
    for target in _migfix_order:
        args.append(raw_interface[target].path)
    for target, parameter in _migfix_fixed_parameters.items():
        args.extend([parameter, target_interface[target].path])

    ctx.actions.run(
        arguments = args,
        executable = ctx.executable._migfix,
        inputs = raw_interface.values(),
        mnemonic = "FixMachInterface",
        outputs = target_interface.values(),
        progress_message = "Fixing generated interface: %s" % basename,
    )

    return target_interface

def _mig_impl(ctx):
    mig = ctx.toolchains[_MIG_TOOLCHAIN_TYPE].tool
    cc_toolchain = find_cc_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features + ["sysroot"],
        unsupported_features = ctx.disabled_features,
    )
    cc = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = ACTION_NAMES.c_compile,
    )
    cc_variables = cc_common.empty_variables()
    cc_env = cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = ACTION_NAMES.c_compile,
        variables = cc_variables,
    )

    sdk_srcs = {k: None for k in ctx.attr.sdk_srcs}
    for lib in ctx.toolchains[_MIG_TOOLCHAIN_TYPE].libs:
        if lib.basename in sdk_srcs:
            sdk_srcs[lib.basename] = lib
    missing_srcs = [k for k, v in sdk_srcs.items() if v == None]
    if missing_srcs:
        fail("item(s) from sdk_srcs are not found in the current mig toolchain:", missing_srcs)

    output_files = []

    src_files = []
    hdr_files = []
    client_files = []
    server_files = []

    for defs_file in ctx.files.srcs + sdk_srcs.values():
        result_files = _mig_generate(ctx, defs_file, mig, cc, cc_env, cc_toolchain)
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
    """,
    attrs = {
        "srcs": attr.label_list(
            doc = "A list of MIG definition files (.defs).",
            allow_files = True,
            mandatory = True,
        ),
        "sdk_srcs": attr.string_list(
            doc = "MIG definition filenames to add from macOS SDK.",
        ),
        "included_srcs": attr.label_list(
            doc = "Additional MIG definition files (.defs). These are passed to " +
                  "the MIG tool, but are not considered outputs of this rule. " +
                  "This is useful for including definitions from other MIG rules.",
            allow_files = True,
        ),
        "include_dirs": attr.string_list(
            doc = "A list of include directories for the MIG tool, subject to " +
                  "$(location ...) expansions.",
        ),
        "output_dir": attr.string(
            doc = "An optional output directory for generated files. If not " +
                  "specified, files are placed in the default genfiles directory.",
        ),
        "deps": attr.label_list(
            doc = "Labels used for location expansion.",
        ),
        "_migfix": attr.label(
            cfg = "exec",
            executable = True,
            default = Label("//util:mig_fix"),
        ),
        "_cc_toolchain": attr.label(
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain"),
        ),
    },
    fragments = ["cpp"],
    implementation = _mig_impl,
    output_to_genfiles = True,
    toolchains = use_cc_toolchain() + [_MIG_TOOLCHAIN_TYPE],
)
