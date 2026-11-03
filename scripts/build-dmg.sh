#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
app_dir="${1:-$project_dir/../Slip.app}"
app_dir="${app_dir:A}"
dmg_path="${2:-$project_dir/../Slip.dmg}"
dmg_path="${dmg_path:A}"
build_dir="${SLIP_DMG_BUILD_DIR:-$project_dir/.build/dmg}"
python="${SLIP_DMG_PYTHON:-python3}"

codesign --verify --strict "$app_dir"
mkdir -p "$build_dir/module-cache" "${dmg_path:h}"
swiftc -module-cache-path "$build_dir/module-cache" \
    "$project_dir/scripts/GenerateDMGBackground.swift" -o "$build_dir/GenerateDMGBackground"
"$build_dir/GenerateDMGBackground" "$build_dir/background.tiff"

"$python" -m dmgbuild -s "$project_dir/scripts/dmg-settings.py" \
    -D "app=$app_dir" -D "background=$build_dir/background.tiff" Slip "$dmg_path"
codesign --force --sign - "$dmg_path"
codesign --verify --strict "$dmg_path"
hdiutil verify "$dmg_path"
"$python" "$project_dir/scripts/verify-dmg.py" "$dmg_path"
printf '\nBuilt %s\n' "$dmg_path"
