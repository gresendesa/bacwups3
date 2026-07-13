#!/bin/bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATH="$ROOT_DIR/tests/fake-bin:$PATH"
source "$ROOT_DIR/lib_core.sh"

WORK_DIR=$(mktemp -d)
MOCK_S3="$WORK_DIR/s3"
mkdir -p "$MOCK_S3"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_file_exists() {
    [[ -f "$1" ]] || fail "arquivo esperado ausente: $1"
}

assert_path_absent() {
    [[ ! -e "$1" ]] || fail "caminho inesperado presente: $1"
}

aws() {
    if [[ "$1" == "s3" && "$2" == "cp" ]]; then
        cp "$MOCK_S3/$(basename "$3")" "$4"
        return $?
    fi

    fail "chamada AWS inesperada: $*"
}

docker() {
    fail "docker não deveria ser chamado durante verificação: $*"
}

write_manifest() {
    local tar_file=$1
    local manifest_file=$2
    local checksum=$3
    local size

    size=$(stat -c '%s' "$tar_file")
    generate_manifest "directory" "dest" "test" "/origin" "$size" "$checksum" "$manifest_file"
}

publish_pair() {
    local name=$1
    local tar_file=$2
    local manifest_file=$3

    cp "$tar_file" "$MOCK_S3/$name.tar.gz"
    cp "$manifest_file" "$MOCK_S3/$name.manifest.json"
}

make_safe_tar() {
    local tar_file=$1
    local src="$WORK_DIR/src_$RANDOM"

    mkdir -p "$src"
    echo "ok" > "$src/file.txt"
    tar -czf "$tar_file" -C "$src" .
}

test_verify_success_does_not_restore() {
    local tar_file="$WORK_DIR/good.tar.gz"
    local manifest_file="$WORK_DIR/good.manifest.json"
    local checksum

    make_safe_tar "$tar_file"
    checksum=$(sha256sum "$tar_file" | awk '{print $1}')
    write_manifest "$tar_file" "$manifest_file" "$checksum"
    publish_pair "good" "$tar_file" "$manifest_file"

    do_verify_backup "s3://bucket/good.tar.gz" >/dev/null

    assert_file_exists "$MOCK_S3/good.tar.gz"
    assert_file_exists "$MOCK_S3/good.manifest.json"
    assert_path_absent "$WORK_DIR/file.txt"
    assert_path_absent "$WORK_DIR/dest"
    assert_path_absent "$WORK_DIR/volume_dest"
}

test_verify_rejects_bad_hash() {
    local tar_file="$WORK_DIR/bad-hash.tar.gz"
    local manifest_file="$WORK_DIR/bad-hash.manifest.json"

    make_safe_tar "$tar_file"
    write_manifest "$tar_file" "$manifest_file" "0000000000000000000000000000000000000000000000000000000000000000"
    publish_pair "bad-hash" "$tar_file" "$manifest_file"

    if do_verify_backup "s3://bucket/bad-hash.tar.gz" >/dev/null 2>&1; then
        fail "verificação com hash divergente deveria falhar"
    fi

    assert_path_absent "$WORK_DIR/file.txt"
    assert_path_absent "$WORK_DIR/dest"
}

test_verify_rejects_malformed_archive() {
    local tar_file="$WORK_DIR/bad-archive.tar.gz"
    local manifest_file="$WORK_DIR/bad-archive.manifest.json"
    local checksum

    echo "not tar" > "$tar_file"
    checksum=$(sha256sum "$tar_file" | awk '{print $1}')
    write_manifest "$tar_file" "$manifest_file" "$checksum"
    publish_pair "bad-archive" "$tar_file" "$manifest_file"

    if do_verify_backup "s3://bucket/bad-archive.tar.gz" >/dev/null 2>&1; then
        fail "verificação com pacote malformado deveria falhar"
    fi

    assert_path_absent "$WORK_DIR/file.txt"
    assert_path_absent "$WORK_DIR/dest"
}

test_verify_success_does_not_restore
test_verify_rejects_bad_hash
test_verify_rejects_malformed_archive

echo "OK: verify_backup_test"
