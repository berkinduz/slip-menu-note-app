# Homebrew distribution

Slip is distributed through [berkinduz/homebrew-tap](https://github.com/berkinduz/homebrew-tap):

```sh
brew install --cask berkinduz/tap/berkinduz-slip
```

To update, run `brew update` followed by `brew upgrade --cask berkinduz/tap/berkinduz-slip`. If you installed the app manually before using Homebrew, quit Slip and move that app out of Applications before installing the cask. Your notebook is stored separately in Application Support.

## Maintaining the cask

Generate the cask from the exact published DMG:

```sh
python3 scripts/prepare-homebrew.py .build/artifacts/Slip-v0.3.0-macos-arm64.dmg
ruby -c distribution/homebrew/Casks/berkinduz-slip.rb
```

If CI rebuilds the DMG, regenerate the cask from the actual published asset: rebuilding, signing or repackaging can change its checksum. The input filename must match the version in `Resources/Info.plist`. Do not substitute a placeholder checksum.

After publishing a new release, copy the generated file to `Casks/berkinduz-slip.rb` in the tap and commit it. The generator only writes a local file; it does not publish a release or update the tap.

The cask declares macOS 14+ and Apple Silicon, installs `Slip.app`, and includes no command that removes a user's notebook or backups. It does not bypass Gatekeeper or remove quarantine attributes. The app and DMG are ad hoc signed, without Developer ID or notarization; macOS can require manual approval on first launch. See [Apple's opening-app guidance](https://support.apple.com/en-us/102445).

A custom tap is separate from admission to the official Homebrew catalog. That catalog's [acceptance policy](https://docs.brew.sh/Acceptable-Casks) includes macOS security checks and separate package acceptance requirements.
