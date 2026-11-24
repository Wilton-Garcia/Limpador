#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
if [ -n "${LIMPADOR_NOTARY_PROFILE:-}" ] && { [ -z "${LIMPADOR_SIGNING_IDENTITY:-}" ] || [ "$LIMPADOR_SIGNING_IDENTITY" = - ]; }; then
    printf 'Notarization requires an existing Developer ID signing identity.\n' >&2
    exit 2
fi
LIMPADOR_UNIVERSAL=1 "$ROOT/scripts/build-app.sh"
APP="$ROOT/build/Limpador.app"
ARCHIVE="$ROOT/build/Limpador-local.zip"
if [ -n "${LIMPADOR_SIGNING_IDENTITY:-}" ] && [ "$LIMPADOR_SIGNING_IDENTITY" != - ]; then
    ARCHIVE="$ROOT/build/Limpador-signed.zip"
fi
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ARCHIVE"
if [ -n "${LIMPADOR_NOTARY_PROFILE:-}" ]; then
    xcrun notarytool submit "$ARCHIVE" --keychain-profile "$LIMPADOR_NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP"
    xcrun stapler validate "$APP"
    spctl --assess --type execute "$APP"
    ditto -c -k --sequesterRsrc --keepParent "$APP" "$ARCHIVE"
fi
shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256"
printf 'Archive: %s\n' "$ARCHIVE"
if [ -z "${LIMPADOR_NOTARY_PROFILE:-}" ]; then
    printf 'Not notarized. Configure Developer ID and a Keychain notary profile for public distribution.\n'
fi
