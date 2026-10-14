#!/bin/bash
# Toad City Baltimore -> macOS + ES-DE installer (idempotent: safe to run again, e.g. to update).
#
#   curl -fsSL https://raw.githubusercontent.com/bparlette/Hawk/toadcity/desktop/install_mac.sh | bash
#   or: bash install_mac.sh
#
# 1. Downloads the newest "desktop-v*" GitHub release of bparlette/Hawk (universal arm64+x64 app zip + ES-DE kit zip).
# 2. Installs "Toad City Baltimore.app" to ~/Applications and removes the download quarantine (the app is not Apple-signed).
# 3. Installs the ES-DE "toadcity" system: merges it into ~/ES-DE/custom_systems/es_systems.xml and es_find_rules.xml
#    (existing files are backed up first and your other systems are kept), the ROM stub into ~/ROMs/toadcity, the
#    gamelist and the media (screenshot, marquee, video, ...).
# Env overrides: TAG=desktop-vN (a specific release), APP_ZIP=/path.zip and ESDE_ZIP=/path.zip (local files, no download),
#   ESDE_DIR (default ~/ES-DE), ROMS_DIR, MEDIA_DIR (default: read from ES-DE settings, else ~/ROMs and ~/ES-DE/downloaded_media),
#   APP_DIR (default ~/Applications), FORCE_GAMELIST=1 (overwrite an existing toadcity gamelist; by default it is kept so
#   ES-DE's play counts survive).
set -euo pipefail
REPO="bparlette/Hawk"
APP_NAME="Toad City Baltimore"
APP_ASSET="ToadCityBaltimore-mac-universal.zip"
ESDE_ASSET="ToadCityBaltimore-esde.zip"
SYS="toadcity"
STAMP="$(date +%Y%m%d-%H%M%S)"
ESDE_DIR="${ESDE_DIR:-$HOME/ES-DE}"
APP_DIR="${APP_DIR:-$HOME/Applications}"
SETTINGS="$ESDE_DIR/settings/es_settings.xml"

say()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
setting() { [ -f "$SETTINGS" ] || return 0; sed -n "s/.*<string name=\"$1\" value=\"\([^\"]*\)\".*/\1/p" "$SETTINGS" | head -n1; }

[ "$(uname -s)" = "Darwin" ] || die "This installer is for macOS."
if pgrep -xq ES-DE 2>/dev/null; then die "ES-DE is running. Quit it first (it rewrites its files on exit), then run this again."; fi

if [ -z "${ROMS_DIR:-}" ]; then r="$(setting ROMDirectory)"; if [ -n "$r" ] && [[ "$r" != *%ESPATH%* ]]; then ROMS_DIR="${r/#\~/$HOME}"; else ROMS_DIR="$HOME/ROMs"; fi; fi
if [ -z "${MEDIA_DIR:-}" ]; then m="$(setting MediaDirectory)"; if [ -n "$m" ] && [[ "$m" != *%ESPATH%* ]]; then MEDIA_DIR="${m/#\~/$HOME}"; else MEDIA_DIR="$ESDE_DIR/downloaded_media"; fi; fi

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
# When this script is run from the unzipped ES-DE kit (ToadCityBaltimore-esde.zip), use that kit and look for the app zip
# next to it or in ~/Downloads before downloading anything. (When piped from curl there is no script dir.)
HERE=""; if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; fi
LOCAL_KIT=""; if [ -z "${ESDE_ZIP:-}" ] && [ -n "$HERE" ] && [ -f "$HERE/custom_systems/es_systems.xml" ]; then LOCAL_KIT="$HERE"; fi
if [ -z "${APP_ZIP:-}" ] && [ -n "$LOCAL_KIT" ]; then
  for z in "$HERE/$APP_ASSET" "$HERE/../$APP_ASSET" "$HOME/Downloads/$APP_ASSET"; do [ -f "$z" ] && { APP_ZIP="$z"; break; }; done
fi

# ---------------------------------------------------------------- 1. download
asset_url() { # $1 = asset file name; picks it from $TAG, or from the newest desktop-v* release (pre-releases included)
  local json url
  if [ -n "${TAG:-}" ]; then printf 'https://github.com/%s/releases/download/%s/%s' "$REPO" "$TAG" "$1"; return; fi
  # the GitHub API lists pre-releases newest first; if it is unreachable or rate-limited, use the rolling desktop-latest release
  json="$(curl -fsSL -H 'Accept: application/vnd.github+json' "https://api.github.com/repos/$REPO/releases?per_page=50" 2>/dev/null || true)"
  url="$(printf '%s\n' "$json" | grep -o "\"browser_download_url\": *\"[^\"]*/releases/download/desktop-v[0-9][^\"/]*/$1\"" | head -n1 | sed 's/.*"\(https[^"]*\)"$/\1/' || true)"
  [ -n "$url" ] || url="https://github.com/$REPO/releases/download/desktop-latest/$1"
  printf '%s' "$url"
}
fetch() { # $1 asset, $2 local override, $3 dest
  if [ -n "$2" ]; then [ -f "$2" ] || die "$2 not found"; cp "$2" "$3"; say "Using local $2"; return; fi
  local u; u="$(asset_url "$1")"; say "Downloading $u"
  curl -fL --retry 3 --progress-bar -o "$3" "$u" || die "Download failed: $u"
}
fetch "$APP_ASSET" "${APP_ZIP:-}" "$WORK/app.zip"
mkdir -p "$WORK/app" "$WORK/esde"
ditto -x -k "$WORK/app.zip" "$WORK/app"
if [ -n "$LOCAL_KIT" ]; then say "Using the ES-DE kit next to this script: $LOCAL_KIT"; cp -R "$LOCAL_KIT/." "$WORK/esde/"
else fetch "$ESDE_ASSET" "${ESDE_ZIP:-}" "$WORK/esde.zip"; ditto -x -k "$WORK/esde.zip" "$WORK/esde"; fi
SRC_APP="$(find "$WORK/app" -maxdepth 2 -name "$APP_NAME.app" -type d | head -n1)"
[ -n "$SRC_APP" ] || die "The app zip has no '$APP_NAME.app'."
KIT="$(find "$WORK/esde" -maxdepth 2 -type d -name custom_systems | head -n1)"; KIT="$(dirname "${KIT:-$WORK/esde/x}")"
[ -f "$KIT/custom_systems/es_systems.xml" ] || die "The ES-DE kit zip is missing custom_systems/es_systems.xml."

# ---------------------------------------------------------------- 2. the app
mkdir -p "$APP_DIR"
DST_APP="$APP_DIR/$APP_NAME.app"
[ -d "$DST_APP" ] && { say "Replacing $DST_APP (saves are kept in ~/Library/Application Support/$APP_NAME)"; rm -rf "$DST_APP"; }
ditto "$SRC_APP" "$DST_APP"
# Unsigned app: drop the download quarantine so Gatekeeper lets ES-DE start it.
xattr -dr com.apple.quarantine "$DST_APP" 2>/dev/null || true
if ! codesign --verify --deep "$DST_APP" >/dev/null 2>&1; then
  say "Re-signing ad-hoc (local only, no Apple ID needed)"
  codesign --force --deep --sign - "$DST_APP" >/dev/null 2>&1 || warn "codesign failed; if macOS blocks the app, right-click it in Finder > Open once."
fi
say "App -> $DST_APP ($(file -b "$DST_APP/Contents/MacOS/$APP_NAME" | head -n1))"
if [ "$DST_APP" != "/Applications/$APP_NAME.app" ] && [ -w "/Applications" ]; then
  ln -sf "$DST_APP" "/Applications/$APP_NAME.app" 2>/dev/null && say "Linked -> /Applications/$APP_NAME.app" || true
fi

# ---------------------------------------------------------------- 3. ES-DE
# merge_block <target file> <kit file> <start-tag regex> <end-tag regex> <identity regex> <root close tag> <root open line>
# Removes any earlier copy of our block from the target, inserts the kit's block before the root close tag.
# Writes only when something changes, and backs the old file up first.
merge_block() {
  local target="$1" kit="$2" st="$3" en="$4" id="$5" rclose="$6" ropen="$7" bf tmp
  bf="$WORK/block.$$"; tmp="$WORK/merged.$$"
  awk -v st="$st" -v en="$en" 'f || $0 ~ st { f=1; print } f && $0 ~ en { exit }' "$kit" > "$bf"
  mkdir -p "$(dirname "$target")"
  if [ ! -f "$target" ]; then cp "$kit" "$target"; say "Created $target"; return; fi
  awk -v bf="$bf" -v st="$st" -v en="$en" -v id="$id" -v rc="$rclose" -v ro="$ropen" '
    BEGIN { while ((getline l < bf) > 0) block = block l "\n" }
    !inb && $0 ~ st { inb=1; buf=$0 "\n"; keep=($0 !~ id); if ($0 ~ en) { if (keep) printf "%s", buf; inb=0 } next }
    inb { buf = buf $0 "\n"; if ($0 ~ id) keep=0; if ($0 ~ en) { if (keep) printf "%s", buf; inb=0; buf="" } next }
    index($0, rc) && !done { printf "%s", block; done=1 }
    { print }
    END { if (!done) { print ro; printf "%s", block; print rc } }' "$target" > "$tmp" || die "awk failed merging into $target (file untouched)"
  grep -Eq "$id" "$tmp" && grep -q "$rclose" "$tmp" || die "Could not merge into $target automatically; it is untouched. Add the block from $kit by hand."
  if cmp -s "$tmp" "$target"; then say "$target already up to date"; return; fi
  cp -p "$target" "$target.backup-$STAMP"; say "Backed up $target -> $target.backup-$STAMP"
  cat "$tmp" > "$target"; say "Merged $SYS into $target"
}
CS="$ESDE_DIR/custom_systems"
merge_block "$CS/es_systems.xml" "$KIT/custom_systems/es_systems.xml" '<system>' '</system>' "<name>[[:space:]]*$SYS[[:space:]]*</name>" '</systemList>' '<systemList>'
merge_block "$CS/es_find_rules.xml" "$KIT/custom_systems/es_find_rules.xml" '<emulator[[:space:]>]' '</emulator>' 'name="TOADCITY"' '</ruleList>' '<ruleList>'

mkdir -p "$ROMS_DIR/$SYS"
cp -f "$KIT/roms/$SYS/$APP_NAME.toadcity" "$ROMS_DIR/$SYS/"; chmod +x "$ROMS_DIR/$SYS/$APP_NAME.toadcity"
xattr -dr com.apple.quarantine "$ROMS_DIR/$SYS" 2>/dev/null || true
say "ROM stub -> $ROMS_DIR/$SYS/$APP_NAME.toadcity"

GL="$ESDE_DIR/gamelists/$SYS/gamelist.xml"; mkdir -p "$(dirname "$GL")"
if [ -f "$GL" ] && grep -q "$APP_NAME.toadcity" "$GL" && [ "${FORCE_GAMELIST:-0}" != "1" ]; then
  say "Gamelist kept ($GL already lists the game; FORCE_GAMELIST=1 replaces it)"
else
  [ -f "$GL" ] && cp -p "$GL" "$GL.backup-$STAMP"
  cp -f "$KIT/gamelists/$SYS/gamelist.xml" "$GL"; say "Gamelist -> $GL"
fi

mkdir -p "$MEDIA_DIR/$SYS"
ditto "$KIT/downloaded_media/$SYS" "$MEDIA_DIR/$SYS"
xattr -dr com.apple.quarantine "$MEDIA_DIR/$SYS" 2>/dev/null || true
say "Media -> $MEDIA_DIR/$SYS ($(cd "$MEDIA_DIR/$SYS" && ls | tr '\n' ' '))"

cat <<EOF

$(say "Done.")
VERIFY
  1. Start ES-DE. A "Toad City Baltimore" system appears in the system carousel (with ES-DE's "ports" theme art),
     with one game showing the screenshot, marquee and video.
     If it is missing: ES-DE > Main menu > Utilities > Rescan ROM directory, then check ~/ES-DE/logs/es_log.txt for "toadcity".
  2. Launch it: the game opens fullscreen, no cursor, the Xbox controller works right away
     (A jump, X/B swing, Y act, LB/RB turn camera, View map, Start pause).
  3. Hold View+Start (the two small buttons) or Esc for 1 second: the game quits and ES-DE comes back. (Cmd+Q also works.)
  Quick checks from Terminal:
     file "$DST_APP/Contents/MacOS/$APP_NAME"                 # -> universal binary, x86_64 + arm64
     xattr -l "$DST_APP" | grep -c quarantine || true          # -> 0
     open -W -a "$DST_APP"                                      # runs it without ES-DE
  If macOS still says the app is damaged or can't be opened:  xattr -dr com.apple.quarantine "$DST_APP"
  Uninstall: bash uninstall_mac.sh  (or curl -fsSL https://raw.githubusercontent.com/$REPO/toadcity/desktop/uninstall_mac.sh | bash)
EOF
