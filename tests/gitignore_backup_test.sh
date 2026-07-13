#!/bin/bash

set -euo pipefail

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

assert_file_absent() {
    [[ ! -e "$1" ]] || fail "arquivo inesperado presente: $1"
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
        cp "$3" "$MOCK_S3/$(basename "$3")"
        return 0
    fi

    fail "chamada AWS inesperada: $*"
}

create_repo() {
    local repo=$1

    mkdir -p "$repo/build" "$repo/nested"
    git -C "$repo" init -q
    git -C "$repo" config user.email "tests@example.invalid"
    git -C "$repo" config user.name "Tests"

    cat > "$repo/.gitignore" <<'EOF'
*.log
ignored-root.txt
build/*.tmp
!build/keep.tmp
EOF

    echo "ignored by root" > "$repo/ignored-root.txt"
    echo "tracked despite ignore" > "$repo/tracked.log"
    echo "drop" > "$repo/build/drop.tmp"
    echo "keep" > "$repo/build/keep.tmp"
    echo "plain" > "$repo/plain.txt"
    echo "space" > "$repo/name with spaces.txt"
    printf 'newline' > "$repo/line
break.txt"

    cat > "$repo/nested/.gitignore" <<'EOF'
ignored-sub.txt
EOF
    echo "ignored by nested" > "$repo/nested/ignored-sub.txt"
    echo "visible nested" > "$repo/nested/visible.txt"

    echo "info exclude" > "$repo/info-excluded.txt"
    echo "info-excluded.txt" >> "$repo/.git/info/exclude"

    git -C "$repo" add .gitignore nested/.gitignore
    git -C "$repo" add -f tracked.log
    git -C "$repo" commit -q -m "initial"
}

test_gitignore_backup_contents() {
    local repo="$WORK_DIR/repo"
    local extract_dir="$WORK_DIR/extract"
    create_repo "$repo"

    do_backup "dir" "$repo" "project" "s3://bucket/backups/" "gitignore" >/dev/null

    local backup_tar
    local manifest
    backup_tar=$(single_match "$MOCK_S3/project_*.tar.gz")
    manifest=$(single_match "$MOCK_S3/project_*.manifest.json")

    mkdir -p "$extract_dir"
    tar -xzf "$backup_tar" -C "$extract_dir"

    assert_file_exists "$extract_dir/.gitignore"
    assert_file_exists "$extract_dir/nested/.gitignore"
    assert_file_exists "$extract_dir/tracked.log"
    assert_file_exists "$extract_dir/plain.txt"
    assert_file_exists "$extract_dir/name with spaces.txt"
    assert_file_exists "$extract_dir/line
break.txt"
    assert_file_exists "$extract_dir/build/keep.tmp"
    assert_file_exists "$extract_dir/nested/visible.txt"

    assert_file_absent "$extract_dir/ignored-root.txt"
    assert_file_absent "$extract_dir/nested/ignored-sub.txt"
    assert_file_absent "$extract_dir/build/drop.tmp"
    assert_file_absent "$extract_dir/info-excluded.txt"
    assert_file_absent "$extract_dir/.git"

    grep -q '"filter_mode": "gitignore"' "$manifest"
    grep -q '"git_metadata_included": false' "$manifest"
    grep -q '"git_commit": "' "$manifest"
    grep -q '"git_branch": "' "$manifest"
    grep -q '"git_dirty": true' "$manifest"
    grep -q '"backup_mode": "full"' "$manifest"
}

test_normal_directory_filter_mode() {
    local dir="$WORK_DIR/normal"
    mkdir -p "$dir"
    echo "ignored only in git mode" > "$dir/.gitignore"
    echo "data" > "$dir/data.txt"

    do_backup "dir" "$dir" "normal" "s3://bucket/backups/" "none" >/dev/null

    local manifest
    manifest=$(single_match "$MOCK_S3/normal_*.manifest.json")
    grep -q '"filter_mode": "none"' "$manifest"
}

test_git_mode_outside_repository_fails() {
    local dir="$WORK_DIR/not-repo"
    mkdir -p "$dir"
    echo "data" > "$dir/data.txt"

    if do_backup "dir" "$dir" "notrepo" "s3://bucket/backups/" "gitignore" >/dev/null 2>&1; then
        fail "modo Git deveria falhar fora de um repositório"
    fi

    shopt -s nullglob
    local files=("$MOCK_S3"/notrepo_*.tar.gz)
    shopt -u nullglob
    [[ ${#files[@]} -eq 0 ]] || fail "modo Git não deveria gerar pacote"
}

test_git_metadata_failure_does_not_cancel_backup() {
    local repo="$WORK_DIR/repo-metadata-failure"
    create_repo "$repo"

    get_git_commit() {
        return 1
    }

    get_git_branch() {
        return 1
    }

    get_git_dirty() {
        return 1
    }

    do_backup "dir" "$repo" "metadata_failure" "s3://bucket/backups/" "gitignore" >/dev/null

    local manifest
    manifest=$(single_match "$MOCK_S3/metadata_failure_*.manifest.json")
    grep -q '"filter_mode": "gitignore"' "$manifest"
    grep -q '"git_commit": null' "$manifest"
    grep -q '"git_branch": null' "$manifest"
    grep -q '"git_dirty": null' "$manifest"
    grep -q '"git_metadata_included": false' "$manifest"
}

test_gitignore_backup_contents
test_normal_directory_filter_mode
test_git_mode_outside_repository_fails
test_git_metadata_failure_does_not_cancel_backup

echo "OK: gitignore_backup_test"
