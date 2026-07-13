#!/bin/bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

bash -n bacwups3.sh lib_core.sh lib_ui.sh bundle.sh

bash tests/restore_defensive_test.sh
bash tests/backup_unique_docker_test.sh
bash tests/gitignore_backup_test.sh
bash tests/verify_backup_test.sh
bash tests/env_iam_test.sh

bash bundle.sh >/dev/null
bash -n dist/bacwups3.bundle.sh

if command -v shellcheck >/dev/null 2>&1; then
    shellcheck bacwups3.sh lib_core.sh lib_ui.sh bundle.sh tests/*.sh
else
    echo "SKIP: shellcheck não instalado."
fi

if command -v bats >/dev/null 2>&1; then
    bats tests/bacwups3.bats
else
    echo "SKIP: bats não instalado."
fi

if [[ "${BACWUPS3_RUN_DOCKER_INTEGRATION:-}" == "1" ]]; then
    bash tests/docker_volume_integration_test.sh
else
    echo "SKIP: integração Docker real desabilitada (BACWUPS3_RUN_DOCKER_INTEGRATION=1)."
fi

echo "OK: tests/run_all.sh"
