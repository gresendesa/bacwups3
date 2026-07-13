#!/bin/bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATH="$ROOT_DIR/tests/fake-bin:$PATH"
source "$ROOT_DIR/lib_core.sh"

WORK_DIR=$(mktemp -d)
MOCK_S3="$WORK_DIR/s3"
mkdir -p "$MOCK_S3"
AWS_FAIL_MANIFEST_UPLOAD=false
AWS_FAIL_HEAD_OBJECT=false
AWS_RM_CALLS=0
DOCKER_LAST_RUN=""

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

single_match() {
    local pattern=$1
    local matches=()

    shopt -s nullglob
    matches=($pattern)
    shopt -u nullglob

    [[ ${#matches[@]} -eq 1 ]] || fail "esperado exatamente um arquivo para padrão: $pattern"
    printf '%s\n' "${matches[0]}"
}

aws() {
    if [[ "$1" == "s3api" && "$2" == "head-object" ]]; then
        local key=""
        local previous=""
        local arg

        if [[ "$AWS_FAIL_HEAD_OBJECT" == "true" ]]; then
            echo "An error occurred (AccessDenied) when calling the HeadObject operation: Access Denied" >&2
            return 255
        fi

        for arg in "$@"; do
            if [[ "$previous" == "--key" ]]; then
                key=$arg
            fi
            previous=$arg
        done

        [[ -n "$key" ]] || fail "head-object sem key"
        local object="$MOCK_S3/$(basename "$key")"
        if [[ -f "$object" ]]; then
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

        if [[ "$AWS_FAIL_MANIFEST_UPLOAD" == "true" && "$source" == *.manifest.json ]]; then
            return 1
        fi

        cp "$source" "$MOCK_S3/$(basename "$dest")"
        return 0
    fi

    if [[ "$1" == "s3" && "$2" == "rm" ]]; then
        AWS_RM_CALLS=$((AWS_RM_CALLS + 1))
        rm -f "$MOCK_S3/$(basename "$3")"
        return 0
    fi

    fail "chamada AWS inesperada: $*"
}

docker() {
    if [[ "$1" == "run" ]]; then
        DOCKER_LAST_RUN="$*"
        local output=""
        local previous=""
        local arg

        for arg in "$@"; do
            if [[ "$previous" == "-czf" && "$arg" == /backup/* ]]; then
                output="$BACWUPS3_WORKSPACE/$(basename "$arg")"
            fi
            previous=$arg
        done

        [[ "$*" == *"$BACWUPS3_WORKSPACE:/backup"* ]] || fail "docker run não montou workspace esperado"
        [[ -n "$output" ]] || fail "docker run não informou arquivo de saída esperado"
        mkdir -p "$(dirname "$output")"
        local src="$WORK_DIR/docker-src"
        mkdir -p "$src"
        echo "volume" > "$src/file.txt"
        tar -czf "$output" -C "$src" .
        return 0
    fi

    fail "chamada Docker inesperada: $*"
}

test_unique_ids_and_shared_manifest_id() {
    local dir="$WORK_DIR/data"
    mkdir -p "$dir"
    echo "one" > "$dir/file.txt"

    do_backup "dir" "$dir" "project" "s3://bucket/backups/" "none" >/dev/null
    do_backup "dir" "$dir" "project" "s3://bucket/backups/" "none" >/dev/null

    shopt -s nullglob
    local packages=("$MOCK_S3"/project_*.tar.gz)
    local manifests=("$MOCK_S3"/project_*.manifest.json)
    shopt -u nullglob

    [[ ${#packages[@]} -eq 2 ]] || fail "execuções sucessivas deveriam gerar dois pacotes"
    [[ ${#manifests[@]} -eq 2 ]] || fail "execuções sucessivas deveriam gerar dois manifestos"
    [[ "$(basename "${packages[0]}" .tar.gz)" != "$(basename "${packages[1]}" .tar.gz)" ]] || fail "IDs de backup deveriam ser únicos"

    local manifest_id
    manifest_id=$(node -e 'const f=process.argv[1]; console.log(JSON.parse(require("fs").readFileSync(f, "utf8")).backup_id)' "${manifests[0]}")
    [[ "$manifest_id" == "$(basename "${manifests[0]}" .manifest.json)" ]] || fail "manifesto deve usar o mesmo ID do arquivo"
}

test_collision_does_not_overwrite() {
    local dir="$WORK_DIR/collision"
    mkdir -p "$dir"
    echo "collision" > "$dir/file.txt"

    BACWUPS3_FIXED_BACKUP_ID="20260712T184231Z-a94f10d2"
    do_backup "dir" "$dir" "collision" "s3://bucket/backups/" "none" >/dev/null
    if do_backup "dir" "$dir" "collision" "s3://bucket/backups/" "none" >/dev/null 2>&1; then
        fail "colisão remota deveria abortar"
    fi
    unset BACWUPS3_FIXED_BACKUP_ID
}

test_head_object_access_failure_aborts() {
    local dir="$WORK_DIR/head-object-fail"
    mkdir -p "$dir"
    echo "data" > "$dir/file.txt"

    AWS_FAIL_HEAD_OBJECT=true
    if do_backup "dir" "$dir" "headfail" "s3://bucket/backups/" "none" >/dev/null 2>&1; then
        fail "falha real no head-object deveria abortar"
    fi
    AWS_FAIL_HEAD_OBJECT=false

    shopt -s nullglob
    local packages=("$MOCK_S3"/headfail_*.tar.gz)
    shopt -u nullglob
    [[ ${#packages[@]} -eq 0 ]] || fail "backup não deveria continuar após erro real no head-object"
}

test_manifest_upload_failure_removes_package() {
    local dir="$WORK_DIR/fail-manifest"
    mkdir -p "$dir"
    echo "data" > "$dir/file.txt"

    AWS_FAIL_MANIFEST_UPLOAD=true
    if do_backup "dir" "$dir" "orphan" "s3://bucket/backups/" "none" >/dev/null 2>&1; then
        fail "falha no upload do manifesto deveria abortar"
    fi
    AWS_FAIL_MANIFEST_UPLOAD=false

    [[ $AWS_RM_CALLS -ge 1 ]] || fail "pacote remoto deveria ser removido após falha do manifesto"
    shopt -s nullglob
    local packages=("$MOCK_S3"/orphan_*.tar.gz)
    shopt -u nullglob
    [[ ${#packages[@]} -eq 0 ]] || fail "pacote órfão não deveria permanecer"
}

test_docker_backup_uses_readonly_volume_and_pinned_image() {
    do_backup "volume" "sourcevol" "docker_volume" "s3://bucket/backups/" "none" >/dev/null

    [[ "$DOCKER_LAST_RUN" == *"sourcevol:/data:ro"* ]] || fail "volume de origem deveria ser montado como read-only"
    [[ "$DOCKER_LAST_RUN" == *"$DOCKER_BACKUP_IMAGE"* ]] || fail "docker run deveria usar imagem versionada centralizada"
    single_match "$MOCK_S3/docker_volume_*.tar.gz" >/dev/null
    single_match "$MOCK_S3/docker_volume_*.manifest.json" >/dev/null
}

test_unique_ids_and_shared_manifest_id
test_collision_does_not_overwrite
test_head_object_access_failure_aborts
test_manifest_upload_failure_removes_package
test_docker_backup_uses_readonly_volume_and_pinned_image

echo "OK: backup_unique_docker_test"
