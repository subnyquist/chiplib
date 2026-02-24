"""Verilog build and test rules."""

load("@bedrock-rtl//bazel:verilog.bzl", "get_transitive")
load(
    "@rules_hdl//verilog:providers.bzl",
    "VerilogInfo",
    _verilog_library = "verilog_library",
)

verilog_library = _verilog_library

def _verilog_filelist_impl(ctx):
    srcs = get_transitive(ctx = ctx, srcs_not_hdrs = True).to_list()
    hdrs = get_transitive(ctx = ctx, srcs_not_hdrs = False).to_list()

    tree = ctx.actions.declare_directory(ctx.attr.name)
    filelist = "%s/%s.vf" % (tree.path, ctx.attr.name)

    cmd = []

    if len(hdrs):
        cmd.append("mkdir -p %s/include" % tree.path)
        cmd.append("echo +incdir+include >> %s" % filelist)
        for hdr in hdrs:
            cmd.append("cp %s %s/include/" % (hdr.path, tree.path))

    for src in srcs:
        cmd.append("echo %s >> %s" % (src.basename, filelist))
        cmd.append("cp %s %s/" % (src.path, tree.path))

    cmd.append("")
    cmd = "\n".join(cmd)

    ctx.actions.run_shell(
        command = cmd,
        inputs = depset(srcs + hdrs),
        outputs = [tree],
        use_default_shell_env = True,
    )

    return [DefaultInfo(files = depset([tree]))]

verilog_filelist = rule(
    attrs = {
        "deps": attr.label_list(
            allow_files = False,
            doc = "Verilog libraries",
            providers = [VerilogInfo],
        ),
    },
    doc = "Generates Verilog filelist",
    implementation = _verilog_filelist_impl,
)

def _verilog_lint_test_impl(ctx):
    srcs = get_transitive(ctx = ctx, srcs_not_hdrs = True).to_list()
    hdrs = get_transitive(ctx = ctx, srcs_not_hdrs = False).to_list()

    incdirs = {hdr.dirname: hdr.short_path for hdr in hdrs}

    cmd = ["set -x; verilator", "--lint-only"]
    cmd += ["-D%s" % d for d in ctx.attr.defines]
    cmd += ["-G%s=%s" % (k, v) for k, v in ctx.attr.params.items()]
    cmd += ["--top-module", ctx.attr.top]
    cmd += ["-I%s" % i for i in incdirs.keys()]
    cmd += [i.short_path for i in srcs]

    ctx.actions.write(
        output = ctx.outputs.executable,
        content = " ".join(cmd) + "\n",
    )

    runfiles = ctx.runfiles(files = srcs + hdrs)
    return [DefaultInfo(runfiles = runfiles)]

verilog_lint_test = rule(
    attrs = {
        "deps": attr.label_list(
            allow_files = False,
            doc = "Verilog libraries",
            providers = [VerilogInfo],
        ),
        "top": attr.string(
            doc = "Top-level module name",
            mandatory = True,
        ),
        "defines": attr.string_list(
            doc = "Preprocessor defines",
        ),
        "params": attr.string_dict(
            doc = "Top-level parameters",
        ),
    },
    doc = "Lints a Verilog module",
    implementation = _verilog_lint_test_impl,
    test = True,
)
