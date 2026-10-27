# Forever Models <img align="right" src="https://raw.githubusercontent.com/giddeondb/ForeverModels/main/docs/images/logo-transparent.svg" alt="Forever Models logo, an SD to HD toggle switch" width="96">

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
- Changing the current character applies the setting and confirms it in chat.
- Changing another character saves its preference for its next login without
  changing your current client setting.
- Only characters seen by this add-on appear. Log into missing characters once.
- Larger rosters use Previous and Next buttons.

The top of the window shows this character's saved choice, the client setting,
and the result of the latest change.

## Commands

| Command | Action |
| --- | --- |
| `/models` | Open or close the character roster |
| `/models hd` | Save and apply HD for the current character |
| `/models sd` | Save and apply SD for the current character |
| `/models status` | Show saved choice, client setting, latest result, and character identity |
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
during combat. Successful changes are confirmed in chat for the logged-in character,
including automatic switching on login and changes applied after combat.

Changes made through Blizzard's model setter while in-world are remembered
when automatic switching is enabled. Calls made by another add-on cannot be
distinguished from manual changes. Startup calls are ignored.

The current Forever client applies model changes immediately without a UI reload.

The API is documented in
[Blizzard's Forever graphics UI source](https://github.com/Gethe/wow-ui-source/blob/b401e0332adfbf0460d319b06d8ea29279a941f1/Interface/AddOns/Blizzard_Settings_Shared/Mainline/GraphicsOverrides.lua#L96).
The add-on reads `C_GameRules.AccountHasSDEnabled()` and writes
`C_GameRules.SetSDHDToggleValue(isSD, Enum.SdToggleUsageLocationUI.OptionsMenu)`,
with `isSD` true for SD or false for HD. Updated clients require the usage location
argument. Older clients without that enum use the original one-argument call.

## Validation

On September 29, 2026, the user confirmed normal SavedVariables persistence on
Forever beta 1.60.1.70009 after removing the workaround. The acceptance test
covered saved choices, editing another character, UI reload, character switching,
and a full client restart.

On October 6, 2026, the user confirmed in-game that model changes apply with
a chat confirmation and no reload popup.

On October 16, 2026, the user confirmed the usage-location compatibility fix
worked in-game after installing the patched Lua file. The fix supplies the
required `OptionsMenu` usage location when applying HD or SD on updated clients.

Run `luajit tests/test.lua` for local regression tests. They cover separate saved
characters, persistence across fresh sessions, legacy migration, required usage
location arguments and older-client compatibility, failed writes,
combat deferral, change notifications without reload prompts, roster edits, and pagination. They emulate UI
widgets and client APIs; they do not verify rendering or actual client behavior.

For future client updates:
1. Confirm existing characters and choices appear in `/models`.
2. Change another character's preference and run `/reload`.
3. Log into that character and confirm the saved choice applies.
4. Restore the preferred choice, quit WoW, and reopen it to verify persistence.

## Release packaging

Run `python tools/package.py` to build identical versioned and `ForeverModels.zip`
installable archives under dist. Every new main commit automatically publishes a
minor release unless its message contains `[skip ci]` or `[ci skip]`. Skipped
commits stay skipped during later catch-up runs. Release tags contain the
generated version and changelog; main retains its development baseline.
See [the publishing guide](https://github.com/giddeondb/ForeverModels/blob/main/PUBLISHING.md).
Only the add-on Lua, TOC, README, changelog, and license are included. Tests, developer
tools, saved settings, backups, and filesystem links are excluded.

## Author and license

By GiddeonDB. Licensed under the [BSD 3-Clause License](LICENSE).
