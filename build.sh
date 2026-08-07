#!/bin/bash
#
# Builds GhosttyToggle.app and installs it to ~/Applications.
#
#   ./build.sh            build, sign, install to ~/Applications
#   ./build.sh --no-install   build only (leaves build/GhosttyToggle.app)
#
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="GhosttyToggle"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"
INSTALL_DIR="$HOME/Applications"
DEPLOYMENT_TARGET="13.0"

INSTALL=1
[[ "${1:-}" == "--no-install" ]] && INSTALL=0

echo "==> Cleaning $BUILD_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "==> Compiling (arm64 + x86_64, target macOS $DEPLOYMENT_TARGET)"
for arch in arm64 x86_64; do
	swiftc -O \
		-target "${arch}-apple-macos${DEPLOYMENT_TARGET}" \
		-framework AppKit -framework Carbon -framework ServiceManagement \
		-o "$BUILD_DIR/$APP_NAME.$arch" \
		Sources/main.swift
done
lipo -create -output "$APP/Contents/MacOS/$APP_NAME" \
	"$BUILD_DIR/$APP_NAME.arm64" "$BUILD_DIR/$APP_NAME.x86_64"
rm -f "$BUILD_DIR/$APP_NAME.arm64" "$BUILD_DIR/$APP_NAME.x86_64"

echo "==> Assembling bundle"
cp Resources/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Ad-hoc signing"
codesign --force --sign - --identifier com.mihasic.ghostty-toggle "$APP"
codesign --verify --strict "$APP"

if [[ "$INSTALL" == "1" ]]; then
	echo "==> Installing to $INSTALL_DIR"
	mkdir -p "$INSTALL_DIR"
	# Stop any running copy so the replaced binary is the one relaunched.
	pkill -x "$APP_NAME" 2>/dev/null || true
	rm -rf "$INSTALL_DIR/$APP_NAME.app"
	cp -R "$APP" "$INSTALL_DIR/$APP_NAME.app"
	echo "==> Launching"
	# `env -i` so launchd supplies the same environment as a Finder/login launch
	# instead of pinning this shell's into every terminal. Absolute path: no PATH.
	env -i /usr/bin/open "$INSTALL_DIR/$APP_NAME.app"
	echo
	echo "Done. Ctrl+\` now toggles Ghostty."
	echo "Registered as a login item (approve in System Settings > General > Login Items if prompted)."
else
	echo
	echo "Done: $APP (not installed)."
fi
