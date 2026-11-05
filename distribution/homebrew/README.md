# Homebrew distribution preparation

This directory prepares a custom tap; it does not publish one. Version 0.3.0 is not yet a public release. The generated cask refers to its future versioned GitHub release URL and must not be advertised as installable before that exact asset is published.

After building and verifying the final DMG, generate the cask from its real bytes:

```sh
python3 scripts/prepare-homebrew.py .build/artifacts/Slip-v0.3.0-macos-arm64.dmg
ruby -c distribution/homebrew/Casks/berkinduz-slip.rb
```

If CI rebuilds the DMG, regenerate the cask from the actual published asset: rebuilding, signing or repackaging can change its checksum. The input filename must match the version in `Resources/Info.plist`. Do not substitute a placeholder checksum.

The eventual tap repository is `berkinduz/homebrew-tap`, with the generated file at `Casks/berkinduz-slip.rb`. Creating that repository, publishing the release and pushing the cask are separate publishing actions. Once those actions are explicitly authorized and completed, the intended installation is:

```sh
brew install --cask berkinduz/tap/berkinduz-slip
```

The cask declares macOS 14+ and Apple Silicon, installs `Slip.app`, and includes no command that removes a user's notebook or backups. It does not bypass Gatekeeper or remove quarantine attributes. The app and DMG are ad hoc signed, without Developer ID or notarization; macOS can require manual approval on first launch. See [Apple's opening-app guidance](https://support.apple.com/en-us/102445).

A custom tap is separate from admission to the official Homebrew catalog. That catalog's [acceptance policy](https://docs.brew.sh/Acceptable-Casks) includes macOS security checks and separate package acceptance requirements.
