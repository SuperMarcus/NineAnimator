#!/bin/zsh

pushd "$(dirname "${(%):-%N}")/../.."
PROJECT_DIR="$(pwd)"
DEPS_DIR="${PROJECT_DIR}/NineAnimatorDependencies"
REGISTRY_ENDPOINT="https://supermarcus.github.io/NineAnimatorCommon"
RESOLVED_MANIFEST_URL=""
RESOLVED_VERSION=""
RESOLVED_FILE=""
RESOLVED_FILE_URL=""
RESOLVED_CHKSUM=""

alias curl_wrp="curl -sL"

guard_sys_dep() {
    which "$1">/dev/null || HOMEBREW_NO_AUTO_UPDATE=1 brew install "$1"
}

exit_with_error() {
    >&2 echo "[!] $1"
    exit 1
}

# resolve_version_url "package name" "version"
resolve_version_url() {
    local target_version="$2"
    [[ -z "$target_version" ]] && target_version=latest
    
    echo "[*] Resolving dependency $1@$target_version..."
    local resolved_dep=`curl_wrp "${REGISTRY_ENDPOINT}/pkg/$1/versions.json" | jq -r ".[\"${target_version}\"]"`
    [[ "$resolved_dep" = "null" ]] && exit_with_error "Unable to resolve the package with the specified version."
    
    RESOLVED_MANIFEST_URL="${REGISTRY_ENDPOINT}/pkg/$1/$resolved_dep/manifest.json"
    RESOLVED_VERSION="$resolved_dep"
}

# download_read_manifest "package name"
download_read_manifest() {
    local local_manifest_path="${DEPS_DIR}/$1.${RESOLVED_VERSION}.manifest.json"
    curl_wrp "${RESOLVED_MANIFEST_URL}" -o "$local_manifest_path"
    RESOLVED_FILE=`cat "${local_manifest_path}" | jq -r ".file"`
    RESOLVED_CHKSUM=`cat "${local_manifest_path}" | jq -r ".checksum"`
    RESOLVED_FILE_URL="${REGISTRY_ENDPOINT}/pkg/$1/${RESOLVED_VERSION}/${RESOLVED_FILE}"
}

download_process_file() {
    local local_file_path="${DEPS_DIR}/${RESOLVED_FILE}"
    echo "[*] Downloading ${RESOLVED_FILE}..."
    curl_wrp "$RESOLVED_FILE_URL" -o "${local_file_path}"
    
    pushd "${DEPS_DIR}"
    unzip -qq -o "${RESOLVED_FILE}"
    rm -f "${RESOLVED_FILE}"
    popd
}

[[ -z "$1" ]] && exit_with_error "Usage: $0 <package_name>"

guard_sys_dep jq

mkdir -p "${DEPS_DIR}"

resolve_version_url "$1"
download_read_manifest "$1"
download_process_file

popd
