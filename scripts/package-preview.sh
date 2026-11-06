#!/bin/bash
set -euo pipefail

# Creates a local, ad-hoc signed preview. It never publishes or submits to Apple.
shelf_repo_root="$(cd "$(dirname "$0")/.." && pwd)"
shelf_output_dir="${1:-"$shelf_repo_root/dist"}"
mkdir -p "$shelf_output_dir"
shelf_output_dir="$(cd "$shelf_output_dir" && pwd)"
shelf_work_dir="$(mktemp -d /private/tmp/ShelfPreview.XXXXXX)"
printf 'Building Release preview; temporary files: %s\n' "$shelf_work_dir"

xcodebuild -quiet build \
    -project "$shelf_repo_root/Shelf.xcodeproj" -scheme Shelf \
    -configuration Release -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$shelf_work_dir/DerivedData" \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO

shelf_built_app="$shelf_work_dir/DerivedData/Build/Products/Release/Shelf.app"
shelf_version="$(plutil -extract CFBundleShortVersionString raw "$shelf_built_app/Contents/Info.plist")"
shelf_build="$(plutil -extract CFBundleVersion raw "$shelf_built_app/Contents/Info.plist")"
shelf_minimum_os="$(plutil -extract LSMinimumSystemVersion raw "$shelf_built_app/Contents/Info.plist")"
shelf_package_name="Shelf-$shelf_version-preview.4-arm64"
shelf_zip="$shelf_output_dir/$shelf_package_name.zip"
if [[ -e "$shelf_zip" || -e "$shelf_zip.sha256" ]]; then
    printf 'Refusing to overwrite an existing package. Choose a new output directory.\n' >&2
    exit 1
fi

shelf_stage="$shelf_work_dir/$shelf_package_name"
mkdir -p "$shelf_stage"
ditto "$shelf_built_app" "$shelf_stage/Shelf.app"
shelf_archs="$(lipo -archs "$shelf_stage/Shelf.app/Contents/MacOS/Shelf")"
if [[ "$shelf_archs" != arm64 ]]; then
    printf 'Unexpected architectures: %s\n' "$shelf_archs" >&2
    exit 1
fi

codesign --force --sign - --options runtime --timestamp=none \
    --entitlements "$shelf_repo_root/Shelf/Shelf.entitlements" "$shelf_stage/Shelf.app"
codesign --verify --deep --strict "$shelf_stage/Shelf.app"
codesign --display --entitlements - --xml "$shelf_stage/Shelf.app" > "$shelf_work_dir/entitlements.plist"
for shelf_entitlement in com.apple.security.app-sandbox com.apple.security.files.user-selected.read-write; do
    if [[ "$(/usr/libexec/PlistBuddy -c "Print :$shelf_entitlement" "$shelf_work_dir/entitlements.plist")" != true ]]; then
        printf 'Missing entitlement: %s\n' "$shelf_entitlement" >&2
        exit 1
    fi
done

cp "$shelf_repo_root/docs/PREVIEW_README.txt" "$shelf_stage/README.txt"
cp "$shelf_repo_root/LICENSE" "$shelf_stage/LICENSE"
shelf_source_commit="$(git -C "$shelf_repo_root" rev-parse HEAD)"
shelf_source_state=clean
if [[ -n "$(git -C "$shelf_repo_root" status --porcelain)" ]]; then
    shelf_source_state='includes uncommitted changes'
fi
cat > "$shelf_stage/BUILD.txt" <<EOF
Shelf $shelf_version preview.4 (build $shelf_build)
Architecture: $shelf_archs
Minimum macOS: $shelf_minimum_os
Signing: ad-hoc; no Developer ID; NOT notarized
Source commit: $shelf_source_commit
Working tree: $shelf_source_state
EOF

ditto -c -k --sequesterRsrc --keepParent "$shelf_stage" "$shelf_zip"
(
    cd "$shelf_output_dir"
    shasum -a 256 "$shelf_package_name.zip" > "$shelf_package_name.zip.sha256"
    shasum -a 256 -c "$shelf_package_name.zip.sha256"
)
printf 'Preview: %s\nChecksum: %s.sha256\n' "$shelf_zip" "$shelf_zip"
printf 'Not notarized. Download/install and sandbox behavior still require manual acceptance.\n'
