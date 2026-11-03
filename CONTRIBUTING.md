# Contributing

Thanks for helping improve Slip. Bug reports, focused fixes, documentation improvements, and feature proposals are welcome.

For a bug report, describe what you expected, what happened, your macOS version, and the steps needed to reproduce it. For a larger feature, open an issue to discuss the behavior before investing in an implementation. Please avoid sharing private note contents in reports or screenshots.

## Develop

Slip requires macOS 14 or later, Xcode 16 or later, and Swift 6. Clone the repository and run from its root:

```sh
swift test
./scripts/build-app.sh
```

The build script creates an ad hoc signed `Slip.app` next to the repository. You can also open `Package.swift` in Xcode. The app uses SwiftUI and AppKit; notebook and Markdown logic live in `SlipCore`.

Keep changes focused, include tests when they help verify behavior, and describe how you checked the change in your pull request. For interface changes, screenshots and a short description of the interaction are helpful. Preserve the existing license and third-party notices.

## Releases

Maintainers update the version in `Resources/Info.plist` and the release notes, then push a matching `v` tag such as `v0.2.1`. The release workflow tests and builds on an Apple Silicon macOS runner, signs the app and DMG ad hoc, and publishes both the drag-to-Applications DMG and an optional ZIP with SHA-256 checksums. Signing with a Developer ID and notarization are not part of this workflow.

To check the installer locally after building the app:

```sh
python3 -m venv .build/dmg-tools
.build/dmg-tools/bin/pip install -r scripts/dmg-requirements.txt
SLIP_DMG_PYTHON=.build/dmg-tools/bin/python ./scripts/build-dmg.sh
```

The script creates `Slip.dmg` next to the repository. Its Finder layout is written directly, so packaging does not require a GUI session.
