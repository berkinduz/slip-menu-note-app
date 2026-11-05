#!/usr/bin/env python3
"""Prepare a local cask for the exact versioned release DMG; publish nothing."""
import argparse
import hashlib
import plistlib
from pathlib import Path


def main():
    project = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dmg", type=Path, help="The exact DMG that will be distributed")
    parser.add_argument("--output", type=Path, default=project / "distribution/homebrew/Casks/berkinduz-slip.rb")
    args = parser.parse_args()
    with (project / "Resources/Info.plist").open("rb") as file:
        version = plistlib.load(file)["CFBundleShortVersionString"]
    expected = "Slip-v{}-macos-arm64.dmg".format(version)
    if not args.dmg.is_file() or args.dmg.name != expected:
        parser.error("Provide the versioned release artifact named " + expected)
    digest = hashlib.sha256()
    with args.dmg.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    template = (project / "distribution/homebrew/Casks/berkinduz-slip.rb.in").read_text()
    output = template.replace("@VERSION@", version).replace("@SHA256@", digest.hexdigest())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(output)
    print("Prepared " + str(args.output.resolve()))
    print("Publish this exact DMG before distributing the cask. No release or tap was published.")


if __name__ == "__main__":
    main()
