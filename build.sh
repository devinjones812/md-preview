#!/bin/sh
# Build "MD Preview.app" into ./build. Pass --install to copy it to /Applications.
set -e
cd "$(dirname "$0")"
APP="build/MD Preview.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O main.swift -o "$APP/Contents/MacOS/MDPreview" -framework AppKit -framework WebKit
cp Info.plist "$APP/Contents/"
cp Resources/* "$APP/Contents/Resources/"
codesign --force -s - "$APP"
echo "Built $APP"
if [ "$1" = "--install" ]; then
  rm -rf "/Applications/MD Preview.app"
  cp -R "$APP" /Applications/
  echo "Installed to /Applications/MD Preview.app"
fi
