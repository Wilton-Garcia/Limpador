#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
taskInstallDirectory="$HOME/Applications"
taskApprove=0
taskDryRun=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --destination) [ "$#" -ge 2 ] || exit 2; taskInstallDirectory=$2; shift 2 ;;
        --yes) taskApprove=1; shift ;;
        --dry-run) taskDryRun=1; shift ;;
        *) printf 'Usage: install-local.sh [--destination DIRECTORY] [--dry-run] [--yes]\n' >&2; exit 2 ;;
    esac
done
taskSource="$ROOT/build/Limpador.app"
taskTarget="$taskInstallDirectory/Limpador.app"
[ -d "$taskSource" ] || { printf 'Build Limpador.app first with scripts/build-app.sh.\n' >&2; exit 1; }
taskExpectedID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$taskSource/Contents/Info.plist")
[ "$taskExpectedID" = local.limpador.app ] || { printf 'Unexpected source bundle identifier.\n' >&2; exit 1; }
codesign --verify --strict "$taskSource"
[ ! -L "$taskTarget" ] || { printf 'Refusing a symlink destination: %s\n' "$taskTarget" >&2; exit 1; }
if [ -e "$taskTarget" ]; then
    taskExistingID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$taskTarget/Contents/Info.plist")
    [ "$taskExistingID" = "$taskExpectedID" ] || { printf 'Destination is a different application.\n' >&2; exit 1; }
    if codesign --verify --strict "$taskTarget" 2>/dev/null && cmp -s "$taskSource/Contents/MacOS/Limpador" "$taskTarget/Contents/MacOS/Limpador" && cmp -s "$taskSource/Contents/Info.plist" "$taskTarget/Contents/Info.plist" && cmp -s "$taskSource/Contents/Resources/AppIcon.icns" "$taskTarget/Contents/Resources/AppIcon.icns"; then
        printf 'Already installed with identical application contents: %s\n' "$taskTarget"
        exit 0
    fi
fi
printf 'Source: %s\nDestination: %s\nExisting versions are retained in a sibling .Limpador-backup directory.\n' "$taskSource" "$taskTarget"
[ "$taskDryRun" -eq 0 ] || exit 0
if [ "$taskApprove" -eq 0 ]; then
    printf 'Install this local build? [y/N] '
    read -r taskAnswer
    case "$taskAnswer" in y|Y|s|S) ;; *) exit 0 ;; esac
fi
mkdir -p "$taskInstallDirectory"
taskStage=$(mktemp -d "$taskInstallDirectory/.Limpador-stage.XXXXXX")
taskBackup=
cleanup() {
    if [ -n "$taskStage" ] && [ -d "$taskStage" ]; then rm -rf -- "$taskStage"; fi
}
trap cleanup EXIT HUP INT TERM
ditto "$taskSource" "$taskStage/Limpador.app"
codesign --verify --strict "$taskStage/Limpador.app"
if [ -e "$taskTarget" ]; then
    taskBackup=$(mktemp -d "$taskInstallDirectory/.Limpador-backup.XXXXXX")
    mv "$taskTarget" "$taskBackup/Limpador.app"
fi
if ! mv "$taskStage/Limpador.app" "$taskTarget"; then
    if [ -n "$taskBackup" ]; then mv "$taskBackup/Limpador.app" "$taskTarget"; fi
    exit 1
fi
codesign --verify --strict "$taskTarget"
printf 'Installed: %s\n' "$taskTarget"
if [ -n "$taskBackup" ]; then printf 'Previous version: %s/Limpador.app\n' "$taskBackup"; fi
