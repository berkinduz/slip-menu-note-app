# Changelog

## 0.3.1 — 2026-11-05

- Add Update & Restart: download and verify the new version, install it after Slip closes, and reopen the app with existing notes preserved.
- Restore the previous app if the update cannot reopen, and respect cancelled quit requests during an update.
- Simplify the README header around the app icon and quick notes from the menu bar.

## 0.3.0 — 2026-11-05

- Add optional iCloud Drive folder sync with local offline storage, retained conflict copies, per-folder histories and download-aware status.
- Add automatic local backups, confirmed recovery from local or exported backups, Markdown import and full-library Markdown export.
- Add launch-at-login controls and quiet startup, plus automatic and manual checks for published updates.
- Remember panel size and per-note selection/scroll, reveal search matches, and offer Undo after moving a note to Trash.
- Add Command-Return task completion, list indentation and URL-over-selection linking while retaining existing formatting shortcuts.
- Add packaging and checksum generation for a custom Homebrew tap.

## 0.2.2 — 2026-11-03

- Introduce a notebook mark connecting the menu bar with a quick note, shared by the application and menu bar icons.
- Draw the menu bar symbol as a resolution-independent template for clear light and dark appearances.
- Update the About and installer icons, README branding, and promotional menu bar images.

## 0.2.1 — 2026-11-03

- Add a drag-to-Applications DMG installer, with ZIP downloads available as an alternative.
- Keep the note editor on the vertical scrolling axis while preserving wrapping and vertical scrolling.
- Add About to Settings with the app version, author, source code, and support links.
- Refresh the README images with a readable welcome note and Markdown examples.

## 0.2.0 — 2026-11-03

- Add independent folders and nested folders, with note moves and folder reorganization.
- Keep manual tags available separately through a compact browser and note footer.
- Add a header pin for keeping the panel open across app switches.
- Remember the sidebar’s last open or closed state.
- Restore conventional English UI labels and neutral Dragon command-menu surfaces.
- Refresh the product presentation and quick-install documentation.

## 0.1.0

- Native menu bar notebook with local, automatic saving and an integrated Markdown editor with highlight.
- Manual nested tags, tag search and suggestions, a tag footer, optional tag icons, and a sidebar.
- Appearance and writing preferences, with SF Pro Text as the default note font, plus keyboard shortcuts, note export, pinning, and Trash.
- Apple Silicon distribution for macOS 14 and later. The app is ad hoc signed and not notarized.
