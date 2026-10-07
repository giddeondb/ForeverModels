# Changes

## 0.8.0

- Replace model reload prompts with character chat confirmations

## 0.6.0

- Use standard WoW installation and SavedVariables persistence.
- Retired the beta loader, installer, and installer-specific tests.
- Preserve existing preferences and legacy per-character migration.
- Native persistence verified in-game on build 1.60.1.70009 on September 29.
- Added a standard release ZIP builder.

## 0.5.0

- Added a repeatable Linux/Wine installer for the beta SavedVariables workaround.
- Load the selected account's live file through the add-on TOC before initialization.
- Archive the private recovery add-on; no hardcoded character fallback remains.
- Added persistence status and install/check/remove commands.
- Tested repeated installation, file replacement, fresh saves, and preserved data on removal.

## 0.4.2

- Keep active preferences attached to the account character record if the legacy saved-variable global is replaced.
- Added a regression test for that state replacement. The reported login reset still needs in-game verification.

## 0.4.1

- Added a one-time per-character login hint for /models, including existing characters.

## 0.4.0

- Added a paginated character roster with HD/SD controls and immediate saving.
- Offline-character edits apply at that character's next login.
- Highlighted the current character and added an explicit pending-reload button.
- Clarified saved preference, client setting, and setting at UI load in diagnostics.
- Added roster regression tests and separated backups from release files.

## 0.3.0

- Added GUID-keyed account storage with legacy per-character migration.
- Standardized model arguments to hd and sd.
- User confirmed per-character restoration and reload prompts work in-game.

## 0.2.0

- Switched from the unavailable hdPlayerModels CVar to Forever's C_GameRules API.
- Added Reload/Later prompts.

## 0.1.0

- Initial compatibility prototype.
