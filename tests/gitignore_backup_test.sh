#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

aws() {
    if [[ "$1" == "s3" && "$2" == "ls" ]]; then
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

    mkdir -p "$extract_dir"
    tar -xzf "$MOCK_S3/project_v1.tar.gz" -C "$extract_dir"

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

    grep -q '"filter_mode": "gitignore"' "$MOCK_S3/project_v1.manifest.json"
    grep -q '"git_metadata_included": false' "$MOCK_S3/project_v1.manifest.json"
    grep -q '"git_commit": "' "$MOCK_S3/project_v1.manifest.json"
    grep -q '"git_dirty": true' "$MOCK_S3/project_v1.manifest.json"
}

test_normal_directory_filter_mode() {
    local dir="$WORK_DIR/normal"
    mkdir -p "$dir"
    echo "ignored only in git mode" > "$dir/.gitignore"
    echo "data" > "$dir/data.txt"

    do_backup "dir" "$dir" "normal" "s3://bucket/backups/" "none" >/dev/null

    grep -q '"filter_mode": "none"' "$MOCK_S3/normal_v1.manifest.json"
}

test_git_mode_outside_repository_fails() {
    local dir="$WORK_DIR/not-repo"
    mkdir -p "$dir"
    echo "data" > "$dir/data.txt"

    if do_backup "dir" "$dir" "notrepo" "s3://bucket/backups/" "gitignore" >/dev/null 2>&1; then
        fail "modo Git deveria falhar fora de um repositório"
    fi

    assert_file_absent "$MOCK_S3/notrepo_v1.tar.gz"
}

test_gitignore_backup_contents
test_normal_directory_filter_mode
test_git_mode_outside_repository_fails

echo "OK: gitignore_backup_test"
