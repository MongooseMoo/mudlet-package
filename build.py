"""Build dist/mongoose.mpackage, the Mudlet package Mongoose offers through GMCP Client.GUI.

    python build.py VERSION

Each module listed in MODULES becomes one script in the package. The archive's
timestamps are fixed, so the same sources and version give the same bytes.
"""

import sys
import zipfile
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent
NAME = "mongoose"
MODULES = [
    ("Mongoose keys", ROOT / "keys" / "keys.lua"),
    ("Mongoose mapper", ROOT / "mapper" / "mapper.lua"),
    ("Mongoose and the starter UI", ROOT / "ui" / "ui.lua"),
]
FIXED_TIME = (2026, 10, 18, 0, 0, 0)


def config(version: str) -> str:
    return "\n".join([
        f"mpackage = [[{NAME}]]",
        "author = [[Mongoose]]",
        "title = [[Mongoose]]",
        f"version = [[{version}]]",
        "description = [[Keys for the games and consoles you use, and a map of the rooms you visit.]]",
        "",
    ])


def package_xml() -> str:
    scripts = []
    for name, path in MODULES:
        source = path.read_text(encoding="utf-8")
        scripts.append(
            '\t\t<Script isActive="yes" isFolder="no">\n'
            f"\t\t\t<name>{escape(name)}</name>\n"
            "\t\t\t<packageName></packageName>\n"
            f"\t\t\t<script>{escape(source)}</script>\n"
            "\t\t\t<eventHandlerList />\n"
            "\t\t</Script>\n"
        )
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        "<!DOCTYPE MudletPackage>\n"
        '<MudletPackage version="1.001">\n'
        "\t<TriggerPackage />\n"
        "\t<TimerPackage />\n"
        "\t<AliasPackage />\n"
        "\t<ActionPackage />\n"
        "\t<ScriptPackage>\n"
        + "".join(scripts)
        + "\t</ScriptPackage>\n"
        "\t<KeyPackage />\n"
        "\t<VariablePackage>\n"
        "\t\t<HiddenVariables />\n"
        "\t</VariablePackage>\n"
        "</MudletPackage>\n"
    )


def add(archive: zipfile.ZipFile, name: str, text: str) -> None:
    info = zipfile.ZipInfo(name, FIXED_TIME)
    info.compress_type = zipfile.ZIP_DEFLATED
    archive.writestr(info, text.encode("utf-8"))


def main() -> None:
    if len(sys.argv) != 2 or not sys.argv[1].strip():
        sys.exit("usage: python build.py VERSION")
    version = sys.argv[1].strip()
    out = ROOT / "dist" / f"{NAME}.mpackage"
    out.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(out, "w") as archive:
        add(archive, "config.lua", config(version))
        add(archive, f"{NAME}.xml", package_xml())
    print(out)


if __name__ == "__main__":
    main()
