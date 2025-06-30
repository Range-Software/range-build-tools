#!/usr/bin/env bash
#set -euo pipefail

# Configuration section - Begin -------------------------------------------

myName=$(basename $0 .sh)

getToolsPath()
{
    pushd "$(echo ${0%/*}/)" &> /dev/null
    local _toolsPath="$(pwd)"
    popd &> /dev/null
    echo $_toolsPath
}
myPath=$(getToolsPath)

. $myPath/lib.sh

appBundle=
appBundleName=
icon=
background=
dsStore=

# Configuration section - End ---------------------------------------------

# Argument parsing section - Begin ----------------------------------------

print_help()
{
cat <<End-of-help
Usage: $myName.sh [OPTION]...

  mandatory

    --app-bundle=[PATH]                Path to application bundle
    --ds_store=[PATH]                  Path to target .DS_Store
    --icon=[PATH]                      Path to volume icon

  optional

    --background=[PATH]                Path to background image of size 640x480

    --help, -h, -?                     Print this help and exit
End-of-help
}

while [ $# -gt 0 ]
do
    case $1 in
        --app-bundle=*)
            appBundle=$(extract_cmd_parameter_value "$1")
            ;;
        --icon=*)
            icon=$(extract_cmd_parameter_value "$1")
            ;;
        --background=*)
            background=$(extract_cmd_parameter_value "$1")
            ;;
        --ds-store=*)
            dsStore=$(extract_cmd_parameter_value "$1")
            ;;
        --help | -h | -?)
            print_help
            exit 0
            ;;
        *)
            echo_e "Unknown parameter '$1'"
            print_help
            exit 1
            ;;
    esac
    shift
done

assert_nonempty "$appBundle" "Path to app bundle was not provided."
assert_nonempty "$icon" "Path to icon was not provided."
assert_nonempty "$background" "Path to background was not provided."
assert_nonempty "$dsStore" "Path .DS_Store file was not provided."

# Argument parsing section - End ------------------------------------------

# Set-up section - Begin --------------------------------------------------

WORK_DIR="$(pwd)/dmgRoot"                 # staging directory
DMG_NAME="temp-layout.dmg"
VOL_NAME="TEMP_LAYOUT"

APP_POS="{200, 190}"                      # icon coordinates in Finder
ALIAS_POS="{600, 185}"
ICON_SIZE="128"
WINDOW_SIZE="{200, 120, 1000, 520}"

appBundleName=$(basename "$appBundle")

# Set-up section - End ----------------------------------------------------

# Prepare staging directory
rm -rf "$WORK_DIR" && \
mkdir -p "$WORK_DIR/.background" && \
cp -v "$background" "$WORK_DIR/.background/" && \
cp -vR "$appBundle" "$WORK_DIR/" && \
ln -vs /Applications "$WORK_DIR/Applications"
assert_success $? "Failed to prepare staging directory" true

# Create & mount a temporary RW dmg
hdiutil create -ov -srcfolder "$WORK_DIR" \
               -volname "$VOL_NAME"       \
               -fs HFS+                   \
               -format UDRW "$DMG_NAME"
assert_success $? "Failed to create temporary device" true

devID=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_NAME" | grep "^/dev/" | awk '{print $1}')
assert_success $? "Failed to mount temporary device" true
mountDir="/Volumes/$VOL_NAME"

# Run AppleScript to lay out the window

osascript <<END_SCRIPT

tell application "Finder"
    tell disk "$VOL_NAME"
        open

        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to $WINDOW_SIZE

        set opts to the icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to $ICON_SIZE
        set background picture of opts to file ".background:$(basename ${background})"

        set position of item "$appBundleName" of container window to $APP_POS
        set position of item "Applications" of container window to $ALIAS_POS

        close

        open -- reopen so Finder commits .DS_Store
        update without registering applications
        delay 1
    end tell
    do shell script "/usr/bin/SetFile -a C /Volumes/" & quoted form of "$VOL_NAME"

end tell
END_SCRIPT
assert_success $? "Failed to to execute osascript" true

# Extract the freshly-written .DS_Store
cp "$mountDir/.DS_Store" "$dsStore"
assert_success $? "Failed to extract .DS_Store" true

# Clean up
hdiutil detach "$mountDir" > /dev/null && \
rm -f "$DMG_NAME"
assert_success $? "Failed to cleanup" true

echo ".DS_Store: \"$dsStore\""

