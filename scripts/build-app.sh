#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
case "${LIMPADOR_UNIVERSAL:-0}" in
    0) set -- ;;
    1) set -- --arch arm64 --arch x86_64 ;;
    *) printf 'LIMPADOR_UNIVERSAL must be 0 or 1.\n' >&2; exit 2 ;;
esac
swift build -c release "$@"
BIN=$(swift build -c release "$@" --show-bin-path)
APP="$ROOT/build/Limpador.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Limpador" "$APP/Contents/MacOS/Limpador"
cp "$ROOT/config/Info.plist" "$APP/Contents/Info.plist"
xcrun swift -module-cache-path "$ROOT/.build/icon-module-cache" "$ROOT/scripts/make-icon.swift" "$ROOT/build/AppIcon.iconset"
iconutil -c icns "$ROOT/build/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
taskSigningIdentity=${LIMPADOR_SIGNING_IDENTITY:--}
if [ "$taskSigningIdentity" = - ]; then
    codesign --force --sign - "$APP"
else
    codesign --force --options runtime --timestamp --sign "$taskSigningIdentity" "$APP"
fi
codesign --verify --strict "$APP"
printf 'Aplicativo criado: %s\n' "$APP"
