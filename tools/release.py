#!/usr/bin/env python3
"""Reconcile main's first-parent commits into immutable GitHub releases.

Tags reserve versions and record source SHAs before the draft is created. This
lets interrupted runs resume without moving tags or allocating another version.
"""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

from package import build

BASE = "6131e75a9b04443c1b1e6b78763c9a340944d6cd"
BASE_VERSION = (0, 6, 0)
VERSION = re.compile(r"v(\d+)\.(\d+)\.(\d+)")
SOURCE = re.compile(r"^Source-Commit: ([0-9a-f]{40})$", re.MULTILINE)
SKIP_CI = ("[skip ci]", "[ci skip]")
ROOT = Path(__file__).resolve().parents[1]


def run(*args, cwd=ROOT, env=None):
    return subprocess.check_output(args, cwd=cwd, env=env, text=True).strip()


def next_version(tags):
    versions = [tuple(map(int, m.groups())) for tag in tags
                if (m := VERSION.fullmatch(tag))]
    major, minor, _ = max([BASE_VERSION, *versions])
    return f"v{major}.{minor + 1}.0"


def pending(commits, sources, releases):
    """Return ordered source/tag pairs, omitting already published releases."""
    result = []
    for source in commits:
        tag = sources.get(source)
        release = releases.get(tag)
        if release is not None and not release["draft"]:
            continue
        result.append((source, tag))
    return result


def release_notes(source, version, subject):
    return f"""## {version}

- {subject}

Download **ForeverModels.zip** and extract the `ForeverModels` folder into
`World of Warcraft/_classic_beta_/Interface/AddOns/`. GitHub's automatic source
archives are not the installable addon package. Preserve your WTF settings.

Targets WoW Forever, interface 16001. The last recorded in-game persistence test
was September 29, 2026, on Forever beta 1.60.1.70009. This release runs automated
checks; it does not claim a new in-game test.

Source-Commit: {source}
"""


def validate(root, version):
    run("luajit", "tests/test.lua", cwd=root)
    run("luac5.1", "-p", "ForeverModels.lua", cwd=root)
    toc = (root / "ForeverModels.toc").read_text()
    if f"## Version: {version}\n" not in toc:
        raise RuntimeError("TOC version does not match tag")
    if not (root / "CHANGELOG.md").read_text().startswith(f"# Changes\n\n## {version}\n"):
        raise RuntimeError("Missing matching changelog entry")
    lua = (root / "ForeverModels.lua").read_text()
    if 'GetAddOnMetadata(ADDON, "Version")' not in lua or re.search(r'say\("v\d', lua):
        raise RuntimeError("Status must read version from TOC metadata")
    return build(root)


def release_catalog():
    pages = json.loads(run("gh", "api", "--paginate", "--slurp",
                           "repos/{owner}/{repo}/releases?per_page=100"))
    return {r["tag_name"]: r for page in pages for r in page}


def publish(source, tag, release, root, paths):
    """Only drafts may have their assets replaced during recovery."""
    if release is not None and not release["draft"]:
        raise RuntimeError(f"Refusing to overwrite published release {tag}")
    notes = root / "dist" / "release-notes.md"
    version = tag[1:]
    subject = run("git", "show", "-s", "--format=%s", source)
    notes.write_text(release_notes(source, version, subject))
    if release is None:
        run("gh", "release", "create", tag, "--verify-tag", "--draft",
            "--title", f"Forever Models {version}", "--notes-file", str(notes))
    run("gh", "release", "upload", tag, *(str(p) for p in paths), "--clobber")
    run("gh", "release", "edit", tag, "--draft=false", "--prerelease=false", "--latest",
        "--title", f"Forever Models {version}", "--notes-file", str(notes))


def main():
    if not os.environ.get("GITHUB_ACTIONS"):
        raise RuntimeError("Publishing runs only in GitHub Actions")
    run("git", "fetch", "origin", "main", "--tags")
    chain = run("git", "rev-list", "--first-parent", "origin/main").splitlines()
    if BASE not in chain:
        raise RuntimeError("Release baseline is not on main's first-parent history")
    commits = list(reversed(chain[:chain.index(BASE)]))
    tags = run("git", "tag", "--list", "v*").splitlines()
    sources = {}
    for tag in tags:
        if not VERSION.fullmatch(tag):
            continue
        message = run("git", "show", "-s", "--format=%B", f"{tag}^{{commit}}")
        match = SOURCE.search(message)
        if match:
            source = match[1]
            if source in sources:
                raise RuntimeError(f"Multiple release tags for source {source}")
            if run("git", "rev-parse", f"{tag}^1") != source:
                raise RuntimeError(f"Invalid release parent for {tag}")
            sources[source] = tag
    releases = release_catalog()
    for source, tag in pending(commits, sources, releases):
        if tag is None:
            message = run("git", "show", "-s", "--format=%B", source)
            if any(marker in message for marker in SKIP_CI):
                print(f"Skipping {source[:7]}: CI skip marker", flush=True)
                continue
        tag = tag or next_version(tags)
        version = tag[1:]
        print(f"Publishing {source[:7]} as {tag}", flush=True)
        with tempfile.TemporaryDirectory(prefix="forever-release-") as temp:
            work = Path(temp) / "source"
            existing = source in sources
            run("git", "worktree", "add", "--detach", str(work), tag if existing else source)
            try:
                if not existing:
                    toc_path = work / "ForeverModels.toc"
                    toc, count = re.subn(r"^## Version: .+$", f"## Version: {version}",
                                         toc_path.read_text(), flags=re.MULTILINE)
                    if count != 1:
                        raise RuntimeError("Expected one TOC version")
                    toc_path.write_text(toc)
                    subject = run("git", "show", "-s", "--format=%s", source)
                    changelog = work / "CHANGELOG.md"
                    old = changelog.read_text()
                    if not old.startswith("# Changes\n\n"):
                        raise RuntimeError("Unexpected changelog heading")
                    changelog.write_text(f"# Changes\n\n## {version}\n\n- {subject}\n\n"
                                         + old.removeprefix("# Changes\n\n"))
                paths = validate(work, version)
                if not existing:
                    env = dict(os.environ, GIT_AUTHOR_NAME="GiddeonDB",
                               GIT_AUTHOR_EMAIL="giddeonplays@gmail.com",
                               GIT_COMMITTER_NAME="GiddeonDB",
                               GIT_COMMITTER_EMAIL="giddeonplays@gmail.com")
                    run("git", "add", "ForeverModels.toc", "CHANGELOG.md", cwd=work)
                    run("git", "-c", "commit.gpgsign=false", "commit", "-m",
                        f"Release {tag}\n\nSource-Commit: {source}", cwd=work, env=env)
                    release_sha = run("git", "rev-parse", "HEAD", cwd=work)
                    run("git", "tag", tag, release_sha)
                    run("git", "push", "origin", f"refs/tags/{tag}")
                    tags.append(tag)
                publish(source, tag, releases.get(tag), work, paths)
            finally:
                run("git", "worktree", "remove", "--force", str(work))
        print(f"Published {tag}", flush=True)


if __name__ == "__main__":
    main()
