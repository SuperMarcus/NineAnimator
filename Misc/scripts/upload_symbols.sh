#!/bin/bash

APPCENTER_TOKEN="$1"

pushd build

for sym_archive in *.dSYMs.zip ; do
    echo "[*] Obtaining symbols upload URL for '${sym_archive}'..."

    UPLOAD_REQUEST_RES="$(curl -X POST "https://api.appcenter.ms/v0.1/apps/marcuszhou/NineAnimator/symbol_uploads" -H "X-API-Token: ${APPCENTER_TOKEN}" -H "accept: application/json" -H "Content-Type: application/json" -d "{ \"symbol_type\": \"Apple\", \"file_name\": \"${sym_archive}\" }")"
    UPLOAD_URL=`osascript -l JavaScript -e "function run(o){return JSON.parse(o[0]).upload_url}" "${UPLOAD_REQUEST_RES}"`
    UPLOAD_ID=`osascript -l JavaScript -e "function run(o){return JSON.parse(o[0]).symbol_upload_id}" "${UPLOAD_REQUEST_RES}"`
    
    echo "[*] Uploading symbols in '${sym_archive}' (${UPLOAD_ID})..."
    curl -X PUT "${UPLOAD_URL}" -H 'x-ms-blob-type: BlockBlob' --upload-file "${sym_archive}"
    
    echo "[*] Committing ${UPLOAD_ID}..."
    curl -X PATCH "https://api.appcenter.ms/v0.1/apps/marcuszhou/NineAnimator/symbol_uploads/${UPLOAD_ID}" \
        -H 'accept: application/json' \
        -H "X-API-Token: ${APPCENTER_TOKEN}" \
        -H 'Content-Type: application/json' \
        -d '{ "status": "committed" }'
    
done

popd
