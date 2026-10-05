# Forever Models publishing guide

Reviewed October 1, 2026, for version 0.6.0.

## Readiness

Recommendation: prepare a public beta release. No release-blocking runtime defect
was found in this review, but the final packaged build still needs an in-game
smoke test. Allow roughly 60–90 minutes for preparation and submissions, excluding
account setup, artwork creation, and platform moderation.

| Area | Finding |
| --- | --- |
| Automated checks | All 17 LuaJIT regression tests passed; Lua 5.1 syntax validation passed. |
| Packaging | Built and inspected `dist/ForeverModels-0.6.0.zip`. Correct `ForeverModels/` root; only Lua, TOC, README, changelog, and license included. |
| In-game evidence | README records successful persistence, reload, character switching, offline-character editing, and restart testing on September 29, build 1.60.1.70009. This review did not repeat that testing. |
| Compatibility | TOC targets interface 16001. CurseForge lists Forever 1.60.1; Wago's live game selector includes Classic Forever. Wago's authenticated upload form and exact version choices were not inspected. |
| Release preparation | BSD 3-Clause license included; author is GiddeonDB. Still needs project icon and screenshots. Hosting IDs and release automation are not configured. Git is initialized on main but has no commits. |

The tests emulate client APIs and widgets. They do not prove actual model rendering,
combat restrictions, client disk persistence, or compatibility with other addons.
There are no bundled external libraries or runtime dependencies in this package.

## 1. Finish the release materials

1. Author and license are ready: GiddeonDB and BSD 3-Clause. The TOC records both,
   and `LICENSE` ships in the ZIP. Select BSD 3-Clause on both hosting sites.
2. Make an original 400×400 PNG icon and capture an actual screenshot of `/models`
   with two characters using different saved choices. Keep marketing artwork
   outside the runtime ZIP. CurseForge specifies an original square icon and
   informative project content in its [submission guide](https://support.curseforge.com/support/solutions/articles/9000199552-project-submission-guide-and-tips).
3. Update installation instructions if your current client uses a folder other
   than `_classic_beta_`. State the tested client build and Forever-only support.
   Keep the explanation that this changes an account-wide setting on character
   login and can require a reload.
4. Keep version `0.6.0` for this first public beta if it has not already been
   published. Select Beta in the upload forms. If changing the version, update
   both the TOC and the hardcoded version in the Lua status command, plus the
   changelog. The package script currently accepts numeric dotted versions only;
   `0.6.0-beta1` would require changing its parser.

Author metadata and screenshots improve release quality; hosting project IDs and
automation are optional for the first manual upload.

## 2. Validate the exact ZIP

Run from the repository directory after the release edits:

```sh
luajit tests/test.lua
luac5.1 -p ForeverModels.lua
python tools/package.py
python -m zipfile -l dist/ForeverModels-0.6.0.zip
```

Use the ZIP's versioned filename if you changed the version. Install that ZIP into
the target client's AddOns folder, preserving your WTF settings. Verify:

1. `/models` opens without Lua errors, and HD/SD choices change the visible models
   after accepting Reload.
2. Two characters retain opposite choices across character changes and a full
   client restart. Editing the other character applies on its next login.
3. A requested change during combat waits until combat ends. `/models off` cancels
   a queued change; `/models on` resumes switching.
4. Choosing Later does not reload automatically. `/models status` reports the
   expected preference and reload state.
5. An existing installation retains choices after updating. If possible, also
   test first-run behavior on a character that has never used the addon.

Record the tested client build and date in the release notes. Do not claim Retail,
Classic Era, or other client support based only on graceful API failure handling.

## 3. Put the source and release on GitHub

Create a public repository named `ForeverModels`. Leave GitHub's automatic README,
license, and gitignore initialization off when pushing this existing local folder.
Set your Git commit name and email before the initial commit; a GitHub-provided
private commit email is an option.

Commit the source, documentation, chosen license, tests, and tools, then connect
the repository URL shown by GitHub and push `main`. The local `.gitignore` already
excludes `dist/` and ZIPs. This review has not made a commit or pushed anything.

Enable GitHub Issues and use the repository and Issues URLs as the Source and
Support links on the hosting sites.

In GitHub Releases, draft a release for tag `v0.6.0` targeting the final committed
source. Attach the ZIP built from that source, add the changelog and tested build,
and mark it as a pre-release. Publish when the package checks are complete.
Users should install the attached addon ZIP; GitHub's automatic source archive
does not have the intended addon folder layout. See [GitHub's release instructions](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository).

## 4. Submit to CurseForge

1. Sign in at [CurseForge Authors](https://authors.curseforge.com/) and create a
   World of Warcraft addon project named Forever Models. Check name availability.
   Suggested main category: Miscellaneous.
2. Add the icon, summary, description below, license, screenshot, and Source/Issues
   links. Keep the project non-experimental for normal ecosystem distribution;
   use the file's Beta designation for this initial release. CurseForge explains
   this distinction in its [submission guide](https://support.curseforge.com/support/solutions/articles/9000199552-project-submission-guide-and-tips).
3. Upload the final ZIP, select Forever and game version 1.60.1 if that remains the
   tested version, select Beta, and include release notes. CurseForge currently
   hosts [Forever 1.60.1 files](https://www.curseforge.com/wow/addons/gatherlite/files/8915348).
4. Submit for moderation and respond to requested changes. After approval, verify
   the download and install it once. Beta visibility in addon managers depends on
   users' update-channel settings. Do not promise a moderation completion date.

Put functional information directly on the project page. Follow the current
[moderation policies](https://support.curseforge.com/support/solutions/articles/9000197279-moderation-policies), including ZIP uploads and changelogs.

## 5. Submit to Wago Addons

1. Open [Wago Addons](https://addons.wago.io/) and select Upload your Addon.
   Its [developer login](https://addons.wago.io/auth/login) supports GitHub and
   Battle.net. This is the Addons service, separate from Wago Imports.
2. Complete developer registration and create the project. Reuse the same name,
   icon, description, license, screenshot, and source/support links.
3. Upload the same tested ZIP as a beta for Classic Forever. The public selector
   includes this flavor as of this review. Confirm the developer form offers the
   matching 1.60.1 build/version before submitting; if absent, use
   [Wago contact](https://addons.wago.io/contact) to ask how to upload it.
4. Complete any review steps the dashboard presents, then verify the public file
   and its installation. Exact authenticated form labels and review timing remain
   unverified.

## Listing text to reuse

Summary:

> Remember and restore HD or SD models separately for each character in WoW Forever.

Description:

> Forever Models saves your preferred HD or SD model setting for each character
> and restores it when you log in.
>
> Type `/models` to open your character roster. Choose HD or SD for your current
> character, or set another character's preference for its next login. Characters
> appear after you log into them with the addon enabled.
>
> Model changes can require a UI reload. The addon offers Reload or Later and
> never reloads automatically. Switching waits until combat ends.
>
> Use `/models off` to pause automatic switching, `/models on` to resume, and
> `/models status` for diagnostics. `/fmodels` is an alternative command.
>
> This addon targets WoW Forever, interface 16001. It switches the client's
> account-wide model setting according to the current character's preference.
> It does not assign different model styles to individual races or change how
> other players see your character. No companion addon is required.

Append the final tested build/date and your GitHub Issues link. For reports,
request addon version, client build, reproduction steps, and any Lua error.

## Later: automate updates

After both first uploads work, add each real project ID to the TOC:

```text
## X-Curse-Project-ID: YOUR_CURSEFORGE_ID
## X-Wago-ID: YOUR_WAGO_ID
```

These are placeholders, not lines to ship unchanged. Use
[BigWigs packager](https://github.com/BigWigsMods/packager) with a tag-triggered
GitHub Actions workflow and `.pkgmeta` controlling package name and exclusions.
Store `CF_API_TOKEN` and `WAGO_API_TOKEN` in GitHub Actions secrets. The workflow
can use GitHub's built-in token with release-writing permission for GitHub uploads.
Exclude tests, tools, artwork, and publishing documentation from runtime packages.

Before enabling uploads, inspect a build made with uploading disabled and confirm
the current packager maps interface 16001 to Forever correctly. This review did
not validate its Forever detection. Manual uploads remain sufficient for launch.

Two maintenance improvements can wait: read the status version from TOC metadata
instead of duplicating it, and expand tests for genuinely missing API functions,
the login hint, and recovery from an unavailable player GUID.
