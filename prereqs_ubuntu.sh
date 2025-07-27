#!/bin/bash

getScriptPath () {
	echo ${0%/*}/
}
myPath=$(getScriptPath)

. ${myPath}/lib.sh

echo_i "Update"
apt-get update -q
assert_success $? "Failed to update" || exit 2

echo_i "Install software-properties-common"
DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common
assert_success $? "Failed to install software-properties-common" || exit 2

echo_i "Install tools, Qt and ffmpeg"
DEBIAN_FRONTEND=noninteractive apt-get install -y pkg-config build-essential alien openssh-client cmake rpm qt6-base-dev qt6-pdf-dev qt6-httpserver-dev qt6-websockets-dev qt6-multimedia-dev linguist-qt6 qt6-tools-dev qt6-tools-dev libxkbcommon-x11-dev libqt6svg6-dev
assert_success $? "Failed to install tools, Qt and ffmpeg" || exit 2

