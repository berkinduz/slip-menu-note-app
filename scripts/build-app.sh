#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
build_dir="${SLIP_BUILD_DIR:-$project_dir/.build}"
app_dir="${1:-$project_dir/../Slip.app}"
export CLANG_MODULE_CACHE_PATH="$build_dir/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$build_dir/module-cache"

swift build --disable-sandbox -c release --package-path "$project_dir" \
    --scratch-path "$build_dir" --cache-path "$build_dir/swift-cache" \
    --config-path "$build_dir/swift-config" --security-path "$build_dir/swift-security"

mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$build_dir/release/Slip" "$app_dir/Contents/MacOS/Slip"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
cp "$project_dir/Resources/THIRD-PARTY-NOTICES.txt" "$app_dir/Contents/Resources/THIRD-PARTY-NOTICES.txt"
printf 'APPL????' > "$app_dir/Contents/PkgInfo"

iconset_dir="$build_dir/Slip.iconset"
mkdir -p "$iconset_dir"
icon_generator_dir="$build_dir/icon-generator"
mkdir -p "$icon_generator_dir"
cp "$project_dir/scripts/GenerateIcon.swift" "$icon_generator_dir/main.swift"
swiftc -module-cache-path "$build_dir/module-cache" "$project_dir/Sources/Slip/SlipMarkImage.swift" "$icon_generator_dir/main.swift" -o "$icon_generator_dir/GenerateIcon"
"$icon_generator_dir/GenerateIcon" "$iconset_dir" "$app_dir/Contents/Resources/Slip.icns" "$build_dir/SlipMenuMark.png"
codesign --force --sign - "$app_dir"
codesign --verify --strict "$app_dir"
printf '\nBuilt %s\n' "$app_dir"
