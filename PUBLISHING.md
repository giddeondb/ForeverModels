# Publishing Forever Models

## GitHub releases

Every new first-parent commit on `main` publishes a regular minor release,
including documentation changes and merge commits. Branch commits brought in by
a merge do not each create a release. Versioning starts at `0.7.0` and increments
the highest numeric release tag's minor component, resetting patch to zero.
Commits through `6131e75` predate automation and are not released retroactively.

1. Make changes and run `luajit tests/test.lua`, `luac5.1 -p ForeverModels.lua`,
   and `python3 -m unittest discover -s tests -p 'test_release.py' -v`.
2. Commit and push to main, or merge a pull request into main.
3. Watch the **Publish addon** workflow in GitHub Actions.
4. Verify the [latest download](https://github.com/giddeondb/ForeverModels/releases/latest/download/ForeverModels.zip).

Do not manually bump versions or push release tags. The workflow creates a
release commit whose parent is the originating main commit. Only the TOC version
and generated changelog entry change in that commit. A `vMAJOR.MINOR.0` tag points
to it; generated commits are never pushed back to main. `/models status` reads
the installed version from the TOC. Main retains its development version.

The workflow uses GitHub's built-in token with `contents: write`. No personal
access token or external service secret is needed. Publishing is serialized;
each run scans main's first-parent history so pending runs replaced by GitHub's
concurrency queue cannot lose commits.

## Artifacts and checks

Each release provides byte-identical `ForeverModels-VERSION.zip` and
`ForeverModels.zip` assets. Both contain one `ForeverModels/` folder with only
Lua, TOC, README, changelog, and BSD 3-Clause license. Screenshots, credentials,
tests, tools, and publishing documentation are excluded. ZIP timestamps and
permissions are fixed for reproducible builds.

Before tagging, the workflow runs Lua regression and syntax checks, validates
version metadata and changelog, and checks archive contents. It creates a draft,
uploads the assets, then publishes it as Latest. GitHub's automatic source-code
archives are not the intended addon installation package.

The README links directly to the stable `ForeverModels.zip` asset name on the
latest release. Source and support links are:

- https://github.com/giddeondb/ForeverModels
- https://github.com/giddeondb/ForeverModels/issues

## Retrying failures

Use **Actions → Publish addon → Run workflow → main** after resolving a transient
failure. Tags reserve version numbers and record the source SHA before drafts
are created. A retry reuses the tag and replaces assets only on its unpublished
draft. Completed releases are skipped. Existing tags and published assets are
never overwritten. A validation failure stops the backlog and leaves Latest
unchanged; it requires investigation before later commits can be released.

Release notes retain the recorded September 29, 2026 in-game validation on
Forever beta 1.60.1.70009. Automated checks do not claim a new in-game test.
For client updates, test model changes and chat confirmations, opposite preferences
on two characters, combat deferral, and persistence after a full client restart.

## Future hosting

CurseForge and Wago are deferred. No project IDs, upload integrations, or hosting
secrets are configured. When adding them, use the same validated installable
ZIP and verify their current Forever client/version options before submission.
