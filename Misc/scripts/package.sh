#!/bin/bash

XCARCHIVE="$(pwd)/$1"
PLATFORM="$2"
PROJ_DIR=`pwd`
PACKAGE_NAME="$3"
BIN_PKG_PATH=`find "${XCARCHIVE}" -name '*.app' -print0`
TMPDIR="$PROJ_DIR/build"
LICENSE_FILE="$PROJ_DIR/LICENSE"
APPNAME="NineAnimator"

echo "[*] Packaging '${XCARCHIVE}' for platform ${PLATFORM} into package name '${PACKAGE_NAME}'..."

package_iOS() {
    pushd "${TMPDIR}"
    
    echo "[*] Generating .ipa archive..."
    
    mkdir -p Payload
    cp -r "${BIN_PKG_PATH}" "Payload/${APPNAME}.app"
    zip -9 -r "${PACKAGE_NAME}.ipa" Payload
    rm -rf Payload
    
    echo "[*] Generating .dSYM archive..."
    
    cp -r "${XCARCHIVE}/dSYMs" "dSYMs"
    zip -9 -r "${PACKAGE_NAME}.dSYMs.zip" "dSYMs"
    rm -rf dSYMs
    
    popd
}

package_macOS() {
    pushd "${TMPDIR}"
    
    echo "[*] Generating .zip archive..."
    cp -r "${BIN_PKG_PATH}" "${APPNAME}.app"
    cp "${LICENSE_FILE}" "LICENSE"
    zip -9 -r "${PACKAGE_NAME}.zip" "${APPNAME}.app" "LICENSE"
    
    echo "[*] Generating .dSYM archive..."
    
    cp -r "${XCARCHIVE}/dSYMs" "dSYMs"
    zip -9 -r "${PACKAGE_NAME}.dSYMs.zip" "dSYMs"
    rm -rf dSYMs
    
    popd
}

"package_${PLATFORM}"

echo "[*] Removing xcarchive..."
rm -rf "${XCARCHIVE}"
