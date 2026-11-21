#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
xcrun swiftc "$ROOT/ios/PandaWord/WordModel.swift" "$ROOT/ios/checks/main.swift" -o "$TEMP_DIR/crypto-check"
"$TEMP_DIR/crypto-check" "$ROOT/reference/aes-vectors.json"
xcodebuild -project "$ROOT/ios/PandaWord.xcodeproj" -target PandaWord -configuration Debug -sdk iphonesimulator SYMROOT="$TEMP_DIR/build" OBJROOT="$TEMP_DIR/obj" CODE_SIGNING_ALLOWED=NO build
