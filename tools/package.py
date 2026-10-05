#!/usr/bin/env python3
"""Build an installable release containing only public add-on files."""
from pathlib import Path
import re
import zipfile

root = Path(__file__).resolve().parents[1]
toc = (root / "ForeverModels.toc").read_text()
version = re.search(r"^## Version: ([0-9.]+)$", toc, re.MULTILINE).group(1)
files = ("ForeverModels.lua", "ForeverModels.toc", "README.md", "CHANGELOG.md", "LICENSE")
destination = root / "dist" / f"ForeverModels-{version}.zip"
destination.parent.mkdir(exist_ok=True)
for name in files:
    if (root / name).is_symlink():
        raise RuntimeError(f"Refusing to package a symbolic link: {name}")
with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED) as archive:
    for name in files:
        archive.write(root / name, f"ForeverModels/{name}")
with zipfile.ZipFile(destination) as archive:
    assert archive.testzip() is None
    assert set(archive.namelist()) == {f"ForeverModels/{name}" for name in files}
print(destination)
