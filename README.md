<div align="center">

<img src="docs/images/icon.png" alt="Slip macOS menu bar notepad icon" width="100">

# Slip — quick notes & to-do lists in your Mac menu bar

**Less to manage. More room to think.**

A free, open-source **macOS menu bar notepad** for quick notes, live Markdown, and everyday to-do lists. Open it, catch a thought, and get back to what matters. No title required.

**Native macOS · Works offline · Local storage · No account · MIT licensed**

[Download for macOS](https://github.com/berkinduz/slip-menu-note-app/releases/latest) · [Quick install](#quick-install) · [How to use](#how-to-use) · [Contribute](#contributing)

</div>

![Slip opened beneath its notebook icon in the macOS menu bar, showing the Make it yours note with live Markdown, task boxes, highlighted text, and a quiet tag footer](docs/images/hero.png)

## Quick install

Requires **macOS 14 or later on Apple Silicon**.

1. Download the **[latest DMG](https://github.com/berkinduz/slip-menu-note-app/releases/latest)** from the release assets.
2. Open it and drag **Slip → Applications** in the installer window.
3. Open Slip from Applications, then eject the disk image. Your notebook lives in the menu bar.

The screenshots and feature guide below show the current `main` branch. The latest packaged release, **v0.2.2**, predates the Settings and organization redesign. To try the new interface now, [build from source](#build-from-source).

A ZIP and SHA-256 checksums are also included with each release. Builds are ad hoc signed and **not notarized**; if macOS blocks the first launch, follow Apple's [opening-app guidance](https://support.apple.com/en-us/102445).

## How to use

1. **Catch a thought.** Click Slip's menu bar icon or press **⌃⌥N**. Start writing immediately. Titles are optional; the note list can use the first line instead.
2. **Turn it into an action.** Type **`/`** for quick commands, then choose a task list, heading, or another format with the arrow keys and Return. Click a task box to check it off.
3. **Keep it close.** Use the header pin to keep the panel visible while switching apps. Use **⌘N** or the compose button at the top right for another note.
4. **Get back to work.** Press **Escape** to dismiss a menu or hide Slip. Changes save automatically. Reopening the panel restores your sidebar preference.

Use it for a few work follow-ups, a meeting note, a daily checklist, or an idea that shouldn't interrupt your flow.

## A little Markdown

Write and read in the same place. Completed Markdown markers disappear into the formatting, so `**bold**` becomes **bold** without switching to a preview. Your note is still stored as Markdown.

Slip supports headings, bold, italic, strikethrough, highlights, links, inline code, fenced code blocks, quotes, dividers, bullet and numbered lists, and clickable task lists. The **`/` menu follows your theme**, and formatting shortcuts keep your hands on the keyboard.

**Checklists are first-class notes.** Return continues the list; Return on an empty item ends it. If quick actions are your usual workflow, set **Settings → Quick capture → New notes start with → Checklist** so every new note is ready for a task.

Select text and press **⌘K** to add a link, or **⇧⌘M** to highlight it. Regular copy gives you the visible text. Use **More → Export → Copy Markdown** for the source, or **Markdown file…** to export a note.

## Organized when you need it

![Slip with its compact note sidebar, folder selector, separate tag browser button, and manual tags beneath the current note](docs/images/organized.png)

### Folders without a crowded sidebar

The sidebar puts your **notes** first. Click the location above the note list to choose **All notes**, **Pinned**, or a folder. Search for a folder or use its arrow to browse subfolders, one level at a time.

Use the folder-plus button in this chooser to create a folder. Right-click a folder to create a subfolder, rename it, move it, or remove it. New notes go into the selected folder; **Move to folder** in a note's menu handles the rest. Removing a folder keeps its notes in the parent folder.

### Tags you add yourself

Add tags from the small **footer beneath your note**. Type a name, reuse a suggestion, or create one explicitly. Use **↑ / ↓** to choose, **Return** to add, and **Escape** to return to writing. Typing `#words` in a note does not create tags.

The **tag button beside the sidebar's location selector** opens a searchable tag browser with note counts. Filter across folders, give a tag a monochrome icon, or rename it. Renaming to an existing tag offers an explicit **Merge**. Removing a tag keeps the notes and their contents.

Folders give a note one home; tags connect notes across those homes. Tag names stay lowercase. Your titles, folder names, and note text keep the case you enter.

### Find it again

Press **⌘F** to search titles and content. Start a query with `#work` to search by tag, or combine it with text, such as `#work feedback`. Pin frequently used notes through their menu to keep them at the top of the list. Deleted notes go to **Trash**, where they can be restored.

## Make it feel like yours

![Slip Settings in dark mode, with eight theme choices, six accent options, and a live Markdown sample](docs/images/settings.jpg)

Settings has dedicated pages for **Appearance**, **Editor**, **Quick capture**, **Organization**, and **About Slip**. Open it with **⌘,** or **More → Settings…**.

- **Appearance:** choose **Slip Theme**, System, Light, Dark, Linen, Dusk, Ocean, or Forest. Keep the theme's accent or pick Sand, Sage, Blue, Rose, or Violet.
- **Editor:** use SF Pro Text, SF Mono, or an installed font. Adjust size, line height, paragraph spacing, page margins, and ligatures with a live Markdown sample. Set spell checking, autocorrect, and smart punctuation to suit your writing.
- **Quick capture:** start with a blank note, checklist, or bullet list. Choose whether Slip opens on launch, stays open across apps, continues lists, or shows slash commands.
- **Organization:** sort by last edit, creation date, or title; show or hide note previews and word count; open your local data folder.
- **About Slip:** find the version, source code, contribution links, and ways to support development.

## Keyboard shortcuts

On Mac, **⌘** is Command, **⌥** is Option, **⌃** is Control, and **⇧** is Shift.

| Action | Shortcut |
| --- | --- |
| Open or hide Slip from another app | ⌃⌥N |
| New note / new folder | ⌘N / ⇧⌘N |
| Search notes | ⌘F |
| Bold / italic / inline code | ⌘B / ⌘I / ⌘E |
| Add or edit a link | ⌘K |
| Highlight | ⇧⌘M |
| Heading / bullet list / task list | ⇧⌘H / ⇧⌘L / ⇧⌘T |
| Show or hide the sidebar | ⇧⌘S |
| Settings | ⌘, |
| Dismiss a menu or hide the panel | Escape |

## Your notes stay on your Mac

Slip works offline and uses no account or cloud service. Notes, folders, tags, and preferences live in **`~/Library/Application Support/Slip/`**. Open the folder from Settings, or export a note as Markdown to take it elsewhere.

Cloud sync is not included. The downloadable app targets **Apple Silicon**; an Intel release is not currently provided. Slip uses **SwiftUI and AppKit** for its native macOS interface.

## Contributing

Help make a small, useful menu bar notes app better. **Bug reports, accessibility improvements, UI refinements, documentation, and focused code contributions are welcome.**

Read [CONTRIBUTING.md](CONTRIBUTING.md), [report a bug or suggest an improvement](https://github.com/berkinduz/slip-menu-note-app/issues), or open a pull request. For a larger feature, start an issue to discuss how it fits Slip's simple quick-capture workflow.

### Build from source

You need **macOS 14 or later**, **Xcode 16 or later**, and **Swift 6**.

```sh
git clone https://github.com/berkinduz/slip-menu-note-app.git
cd slip-menu-note-app
swift test
./scripts/build-app.sh
```

The script creates an ad hoc signed **`Slip.app` next to the repository directory**. Open it to try the current interface. It does not launch or notarize the app automatically. You can also open `Package.swift` in Xcode. See the contribution guide for DMG packaging.

Made by [berkinduz](https://github.com/berkinduz). If Slip makes your day a little lighter, [buy me a coffee](https://buymeacoffee.com/berkinduz) or share it with someone who lives in their menu bar.

## License & credits

Slip is free and open source under the **[MIT License](LICENSE)**. Slip Theme grew from Kanagawa Dragon; attribution is included in [third-party notices](Resources/THIRD-PARTY-NOTICES.txt). Promotional images combine the real Slip interface with a macOS desktop setting; macOS interface elements and the Sonoma wallpaper belong to Apple.
