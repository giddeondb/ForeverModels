#!/usr/bin/env python3
"""Build reproducible, installable ZIPs containing only public addon files."""
from pathlib import Path
import re
import shutil
import zipfile

FILES = ("ForeverModels.lua", "ForeverModels.toc", "README.md", "CHANGELOG.md", "LICENSE")


def build(root):
    version = re.search(r"^## Version: (\d+\.\d+\.\d+)$",
                        (root / "ForeverModels.toc").read_text(), re.MULTILINE).group(1)
    destination = root / "dist" / f"ForeverModels-{version}.zip"
    destination.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED) as archive:
        for name in FILES:
            if (root / name).is_symlink():
                raise RuntimeError(f"Refusing to package a symbolic link: {name}")
            info = zipfile.ZipInfo(f"ForeverModels/{name}", (2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            archive.writestr(info, (root / name).read_bytes())
    with zipfile.ZipFile(destination) as archive:
        assert archive.testzip() is None
        assert set(archive.namelist()) == {f"ForeverModels/{name}" for name in FILES}
        for name in FILES:
            assert archive.read(f"ForeverModels/{name}") == (root / name).read_bytes()
    alias = destination.with_name("ForeverModels.zip")
    shutil.copyfile(destination, alias)
    assert destination.read_bytes() == alias.read_bytes()
    return destination, alias


if __name__ == "__main__":
    for path in build(Path(__file__).resolve().parents[1]):
        print(path)
