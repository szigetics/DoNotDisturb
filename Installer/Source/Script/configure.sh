#!/bin/bash
set -e

#
#  file: configure.sh
#  project: DoNotDisturb
#  description: install/uninstall
#
#  created by Patrick Wardle
#  copyright (c) 2026 Objective-See. All rights reserved.
#

#where binary goes
INSTALL_DIRECTORY="/Library/Objective-See/DoNotDisturb"

#preferences
PREFERENCES="$INSTALL_DIRECTORY/preferences.plist"

#auth check
# gotta be root
if [ "${EUID}" -ne 0 ]; then
    echo "\nERROR: must be run as root\n"
    exit 1
fi

#install logic
if [ "${1}" == "-install" ]; then

    echo "installing"

    #change into dir
    cd "$(dirname "${0}")" || { echo "ERROR: failed to cd to script directory"; exit 1; }

    #remove all xattrs
    xattr -rc ./*

    #create main directory
    mkdir -p "$INSTALL_DIRECTORY"

    #install launch daemon
    chown -R root:wheel "DoNotDisturb.app"
    chown -R root:wheel "com.objective-see.donotdisturb.plist"

    rm -rf "$INSTALL_DIRECTORY/DoNotDisturb.app"
    cp -R "DoNotDisturb.app" "$INSTALL_DIRECTORY"
    cp "com.objective-see.donotdisturb.plist" /Library/LaunchDaemons/
    echo "launch daemon installed"

    #install app
    rm -rf "/Applications/DoNotDisturb Helper.app"
    cp -R "DoNotDisturb Helper.app" "/Applications"
    echo "app installed"

    #no preferences?
    # create defaults
    if [ ! -f "$PREFERENCES" ]; then

        /usr/libexec/PlistBuddy -c 'add disabled bool false' "$PREFERENCES"
        /usr/libexec/PlistBuddy -c 'add noIconMode bool false' "$PREFERENCES"
        /usr/libexec/PlistBuddy -c 'add passiveMode bool false' "$PREFERENCES"
        /usr/libexec/PlistBuddy -c 'add touchIDMode bool true' "$PREFERENCES"
        /usr/libexec/PlistBuddy -c 'add includeImage bool false' "$PREFERENCES"
        /usr/libexec/PlistBuddy -c 'add executeAction bool false' "$PREFERENCES"
        /usr/libexec/PlistBuddy -c 'add gotFullDiskAccess bool false' "$PREFERENCES"
    
    fi

    echo "install complete"
    exit 0

#uninstall logic
elif [ "${1}" == "-uninstall" ]; then

    echo "uninstalling"

    #kill first
    killall DoNotDisturb 2> /dev/null || true
    killall com.objective-see.donotdisturb.helper 2> /dev/null || true
    killall "DoNotDisturb Helper" 2> /dev/null || true

    #unload launch daemon & remove its plist
    launchctl bootout system /Library/LaunchDaemons/com.objective-see.donotdisturb.plist 2> /dev/null || true
    rm -f "/Library/LaunchDaemons/com.objective-see.donotdisturb.plist"
    
    echo "unloaded launch daemon"

    #remove main app/helper app
    rm -rf "/Applications/DoNotDisturb Helper.app"

    #delete keychain items (stored by daemon as root)
    security delete-generic-password -s "com.objective-see.donotdisturb.telegram" -a "telegramChatID" 2> /dev/null || true
    security delete-generic-password -s "com.objective-see.donotdisturb.telegram" -a "telegramBotID" 2> /dev/null || true
    security delete-generic-password -s "com.objective-see.donotdisturb.telegram" -a "telegramBotName" 2> /dev/null || true

    #full uninstall?
    # delete DoNotDisturb's folder w/ everything
    if [[ "${2}" == "1" ]]; then
        rm -rf "$INSTALL_DIRECTORY"

        #no other Objective-See tools?
        # then delete that directory too
        baseDir=$(dirname "$INSTALL_DIRECTORY")

        if [ ! "$(ls -A "$baseDir")" ]; then
            rm -rf "$baseDir"
        fi
    fi

    echo "uninstall complete"
    exit 0
fi

#invalid args
echo ""
echo "ERROR: run w/ '-install' or '-uninstall'"
echo ""
exit 1
