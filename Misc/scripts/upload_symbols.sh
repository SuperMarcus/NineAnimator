#!/bin/bash

APPCENTER_TOKEN="$1"

pushd build

for sym_archive in *.dSYMs.zip ; do
    echo "[*] Obtaining symbols upload URL for '${sym_archive}'..."

    UPLOAD_REQUEST_RES="$(curl -X POST "https://api.appcenter.ms/v0.1/apps/marcuszhou/NineAnimator/symbol_uploads" -H "X-API-Token: ${APPCENTER_TOKEN}" -H "accept: application/json" -H "Content-Type: application/json" -d "{ \"symbol_type\": \"Apple\", \"file_name\": \"${sym_archive}\" }")"
    UPLOAD_URL=`osascript -l JavaScript -e "function run(o){const n=JSON.parse(o[0]);console.log(n.upload_url)}"` "${UPLOAD_REQUEST_RES}"
    
    echo "[*] Uploading symbols in '${sym_archive}'..."
    curl -X PUT "${UPLOAD_URL}" -H 'x-ms-blob-type: BlockBlob' --upload-file "${sym_archive}"
    
done

popd
