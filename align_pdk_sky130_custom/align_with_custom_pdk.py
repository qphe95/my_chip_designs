#!/usr/bin/env python3
"""
Run ALIGN with custom Sky130 passive generators from this repo.

This script builds a temporary PDK directory by symlinking the installed
ALIGN-pdk-sky130/SKY130_PDK files and overlaying the custom res.py / cap.py
generators stored in the same directory as this script.  The temporary PDK
is cleaned up automatically after ALIGN finishes.
"""

import os
import sys
import shutil
import tempfile
import pathlib
import subprocess

# Directory containing this script and the custom generator modules.
CUSTOM_PDK_DIR = pathlib.Path(__file__).resolve().parent

# Default installed Sky130 PDK adapter location.
DEFAULT_INSTALLED_PDK = pathlib.Path.home() / (
    ".local/src/xschem_ngspice_build/ALIGN-pdk-sky130/SKY130_PDK"
)


def _inject_pdk_path(argv, tmp_pdk):
    """Return a copy of argv with -p pointing at the temporary PDK."""
    argv = list(argv)
    out = []
    i = 0
    replaced = False
    while i < len(argv):
        if argv[i] == "-p" and i + 1 < len(argv):
            out.extend(["-p", str(tmp_pdk)])
            i += 2
            replaced = True
        elif argv[i].startswith("-p"):
            out.append(f"-p{tmp_pdk}")
            i += 1
            replaced = True
        else:
            out.append(argv[i])
            i += 1
    if not replaced:
        out.extend(["-p", str(tmp_pdk)])
    return out


def main(argv=None):
    if argv is None:
        argv = sys.argv[1:]

    installed_pdk = pathlib.Path(
        os.environ.get("ALIGN_PDK_SKY130_INSTALLED", DEFAULT_INSTALLED_PDK)
    )
    if not installed_pdk.is_dir():
        print(
            f"ERROR: Installed Sky130 PDK not found at {installed_pdk}",
            file=sys.stderr,
        )
        print(
            "Set ALIGN_PDK_SKY130_INSTALLED to the path of the installed "
            "SKY130_PDK directory.",
            file=sys.stderr,
        )
        return 1

    # Files we override with repo-local custom generators.
    custom_files = {
        "res.py": CUSTOM_PDK_DIR / "res.py",
        "cap.py": CUSTOM_PDK_DIR / "cap.py",
    }
    for name, path in custom_files.items():
        if not path.is_file():
            print(f"ERROR: Custom generator not found: {path}", file=sys.stderr)
            return 1

    with tempfile.TemporaryDirectory(prefix="sky130_pdk_") as tmpdir:
        tmp_pdk = pathlib.Path(tmpdir) / "SKY130_PDK"
        tmp_pdk.mkdir(parents=True)

        # Symlink all installed PDK files except the ones we override.
        for item in installed_pdk.iterdir():
            if item.name in custom_files:
                continue
            link_name = tmp_pdk / item.name
            if item.is_dir():
                shutil.copytree(item, link_name, symlinks=True)
            else:
                link_name.symlink_to(item)

        # Copy custom generators into the temporary PDK.
        for name, path in custom_files.items():
            shutil.copy(path, tmp_pdk / name)

        env = os.environ.copy()
        env["ALIGN_PDK_SKY130"] = str(tmp_pdk)

        cmd = ["schematic2layout.py"] + _inject_pdk_path(argv, tmp_pdk)
        print(f"Running ALIGN with custom PDK overlay: {tmp_pdk}")
        print(f"  installed base: {installed_pdk}")
        print(f"  custom files:   {CUSTOM_PDK_DIR}")
        return subprocess.call(cmd, env=env)


if __name__ == "__main__":
    sys.exit(main())
