#!/bin/bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib_core.sh"

WORK_DIR=$(mktemp -d)

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

aws() {
    if [[ "$1" == "s3" && "$2" == "ls" ]]; then
        if [[ "$3" == "s3://bkp-playground" ]]; then
            return 0
        fi

        fail "bucket inesperado: $*"
    fi

    fail "chamada AWS inesperada: $*"
}

test_load_env_maps_credentials_and_bucket() {
    local env_file="$WORK_DIR/.env"

    cat > "$env_file" <<'ENV'
ACCESS_KEY=test-access
SECRET_ACCESS_KEY=test-secret
AWS_REGION=us-east-1
BACWUPS3_S3_BUCKET=bkp-playground
ENV

    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION AWS_REGION
    unset ACCESS_KEY SECRET_ACCESS_KEY BACWUPS3_S3_BUCKET

    load_env_file "$env_file"

    [[ "${AWS_ACCESS_KEY_ID:-}" == "test-access" ]] || fail "ACCESS_KEY não foi mapeado para AWS_ACCESS_KEY_ID"
    [[ "${AWS_SECRET_ACCESS_KEY:-}" == "test-secret" ]] || fail "SECRET_ACCESS_KEY não foi mapeado para AWS_SECRET_ACCESS_KEY"
    [[ "${AWS_REGION:-}" == "us-east-1" ]] || fail "AWS_REGION não foi carregado"
    [[ "${AWS_DEFAULT_REGION:-}" == "us-east-1" ]] || fail "AWS_DEFAULT_REGION não foi derivado"
    [[ "${BACWUPS3_S3_BUCKET:-}" == "bkp-playground" ]] || fail "bucket fixo não foi carregado"
}

test_configured_bucket_avoids_list_all_buckets() {
    BACWUPS3_S3_BUCKET=bkp-playground

    local buckets
    buckets=$(check_aws_session_and_list_buckets)

    [[ "$buckets" == "bkp-playground" ]] || fail "bucket fixo não foi retornado"
}

test_load_env_maps_credentials_and_bucket
test_configured_bucket_avoids_list_all_buckets

echo "OK: env_iam_test"
