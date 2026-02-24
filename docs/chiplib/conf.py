import os
import re
import tomllib

from pathlib import Path

root_dir = Path(__file__).resolve().parent.parent.parent

with open(root_dir / "pyproject.toml", "rb") as f:
    pyproject_toml = tomllib.load(f)

# Project information

project = "Chiplib"
copyright = "2025-2026, Chiplib Authors"
author = ""
release = pyproject_toml["project"]["version"]

# General configuration

extensions = [
    "sphinx_peakrdl",
    "sphinx_sitemap",
    "sphinxext.opengraph",
]

templates_path = ["_templates"]
exclude_patterns = []

numfig = True

numfig_format = {
    "figure": "Fig. %s.",
    "table": "Table %s.",
    "code-block": "Listing %s.",
}

peakrdl_input_files = [
    str(root_dir / "chiplib/riscv/plic/reg/chiplib_riscv_plic.rdl"),
]
peakrdl_html_title = "Chiplib Register Reference"

html_baseurl = "https://chiplib.readthedocs.io/"
rtd_lang = os.environ.get("READTHEDOCS_LANGUAGE", "en")
rtd_version = os.environ.get("READTHEDOCS_VERSION", "latest")
version = rtd_version

ogp_site_url = f"{html_baseurl}{rtd_lang}/{rtd_version}/"
ogp_description_length = 200

# Options for HTML output

html_theme = "sphinx_book_theme"
html_theme_options = {
    "repository_url": "https://github.com/subnyquist/chiplib",
    "use_repository_button": True,
    "use_issues_button": True,
    "use_download_button": False,
    "home_page_in_toc": True,
    "show_navbar_depth": 2,
    "show_toc_level": 2,
    "logo": {
        "image_light": "_static/logo.svg",
        "image_dark": "_static/logo.svg",
    },
}
html_static_path = ["_static"]
html_css_files = ["custom.css"]
html_extra_path = ["robots.txt"]
html_title = project
html_show_sphinx = False
html_show_sourcelink = False


def gen_sv_stubs(app):
    """Generate SystemVerilog stub listings."""
    sv_files = [
        "chiplib/riscv/plic/chiplib_riscv_plic.sv",
    ]

    pat = r"\);.*?endmodule\b"
    subst = ");\n\n  // Implementation\n\nendmodule"

    out_dir = Path(app.srcdir) / "generated"
    out_dir.mkdir(exist_ok=True)

    for file in sv_files:
        in_path = root_dir / file
        out_path = out_dir / (in_path.stem + ".rst")

        with open(in_path, "r", encoding="utf-8") as f:
            src = f.read()

        stub = re.sub(pat, subst, src, flags=re.DOTALL | re.MULTILINE)

        title = in_path.stem + " -- Interface Definition"

        lines = [
            ":orphan:",
            "",
            title,
            "=" * len(title),
            "",
            ".. code-block:: systemverilog",
            "",
        ]
        lines += [f"   {line}" if line else "" for line in stub.splitlines()]

        with open(out_path, "w", encoding="utf-8") as f:
            for line in lines:
                print(line, file=f)


def setup(app):
    """Sphinx extension hook."""
    app.connect("builder-inited", gen_sv_stubs)
