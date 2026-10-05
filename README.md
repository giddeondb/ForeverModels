# Forever Models

Remember HD or SD models separately for each character in WoW Forever.
Open the character roster with `/models`.

**[Download latest version](https://github.com/giddeondb/ForeverModels/releases/latest/download/ForeverModels.zip)** ·
[Release notes](https://github.com/giddeondb/ForeverModels/releases/latest)

[Source on GitHub](https://github.com/giddeondb/ForeverModels) ·
[Report an issue](https://github.com/giddeondb/ForeverModels/issues)

A one-time chat hint appears for each character, including existing characters
after upgrading to 0.4.1. It stays dismissed across normal logouts and reloads.

## Character roster

![Forever Models character roster with saved HD and SD preferences. Secondary names are redacted for privacy.](https://raw.githubusercontent.com/giddeondb/ForeverModels/main/docs/images/character-roster-redacted.png)

- Your current character is highlighted and listed first.
- Click HD or SD to save immediately. The selected button says "(saved)".
- Changing the current character applies the setting and offers Reload or Later.
- Changing another character saves its preference for its next login without
  changing your current client setting.
- Only characters seen by this add-on appear. Log into missing characters once.
- Larger rosters use Previous and Next buttons.

The top of the window shows this character's saved choice, the client setting,
and whether a reload is pending. Its Reload button completes a pending change.

## Commands

| Command | Action |
| --- | --- |
| `/models` | Open or close the character roster |
| `/models hd` | Save and apply HD for the current character |
| `/models sd` | Save and apply SD for the current character |
| `/models status` | Show saved choice, client setting, setting at UI load, reload state, and character identity |
| `/models off` | Pause automatic switching and learning for the current character |
| `/models on` | Resume automatic switching |
| `/fmodels` | Alternative to `/models`, with the same arguments |

Choosing HD or SD also resumes automatic switching for that character.

## Installation and updates

Since version 0.6.0, the addon uses WoW's standard SavedVariables loader. No setup script,
filesystem links, or companion add-on are required. It targets interface 16001;
native persistence was confirmed in-game on Forever beta 1.60.1.70009.

1. Download **ForeverModels.zip** using the link above, then fully quit WoW.
2. Extract the release ZIP into `World of Warcraft/_classic_beta_/Interface/AddOns/`.
   The resulting path should be `AddOns/ForeverModels/ForeverModels.toc`.
3. Start WoW, enable Forever Models in AddOns, and run `/models`.

GitHub's automatic **Source code** archives are for developers. Install the
attached addon ZIP instead.

For updates, replace the existing ForeverModels folder with the new one.
Keep your WTF folder: that is where WoW stores your preferences.

### Upgrading from the beta workaround

With WoW closed, remove the old ForeverModels add-on folder before extracting
the new release. Also remove the temporary ForeverModelsRecovery add-on if
present. If manually removing the old LiveSavedVariables symbolic link, remove
the link itself, not the SavedVariables directory it points to.
Do not remove files from WTF. Previous settings migrate automatically.

The installer and workaround from v0.5.0 are retired. They were needed for an
earlier beta bug that wrote settings to disk but failed to load them.

Choices are stored by character GUID in ForeverModelsAccountDB. Existing
per-character preferences migrate on login when no account record exists.
The legacy ForeverModelsDB variable remains as a backup. WoW writes saved
variables to disk on normal logout or UI reload.

## Model switching

This controls Forever's account-wide model setting. It does not render individual
races differently or change how other players see you. Switching is deferred
during combat. The add-on never reloads automatically.

Changes made through Blizzard's model setter while in-world are remembered
when automatic switching is enabled. Calls made by another add-on cannot be
distinguished from manual changes. Startup calls are ignored.

The client setting is not a measurement of the visible model. A reload can be
required before appearance matches the selected setting.

The API and reload behavior follow
[Blizzard's Forever graphics UI source](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_Settings_Shared/Mainline/GraphicsOverrides.lua#L83).
The add-on reads `C_GameRules.AccountHasSDEnabled()` and writes
`C_GameRules.SetSDHDToggleValue(true)` for SD or false for HD.

## Validation

On September 29, 2026, the user confirmed normal SavedVariables persistence on
Forever beta 1.60.1.70009 after removing the workaround. The acceptance test
covered saved choices, editing another character, UI reload, character switching,
and a full client restart.

Run `luajit tests/test.lua` for local regression tests. They cover separate saved
characters, persistence across fresh sessions, legacy migration, failed writes,
combat deferral, reload prompts, roster edits, and pagination. They emulate UI
widgets and client APIs; they do not verify rendering or actual client behavior.

For future client updates:
1. Confirm existing characters and choices appear in `/models`.
2. Change another character's preference and run `/reload`.
3. Log into that character and confirm the saved choice applies.
4. Restore the preferred choice, quit WoW, and reopen it to verify persistence.

## Release packaging

Run `python tools/package.py` to build identical versioned and `ForeverModels.zip`
installable archives under dist. Every new main commit automatically publishes a
minor release. Release tags contain the generated version and changelog; main
retains its development baseline. See [the publishing guide](https://github.com/giddeondb/ForeverModels/blob/main/PUBLISHING.md).
Only the add-on Lua, TOC, README, changelog, and license are included. Tests, developer
tools, saved settings, backups, and filesystem links are excluded.

## Author and license

By GiddeonDB. Licensed under the [BSD 3-Clause License](LICENSE).
