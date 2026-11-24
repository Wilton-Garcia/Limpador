#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
taskNativeArchitecture=$(uname -m)
case "$taskNativeArchitecture" in
    arm64) taskOtherArchitecture=x86_64 ;;
    x86_64) taskOtherArchitecture=arm64 ;;
    *) printf 'Unsupported host architecture: %s\n' "$taskNativeArchitecture" >&2; exit 1 ;;
esac
printf 'Running tests natively for %s\n' "$taskNativeArchitecture"
swift test --arch "$taskNativeArchitecture"
printf 'Cross-compiling %s (not executing its tests on this host)\n' "$taskOtherArchitecture"
swift build --arch "$taskOtherArchitecture"
printf 'Use the separate native Intel and Apple Silicon CI jobs for both runtime validations.\n'
