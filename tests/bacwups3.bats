#!/usr/bin/env bats

setup_file() {
    cd "$BATS_TEST_DIRNAME/.."
}

@test "restore defensive behavior" {
    run bash tests/restore_defensive_test.sh
    [ "$status" -eq 0 ]
}

@test "backup IDs and Docker hardening" {
    run bash tests/backup_unique_docker_test.sh
    [ "$status" -eq 0 ]
}

@test "gitignore project backup" {
    run bash tests/gitignore_backup_test.sh
    [ "$status" -eq 0 ]
}

@test "verify backup without restore" {
    run bash tests/verify_backup_test.sh
    [ "$status" -eq 0 ]
}

@test "IAM env configuration" {
    run bash tests/env_iam_test.sh
    [ "$status" -eq 0 ]
}
