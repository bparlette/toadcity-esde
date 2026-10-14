#!/bin/bash
# Toad City Baltimore: removes what install_mac.sh added (safe to run more than once).
#   bash uninstall_mac.sh            keeps your saves (~/Library/Application Support/Toad City Baltimore)
#   bash uninstall_mac.sh --purge    also deletes the saves
# Your other ES-DE systems and find rules are kept; the custom files are backed up before the toadcity entries are removed.
set -euo pipefail
APP_NAME="Toad City Baltimore"; SYS="toadcity"; STAMP="$(date +%Y%m%d-%H%M%S)"
ESDE_DIR="${ESDE_DIR:-$HOME/ES-DE}"; APP_DIR="${APP_DIR:-$HOME/Applications}"; SETTINGS="$ESDE_DIR/settings/es_settings.xml"
say() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
setting() { [ -f "$SETTINGS" ] || return 0; sed -n "s/.*<string name=\"$1\" value=\"\([^\"]*\)\".*/\1/p" "$SETTINGS" | head -n1; }
[ "$(uname -s)" = "Darwin" ] || { echo "This is for macOS."; exit 1; }
if pgrep -xq ES-DE 2>/dev/null; then echo "Quit ES-DE first, then run this again."; exit 1; fi
if [ -z "${ROMS_DIR:-}" ]; then r="$(setting ROMDirectory)"; if [ -n "$r" ] && [[ "$r" != *%ESPATH%* ]]; then ROMS_DIR="${r/#\~/$HOME}"; else ROMS_DIR="$HOME/ROMs"; fi; fi
if [ -z "${MEDIA_DIR:-}" ]; then m="$(setting MediaDirectory)"; if [ -n "$m" ] && [[ "$m" != *%ESPATH%* ]]; then MEDIA_DIR="${m/#\~/$HOME}"; else MEDIA_DIR="$ESDE_DIR/downloaded_media"; fi; fi

pgrep -xq "$APP_NAME" 2>/dev/null && { osascript -e "quit app \"$APP_NAME\"" >/dev/null 2>&1 || true; sleep 1; }
for a in "$APP_DIR/$APP_NAME.app" "/Applications/$APP_NAME.app"; do [ -d "$a" ] && { rm -rf "$a"; say "Removed $a"; }; done

# drop_block <file> <start regex> <end regex> <identity regex>
drop_block() {
  local f="$1" st="$2" en="$3" id="$4" tmp
  [ -f "$f" ] && grep -Eq "$id" "$f" || return 0
  tmp="$(mktemp)"
  awk -v st="$st" -v en="$en" -v id="$id" '
    !inb && $0 ~ st { inb=1; buf=$0 "\n"; keep=($0 !~ id); if ($0 ~ en) { if (keep) printf "%s", buf; inb=0 } next }
    inb { buf = buf $0 "\n"; if ($0 ~ id) keep=0; if ($0 ~ en) { if (keep) printf "%s", buf; inb=0; buf="" } next }
    { print }' "$f" > "$tmp"
  cp -p "$f" "$f.backup-$STAMP"
  if grep -Eq "$st" "$tmp"; then cat "$tmp" > "$f"; say "Removed $SYS from $f (backup: $f.backup-$STAMP)"
  else rm -f "$f"; say "Removed $f (it only held $SYS; backup: $f.backup-$STAMP)"; fi
  rm -f "$tmp"
}
drop_block "$ESDE_DIR/custom_systems/es_systems.xml" '<system>' '</system>' "<name>[[:space:]]*$SYS[[:space:]]*</name>"
drop_block "$ESDE_DIR/custom_systems/es_find_rules.xml" '<emulator[[:space:]>]' '</emulator>' 'name="TOADCITY"'

rm -f "$ROMS_DIR/$SYS/$APP_NAME.toadcity"; rmdir "$ROMS_DIR/$SYS" 2>/dev/null && say "Removed $ROMS_DIR/$SYS" || true
[ -d "$MEDIA_DIR/$SYS" ] && { rm -rf "$MEDIA_DIR/$SYS"; say "Removed $MEDIA_DIR/$SYS"; }
[ -d "$ESDE_DIR/gamelists/$SYS" ] && { rm -rf "$ESDE_DIR/gamelists/$SYS"; say "Removed $ESDE_DIR/gamelists/$SYS"; }
if [ "${1:-}" = "--purge" ]; then rm -rf "$HOME/Library/Application Support/$APP_NAME"; say "Removed saves"; else say "Saves kept in ~/Library/Application Support/$APP_NAME (use --purge to delete)"; fi
say "Done. Start ES-DE: the Toad City Baltimore system is gone."
