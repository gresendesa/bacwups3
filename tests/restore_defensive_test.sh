#!/bin/bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATH="$ROOT_DIR/tests/fake-bin:$PATH"
source "$ROOT_DIR/lib_core.sh"
source "$ROOT_DIR/lib_ui.sh"

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

assert_dir_exists() {
    [[ -d "$1" ]] || fail "diretório esperado ausente: $1"
}

aws() {
    if [[ "$1" == "s3" && "$2" == "cp" ]]; then
        cp "$MOCK_S3/$(basename "$3")" "$4"
        return $?
    fi

    fail "chamada AWS inesperada: $*"
}

docker() {
    case "$1 $2" in
        "volume inspect")
            [[ -e "$WORK_DIR/volume_$3" ]]
            ;;
        "volume create")
            touch "$WORK_DIR/volume_$3"
            echo "$3"
            ;;
        "volume rm")
            rm -f "$WORK_DIR/volume_$3"
            ;;
        *)
            if [[ "$1" == "run" ]]; then
                return 1
            fi
            fail "chamada Docker inesperada: $*"
            ;;
    esac
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

make_unsafe_tar() {
    local tar_file=$1
    local src="$WORK_DIR/unsafe_src"

    mkdir -p "$src"
    echo "bad" > "$src/file.txt"
    tar -czf "$tar_file" -C "$src" --transform='s#file.txt#../evil.txt#' file.txt
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

test_restore_success() {
    local tar_file="$WORK_DIR/good.tar.gz"
    local manifest_file="$WORK_DIR/good.manifest.json"
    local dest="$WORK_DIR/restore-ok"
    local checksum

    make_safe_tar "$tar_file"
    checksum=$(sha256sum "$tar_file" | awk '{print $1}')
    write_manifest "$tar_file" "$manifest_file" "$checksum"
    publish_pair "good" "$tar_file" "$manifest_file"

    do_restore "dir" "$dest" "s3://bucket/good.tar.gz" >/dev/null
    assert_file_exists "$dest/file.txt"
}

test_restore_into_named_subdir_under_existing_parent() {
    local tar_file="$WORK_DIR/parent.tar.gz"
    local manifest_file="$WORK_DIR/parent.manifest.json"
    local parent="$WORK_DIR/existing-parent"
    local final_dest
    local checksum

    mkdir -p "$parent"
    echo "keep" > "$parent/existing.txt"

    make_safe_tar "$tar_file"
    checksum=$(sha256sum "$tar_file" | awk '{print $1}')
    write_manifest "$tar_file" "$manifest_file" "$checksum"
    publish_pair "parent" "$tar_file" "$manifest_file"

    final_dest=$(join_restore_directory_path "$parent" "$(default_restore_directory_name_from_manifest "$manifest_file")")
    [[ "$final_dest" == "$parent/dest" ]] || fail "destino final inesperado: $final_dest"

    do_restore "dir" "$final_dest" "s3://bucket/parent.tar.gz" >/dev/null
    assert_file_exists "$parent/existing.txt"
    assert_file_exists "$parent/dest/file.txt"
}

test_restore_named_subdir_overwrite_protection() {
    local tar_file="$WORK_DIR/overwrite.tar.gz"
    local manifest_file="$WORK_DIR/overwrite.manifest.json"
    local parent="$WORK_DIR/overwrite-parent"
    local final_dest="$parent/custom"
    local checksum

    mkdir -p "$final_dest"
    echo "existing" > "$final_dest/file.txt"

    make_safe_tar "$tar_file"
    checksum=$(sha256sum "$tar_file" | awk '{print $1}')
    write_manifest "$tar_file" "$manifest_file" "$checksum"
    publish_pair "overwrite" "$tar_file" "$manifest_file"

    if do_restore "dir" "$final_dest" "s3://bucket/overwrite.tar.gz" >/dev/null 2>&1; then
        fail "restore deveria bloquear subdiretório final existente com dados"
    fi

    grep -q "existing" "$final_dest/file.txt" || fail "conteúdo existente deveria ser preservado"
}

test_restore_custom_subdir_path() {
    local parent="$WORK_DIR/custom-parent"
    local final_dest

    mkdir -p "$parent"
    final_dest=$(join_restore_directory_path "$parent" "custom-name")
    [[ "$final_dest" == "$parent/custom-name" ]] || fail "subdiretório customizado inesperado: $final_dest"

    final_dest=$(join_restore_directory_path "$parent" "../nested/name/")
    [[ "$final_dest" == "$parent/nested_name" ]] || fail "nome de subdiretório deveria ser saneado: $final_dest"
}

test_manifest_special_paths_are_valid_json() {
    local tar_file="$WORK_DIR/special.tar.gz"
    local manifest_file="$WORK_DIR/special.manifest.json"
    local checksum
    local archive_size

    make_safe_tar "$tar_file"
    checksum=$(sha256sum "$tar_file" | awk '{print $1}')
    archive_size=$(stat -c '%s' "$tar_file")

    generate_manifest \
        "directory" \
        'alvo com espaços "aspas" e unicode çã/測試' \
        "special_v1" \
        '/origem com espaços "aspas" e unicode çã/測試' \
        "$archive_size" \
        "$checksum" \
        "$manifest_file"

    validate_manifest "$manifest_file"
    node -e 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))' "$manifest_file"
    grep -q '"backup_mode": "full"' "$manifest_file"
}

test_invalid_hash_values_do_not_extract() {
    local tar_file="$WORK_DIR/hash.tar.gz"
    local manifest_file="$WORK_DIR/hash.manifest.json"
    local dest="$WORK_DIR/hash-dest"

    make_safe_tar "$tar_file"
    write_manifest "$tar_file" "$manifest_file" ""
    publish_pair "hash-empty" "$tar_file" "$manifest_file"
    if do_restore "dir" "$dest" "s3://bucket/hash-empty.tar.gz" >/dev/null 2>&1; then
        fail "hash vazio deveria falhar"
    fi
    assert_path_absent "$dest"

    write_manifest "$tar_file" "$manifest_file" "not-a-sha"
    publish_pair "hash-bad-format" "$tar_file" "$manifest_file"
    if do_restore "dir" "$dest" "s3://bucket/hash-bad-format.tar.gz" >/dev/null 2>&1; then
        fail "hash malformado deveria falhar"
    fi
    assert_path_absent "$dest"
}

test_divergent_hash_and_bad_archive_do_not_extract() {
    local tar_file="$WORK_DIR/bad.tar.gz"
    local manifest_file="$WORK_DIR/bad.manifest.json"
    local dest="$WORK_DIR/bad-dest"
    local checksum

    make_safe_tar "$tar_file"
    write_manifest "$tar_file" "$manifest_file" "0000000000000000000000000000000000000000000000000000000000000000"
    publish_pair "bad-hash" "$tar_file" "$manifest_file"
    if do_restore "dir" "$dest" "s3://bucket/bad-hash.tar.gz" >/dev/null 2>&1; then
        fail "hash divergente deveria falhar"
    fi
    assert_path_absent "$dest"

    echo "not tar" > "$tar_file"
    checksum=$(sha256sum "$tar_file" | awk '{print $1}')
    write_manifest "$tar_file" "$manifest_file" "$checksum"
    publish_pair "bad-archive" "$tar_file" "$manifest_file"
    if do_restore "dir" "$dest" "s3://bucket/bad-archive.tar.gz" >/dev/null 2>&1; then
        fail "tar malformado deveria falhar"
    fi
    assert_path_absent "$dest"
}

test_unsafe_archive_and_directory_rollback() {
    local tar_file="$WORK_DIR/unsafe.tar.gz"
    local manifest_file="$WORK_DIR/unsafe.manifest.json"
    local dest="$WORK_DIR/unsafe-dest"
    local checksum

    make_unsafe_tar "$tar_file"
    checksum=$(sha256sum "$tar_file" | awk '{print $1}')
    write_manifest "$tar_file" "$manifest_file" "$checksum"
    publish_pair "unsafe" "$tar_file" "$manifest_file"
    if do_restore "dir" "$dest" "s3://bucket/unsafe.tar.gz" >/dev/null 2>&1; then
        fail "tar inseguro deveria falhar"
    fi
    assert_path_absent "$dest"

    make_extract_fail_tar "$tar_file"
    checksum=$(sha256sum "$tar_file" | awk '{print $1}')
    write_manifest "$tar_file" "$manifest_file" "$checksum"
    publish_pair "extract-fail" "$tar_file" "$manifest_file"
    if do_restore "dir" "$dest" "s3://bucket/extract-fail.tar.gz" >/dev/null 2>&1; then
        fail "falha de extração deveria falhar"
    fi
    assert_path_absent "$dest"

    mkdir -p "$dest"
    if do_restore "dir" "$dest" "s3://bucket/extract-fail.tar.gz" >/dev/null 2>&1; then
        fail "falha de extração em diretório existente deveria falhar"
    fi
    assert_dir_exists "$dest"
}

test_volume_rollback() {
    local tar_file="$WORK_DIR/vol.tar.gz"
    local manifest_file="$WORK_DIR/vol.manifest.json"
    local checksum

    make_safe_tar "$tar_file"
    checksum=$(sha256sum "$tar_file" | awk '{print $1}')
    write_manifest "$tar_file" "$manifest_file" "$checksum"
    publish_pair "vol" "$tar_file" "$manifest_file"

    if do_restore "volume" "newvol" "s3://bucket/vol.tar.gz" >/dev/null 2>&1; then
        fail "extração de volume mockada deveria falhar"
    fi
    assert_path_absent "$WORK_DIR/volume_newvol"
}

test_restore_success
test_restore_into_named_subdir_under_existing_parent
test_restore_named_subdir_overwrite_protection
test_restore_custom_subdir_path
test_manifest_special_paths_are_valid_json
test_invalid_hash_values_do_not_extract
test_divergent_hash_and_bad_archive_do_not_extract
test_unsafe_archive_and_directory_rollback
test_volume_rollback

echo "OK: restore_defensive_test"
