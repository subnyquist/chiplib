"""SystemRDL build rules."""

load("@bedrock-rtl//bazel:verilog.bzl", "get_transitive")
load("@rules_hdl//verilog:providers.bzl", "VerilogInfo")

def _systemrdl_regblock_impl(ctx):
    srcs = get_transitive(ctx = ctx, srcs_not_hdrs = True).to_list()
    hdrs = get_transitive(ctx = ctx, srcs_not_hdrs = False).to_list()

    src_files = [src.path for src in srcs]
    hdr_files = [hdr.path for hdr in hdrs]

    inc_dirs = []
    for hdr in hdr_files:
        hdr_dir = "/".join(hdr.split("/")[:-1])
        if hdr_dir not in inc_dirs:
            inc_dirs.append(hdr_dir)

    module_name = ctx.attr.top + "_reg"
    package_name = ctx.attr.top + "_reg_pkg"

    out_verilog = ctx.actions.declare_file("%s/%s.sv" % (ctx.attr.outdir, module_name))
    out_verilog_pkg = ctx.actions.declare_file("%s/%s.sv" % (ctx.attr.outdir, package_name))
    out_hwif_rpt = ctx.actions.declare_file("%s/%s_hwif.rpt" % (ctx.attr.outdir, module_name))
    outputs = [out_verilog, out_verilog_pkg, out_hwif_rpt]

    cmd = "peakrdl regblock"
    cmd += " --cpuif %s" % ctx.attr.cpuif
    if (ctx.attr.addr_width):
        cmd += " --addr-width %s" % ctx.attr.addr_width
    cmd += " --hwif-report"
    for define in ctx.attr.defines:
        cmd += " -D %s" % define
    for incdir in inc_dirs:
        cmd += " -I %s" % incdir
    cmd += " -o $(dirname %s)" % out_verilog.path
    cmd += " --module-name %s" % module_name
    cmd += " --package-name %s" % package_name
    cmd += " --top %s" % ctx.attr.top
    for src in src_files:
        cmd += " " + src

    ctx.actions.run_shell(
        inputs = depset(srcs + hdrs),
        outputs = outputs,
        command = cmd,
        use_default_shell_env = True,
    )

    return [DefaultInfo(files = depset(outputs))]

def _systemrdl_uvm_impl(ctx):
    srcs = get_transitive(ctx = ctx, srcs_not_hdrs = True).to_list()
    hdrs = get_transitive(ctx = ctx, srcs_not_hdrs = False).to_list()

    src_files = [src.path for src in srcs]
    hdr_files = [hdr.path for hdr in hdrs]

    inc_dirs = []
    for hdr in hdr_files:
        hdr_dir = "/".join(hdr.split("/")[:-1])
        if hdr_dir not in inc_dirs:
            inc_dirs.append(hdr_dir)

    package_name = ctx.attr.top + "_uvm_reg_pkg"
    out = ctx.actions.declare_file("%s/%s.sv" % (ctx.attr.outdir, package_name))

    cmd = "peakrdl uvm"
    for define in ctx.attr.defines:
        cmd += " -D %s" % define
    for incdir in inc_dirs:
        cmd += " -I %s" % incdir
    cmd += " -o %s" % out.path
    for src in src_files:
        cmd += " " + src
    cmd += " --top %s" % ctx.attr.top
    cmd += " --use-factory"

    ctx.actions.run_shell(
        inputs = depset(srcs + hdrs),
        outputs = [out],
        command = cmd,
        use_default_shell_env = True,
    )

    return [DefaultInfo(files = depset([out]))]

def _systemrdl_html_impl(ctx):
    srcs = get_transitive(ctx = ctx, srcs_not_hdrs = True).to_list()
    hdrs = get_transitive(ctx = ctx, srcs_not_hdrs = False).to_list()

    src_files = [src.path for src in srcs]
    hdr_files = [hdr.path for hdr in hdrs]

    inc_dirs = []
    for hdr in hdr_files:
        hdr_dir = "/".join(hdr.split("/")[:-1])
        if hdr_dir not in inc_dirs:
            inc_dirs.append(hdr_dir)

    tree = ctx.actions.declare_directory("%s/%s_html" % (ctx.attr.outdir, ctx.attr.top))

    cmd = "peakrdl html"
    cmd += " --title %s" % ctx.attr.title
    for define in ctx.attr.defines:
        cmd += " -D %s" % define
    for incdir in inc_dirs:
        cmd += " -I %s" % incdir
    cmd += " -o %s" % tree.path
    for src in src_files:
        cmd += " " + src
    cmd += " --top %s" % ctx.attr.top

    ctx.actions.run_shell(
        inputs = depset(srcs + hdrs),
        outputs = [tree],
        command = cmd,
        use_default_shell_env = True,
    )

    return [DefaultInfo(files = depset([tree]))]

systemrdl_regblock = rule(
    doc = "Generates a regblock module from SystemRDL source code",
    implementation = _systemrdl_regblock_impl,
    attrs = {
        "defines": attr.string_list(
            doc = "Preprocessor defines",
        ),
        "deps": attr.label_list(
            allow_files = False,
            providers = [VerilogInfo],
            doc = "SystemRDL dependencies",
        ),
        "outdir": attr.string(
            doc = "Output directory",
        ),
        "outputs": attr.output_list(
            doc = "Output Verilog files",
        ),
        "top": attr.string(
            doc = "Top-level addrmap name",
        ),
        "cpuif": attr.string(
            doc = "Bus interface protocol",
        ),
        "addr_width": attr.string(
            doc = "Address width",
        ),
    },
)

systemrdl_uvm = rule(
    doc = "Generates a UVM regmodel from SystemRDL source code",
    implementation = _systemrdl_uvm_impl,
    attrs = {
        "defines": attr.string_list(
            doc = "Preprocessor defines",
        ),
        "deps": attr.label_list(
            allow_files = False,
            providers = [VerilogInfo],
            doc = "SystemRDL dependencies",
        ),
        "outdir": attr.string(
            doc = "Output directory",
        ),
        "outputs": attr.output_list(
            doc = "Output Verilog files",
        ),
        "top": attr.string(
            doc = "Top-level addrmap name",
        ),
    },
)

systemrdl_html = rule(
    doc = "Generates HTML documentation from SystemRDL source code",
    implementation = _systemrdl_html_impl,
    attrs = {
        "defines": attr.string_list(
            doc = "Preprocessor defines",
        ),
        "deps": attr.label_list(
            allow_files = False,
            providers = [VerilogInfo],
            doc = "SystemRDL dependencies",
        ),
        "outdir": attr.string(
            doc = "Output directory",
        ),
        "title": attr.string(
            doc = "Page title",
        ),
        "top": attr.string(
            doc = "Top-level addrmap name",
        ),
    },
)
