#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
swift build -c release
BIN=$(swift build -c release --show-bin-path)
APP="$ROOT/build/Limpador.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Limpador" "$APP/Contents/MacOS/Limpador"
cp "$ROOT/config/Info.plist" "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
printf 'Aplicativo criado: %s\n' "$APP"
