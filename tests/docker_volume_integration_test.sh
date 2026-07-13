#!/bin/bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATH="$ROOT_DIR/tests/fake-bin:$PATH"
source "$ROOT_DIR/lib_core.sh"

WORK_DIR=$(mktemp -d)
MOCK_S3="$WORK_DIR/s3"
TEST_ID="bacwups3_it_$(date +%s)_$$"
SOURCE_VOLUME="${TEST_ID}_source"
RESTORE_VOLUME="${TEST_ID}_restore"
ROLLBACK_VOLUME="${TEST_ID}_rollback"
CREATED_VOLUMES=()
mkdir -p "$MOCK_S3"

cleanup() {
    local volume

    for volume in "${CREATED_VOLUMES[@]}"; do
        docker volume rm "$volume" >/dev/null 2>&1 || true
    done

    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

require_docker() {
    command -v docker >/dev/null 2>&1 || fail "docker não está instalado"
    docker info >/dev/null 2>&1 || fail "docker não está acessível"
}

aws() {
    if [[ "$1" == "s3api" && "$2" == "head-object" ]]; then
        local key=""
        local previous=""
        local arg

        for arg in "$@"; do
            if [[ "$previous" == "--key" ]]; then
                key=$arg
            fi
            previous=$arg
        done

        [[ -n "$key" ]] || fail "head-object sem key"
        if [[ -f "$MOCK_S3/$(basename "$key")" ]]; then
            return 0
        fi

        echo "An error occurred (404) when calling the HeadObject operation: Not Found" >&2
        return 255
    fi

    if [[ "$1" == "s3" && "$2" == "ls" ]]; then
        local object="$MOCK_S3/$(basename "$3")"
        [[ -f "$object" ]] && printf '2026-07-13 00:00:00 %s %s\n' "$(stat -c '%s' "$object")" "$(basename "$object")"
        return 0
    fi

    if [[ "$1" == "s3" && "$2" == "cp" ]]; then
        local source=$3
        local dest=$4

        if [[ "$source" == s3://* ]]; then
            cp "$MOCK_S3/$(basename "$source")" "$dest"
        else
            cp "$source" "$MOCK_S3/$(basename "$dest")"
        fi
        return $?
    fi

    if [[ "$1" == "s3" && "$2" == "rm" ]]; then
        rm -f "$MOCK_S3/$(basename "$3")"
        return 0
    fi

    fail "chamada AWS inesperada: $*"
}

create_volume() {
    local volume=$1

    docker volume create "$volume" >/dev/null
    CREATED_VOLUMES+=("$volume")
}

populate_source_volume() {
    create_volume "$SOURCE_VOLUME"

    docker run --rm \
        -v "$SOURCE_VOLUME":/data \
        "$DOCKER_BACKUP_IMAGE" \
        sh -c 'mkdir -p "/data/sub dir" && printf "alpha\n" > /data/file.txt && printf "space\n" > "/data/sub dir/name with spaces.txt"'
}

assert_source_volume_is_readonly() {
    if docker run --rm -v "$SOURCE_VOLUME":/data:ro "$DOCKER_BACKUP_IMAGE" sh -c 'printf "nope\n" > /data/readonly-check' >/dev/null 2>&1; then
        fail "volume de origem aceitou escrita em montagem read-only"
    fi
}

assert_restored_content_matches() {
    local source_dump="$WORK_DIR/source"
    local restore_dump="$WORK_DIR/restore"

    mkdir -p "$source_dump" "$restore_dump"

    docker run --rm \
        -v "$SOURCE_VOLUME":/data:ro \
        -v "$source_dump":/out \
        "$DOCKER_BACKUP_IMAGE" \
        tar -czf /out/content.tar.gz -C /data .

    docker run --rm \
        -v "$RESTORE_VOLUME":/data:ro \
        -v "$restore_dump":/out \
        "$DOCKER_BACKUP_IMAGE" \
        tar -czf /out/content.tar.gz -C /data .

    mkdir -p "$source_dump/extract" "$restore_dump/extract"
    tar -xzf "$source_dump/content.tar.gz" -C "$source_dump/extract"
    tar -xzf "$restore_dump/content.tar.gz" -C "$restore_dump/extract"

    diff -r "$source_dump/extract" "$restore_dump/extract" >/dev/null
}

make_extract_fail_tar() {
    local tar_file=$1
    local src="$WORK_DIR/fail_src"

    mkdir -p "$src"
    echo "one" > "$src/a"
    echo "two" > "$src/b"
    tar -czf "$tar_file" \
        -C "$src" --transform='s#^a$#clash#' a \
        -C "$src" --transform='s#^b$#clash/child#' b
}

publish_failing_restore_pair() {
    local tar_file="$WORK_DIR/failing.tar.gz"
    local manifest_file="$WORK_DIR/failing.manifest.json"
    local checksum
    local size

    make_extract_fail_tar "$tar_file"
    checksum=$(sha256sum "$tar_file" | awk '{print $1}')
    size=$(stat -c '%s' "$tar_file")
    generate_manifest "volume" "$ROLLBACK_VOLUME" "failing" "docker_volume:$SOURCE_VOLUME" "$size" "$checksum" "$manifest_file"

    cp "$tar_file" "$MOCK_S3/failing.tar.gz"
    cp "$manifest_file" "$MOCK_S3/failing.manifest.json"
}

test_volume_backup_restore_with_real_docker() {
    populate_source_volume
    assert_source_volume_is_readonly

    BACWUPS3_FIXED_BACKUP_ID="$TEST_ID"
    do_backup "volume" "$SOURCE_VOLUME" "docker_volume" "s3://bucket/backups/" "none" >/dev/null
    unset BACWUPS3_FIXED_BACKUP_ID

    [[ -f "$MOCK_S3/docker_volume_${TEST_ID}.tar.gz" ]] || fail "pacote de backup de volume não foi criado"
    [[ -f "$MOCK_S3/docker_volume_${TEST_ID}.manifest.json" ]] || fail "manifesto de volume não foi criado"

    do_restore "volume" "$RESTORE_VOLUME" "s3://bucket/backups/docker_volume_${TEST_ID}.tar.gz" >/dev/null
    CREATED_VOLUMES+=("$RESTORE_VOLUME")

    assert_restored_content_matches
}

test_volume_restore_rollback_with_real_docker() {
    publish_failing_restore_pair

    if do_restore "volume" "$ROLLBACK_VOLUME" "s3://bucket/backups/failing.tar.gz" >/dev/null 2>&1; then
        fail "restore de volume com extração inválida deveria falhar"
    fi

    if docker volume inspect "$ROLLBACK_VOLUME" >/dev/null 2>&1; then
        fail "volume criado pela restauração deveria ser removido no rollback"
    fi
}

require_docker
test_volume_backup_restore_with_real_docker
test_volume_restore_rollback_with_real_docker

echo "OK: docker_volume_integration_test"
