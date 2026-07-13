#!/bin/bash
set -Eeuo pipefail

# ==========================================
# lib_core.sh - Funções de Segurança, S3 e Execução
# ==========================================

BACWUPS3_WORKSPACE=${BACWUPS3_WORKSPACE:-}
MANIFEST_SCHEMA_VERSION=1
DOCKER_BACKUP_IMAGE="alpine:3.20"

init_temp_workspace() {
    if [[ -n "$BACWUPS3_WORKSPACE" && -d "$BACWUPS3_WORKSPACE" ]]; then
        return 0
    fi

    BACWUPS3_WORKSPACE=$(mktemp -d "${TMPDIR:-/tmp}/bacwups3.XXXXXX")
    export BACWUPS3_WORKSPACE
}

cleanup_temp_workspace() {
    if [[ -n "${BACWUPS3_WORKSPACE:-}" && -d "$BACWUPS3_WORKSPACE" ]]; then
        rm -rf -- "$BACWUPS3_WORKSPACE"
    fi
}

trap cleanup_temp_workspace EXIT INT TERM

check_aws_session_and_list_buckets() {
    local s3_output

    if ! s3_output=$(aws s3 ls 2>/dev/null); then
        return 1
    fi

    echo "$s3_output" | awk '{print $3}' | sed '/^$/d'
}

list_docker_volumes() {
    docker volume ls --format '{{.Name}}' 2>/dev/null
}

require_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "ERRO: Dependência obrigatória ausente: jq." >&2
        return 1
    fi
}

build_target_key() {
    local type=$1
    local target=$2
    local key

    if [[ "$type" == "dir" ]]; then
        key=${target#/}
        key=${key//\//__}
    else
        key=$target
    fi

    key=$(echo "$key" | sed 's/[^a-zA-Z0-9._-]/_/g')
    [[ -z "$key" ]] && key="target"
    echo "$key"
}

download_manifest_preview() {
    local s3_src_tar=$1
    local s3_src_manifest=${s3_src_tar/.tar.gz/.manifest.json}

    init_temp_workspace
    local tmp_manifest="$BACWUPS3_WORKSPACE/preview_$(basename "$s3_src_manifest")"

    if ! aws s3 cp "$s3_src_manifest" "$tmp_manifest" >/dev/null 2>&1; then
        return 1
    fi

    echo "$tmp_manifest"
}

check_target_exists() {
    local type=$1
    local target=$2

    if [[ "$type" == "volume" ]]; then
        if docker volume inspect "$target" >/dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    elif [[ "$type" == "dir" ]]; then
        if [[ -d "$target" ]] && [[ "$(ls -A "$target" 2>/dev/null)" ]]; then
            return 0
        else
            return 1
        fi
    fi
}

generate_backup_id() {
    local timestamp
    local suffix

    if [[ -n "${BACWUPS3_FIXED_BACKUP_ID:-}" ]]; then
        echo "$BACWUPS3_FIXED_BACKUP_ID"
        return 0
    fi

    timestamp=$(date -u +%Y%m%dT%H%M%SZ)
    suffix=$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')
    printf '%s-%s\n' "$timestamp" "$suffix"
}

s3_object_uri() {
    local s3_base_path=$1
    local object_name=$2

    printf '%s/%s\n' "${s3_base_path%/}" "$object_name"
}

ensure_s3_object_absent() {
    local s3_uri=$1
    local listing

    if ! listing=$(aws s3 ls "$s3_uri" 2>/dev/null); then
        echo "ERRO: Falha ao verificar objeto remoto '$s3_uri'."
        return 1
    fi

    if [[ -n "$listing" ]]; then
        echo "ERRO: Objeto remoto já existe e não será sobrescrito: $s3_uri"
        return 1
    fi
}

remove_remote_object() {
    local s3_uri=$1

    if ! aws s3 rm "$s3_uri" >/dev/null 2>&1; then
        echo "ERRO: Falha ao remover objeto remoto incompleto: $s3_uri"
        return 1
    fi
}

generate_manifest() {
    local target_type=$1
    local target_name=$2
    local backup_id=$3
    local origin_path=$4
    local archive_size=$5
    local checksum=$6
    local manifest_file=$7
    local filter_mode=${8:-none}
    local git_commit=${9:-}
    local git_branch=${10:-}
    local git_dirty=${11:-}
    local git_metadata_included=${12:-false}
    local created_at

    require_jq || return 1

    created_at=$(date --iso-8601=seconds)

    jq -n \
        --argjson schema_version "$MANIFEST_SCHEMA_VERSION" \
        --arg backup_mode "full" \
        --arg backup_id "$backup_id" \
        --arg target_type "$target_type" \
        --arg target_name "$target_name" \
        --arg origin_path "$origin_path" \
        --arg created_at "$created_at" \
        --argjson archive_size "$archive_size" \
        --arg sha256 "$checksum" \
        --arg filter_mode "$filter_mode" \
        --arg machine_origin "$(hostname)" \
        --arg user "$(whoami)" \
        --arg git_commit "$git_commit" \
        --arg git_branch "$git_branch" \
        --arg git_dirty "$git_dirty" \
        --arg git_metadata_included "$git_metadata_included" \
        '{
          schema_version: $schema_version,
          backup_mode: $backup_mode,
          backup_id: $backup_id,
          target_type: $target_type,
          target_name: $target_name,
          origin_path: $origin_path,
          created_at: $created_at,
          archive_size: $archive_size,
          sha256: $sha256,
          filter_mode: $filter_mode,
          machine_origin: $machine_origin,
          user: $user
        }
        + if $filter_mode == "gitignore" then {
          git_commit: (if $git_commit == "" then null else $git_commit end),
          git_branch: (if $git_branch == "" then null else $git_branch end),
          git_dirty: (if $git_dirty == "true" then true elif $git_dirty == "false" then false else null end),
          git_metadata_included: (if $git_metadata_included == "true" then true else false end)
        } else {} end' > "$manifest_file"
}

validate_manifest() {
    local manifest_file=$1

    require_jq || return 1

    if [[ ! -s "$manifest_file" ]]; then
        echo "ERRO: Manifesto ausente ou vazio."
        return 1
    fi

    if ! jq -e '
        .schema_version == 1 and
        .backup_mode == "full" and
        (.backup_id | type == "string" and length > 0) and
        (.target_type | type == "string" and length > 0) and
        (.target_name | type == "string" and length > 0) and
        (.origin_path | type == "string" and length > 0) and
        (.created_at | type == "string" and length > 0) and
        (.archive_size | type == "number" and . >= 0) and
        (.sha256 | type == "string" and length > 0)
    ' "$manifest_file" >/dev/null; then
        echo "ERRO: Manifesto inválido ou sem campos obrigatórios."
        return 1
    fi
}

manifest_field() {
    local manifest_file=$1
    local field=$2

    jq -r ".$field" "$manifest_file"
}

validate_sha256_value() {
    local checksum=$1

    if [[ -z "$checksum" ]]; then
        echo "ERRO: SHA256 esperado está vazio."
        return 1
    fi

    if [[ ! "$checksum" =~ ^[0-9a-fA-F]{64}$ ]]; then
        echo "ERRO: SHA256 esperado possui formato inválido."
        return 1
    fi
}

validate_archive_before_restore() {
    local tar_file=$1
    local entry
    local link_target

    if ! tar -tzf "$tar_file" >/dev/null; then
        echo "ERRO: Arquivo compactado inválido ou malformado."
        return 1
    fi

    while IFS= read -r entry; do
        if [[ "$entry" == /* || "$entry" == *"/../"* || "$entry" == ../* || "$entry" == ".." || "$entry" == *"/.." ]]; then
            echo "ERRO: Arquivo compactado contém caminho inseguro: $entry"
            return 1
        fi
    done < <(tar -tzf "$tar_file")

    while IFS= read -r entry; do
        [[ "$entry" == *" -> "* ]] || continue
        link_target=${entry##* -> }
        if [[ "$link_target" == /* || "$link_target" == *"/../"* || "$link_target" == ../* || "$link_target" == ".." || "$link_target" == *"/.." ]]; then
            echo "ERRO: Arquivo compactado contém link inseguro: $link_target"
            return 1
        fi
    done < <(tar -tvzf "$tar_file")
}

rollback_created_target() {
    local type=$1
    local target_name=$2

    if [[ "$type" == "volume" ]]; then
        if ! docker volume rm "$target_name" >/dev/null 2>&1; then
            echo "ERRO: Falha no rollback do volume Docker '$target_name'."
            return 1
        fi
    elif [[ "$type" == "dir" ]]; then
        if ! rm -rf -- "$target_name"; then
            echo "ERRO: Falha no rollback do diretório '$target_name'."
            return 1
        fi
    fi
}

create_gitignore_tar() {
    local project_dir=$1
    local tar_file=$2
    local file_list

    if ! git -C "$project_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "ERRO: O diretório '$project_dir' não pertence a um repositório Git."
        return 1
    fi

    init_temp_workspace
    file_list=$(mktemp "$BACWUPS3_WORKSPACE/bacwups3_git_files.XXXXXX")
    if ! git -C "$project_dir" ls-files --cached --others --exclude-standard -z > "$file_list"; then
        echo "ERRO: Falha ao consultar arquivos do projeto Git em '$project_dir'."
        rm -f "$file_list"
        return 1
    fi

    if ! tar -czf "$tar_file" -C "$project_dir" --null -T "$file_list"; then
        echo "ERRO: Falha ao compactar o projeto Git '$project_dir'."
        rm -f "$file_list"
        return 1
    fi

    rm -f "$file_list"
}

get_git_commit() {
    local project_dir=$1
    git -C "$project_dir" rev-parse HEAD 2>/dev/null || true
}

get_git_branch() {
    local project_dir=$1
    git -C "$project_dir" branch --show-current 2>/dev/null || true
}

get_git_dirty() {
    local project_dir=$1

    if [[ -n "$(git -C "$project_dir" status --porcelain 2>/dev/null)" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

do_backup() {
    local type=$1
    local target_name=$2
    local target_key=$3
    local s3_dest=$4
    local filter_mode=${5:-none}

    init_temp_workspace

    local backup_id
    backup_id=$(generate_backup_id)

    local tar_name="${target_key}_${backup_id}.tar.gz"
    local manifest_name="${target_key}_${backup_id}.manifest.json"
    local tar_file="$BACWUPS3_WORKSPACE/$tar_name"
    local manifest_file="$BACWUPS3_WORKSPACE/$manifest_name"
    local s3_tar_uri
    local s3_manifest_uri
    local origin_path
    local manifest_target_type
    local git_commit=""
    local git_branch=""
    local git_dirty=""
    local git_metadata_included=""

    s3_tar_uri=$(s3_object_uri "$s3_dest" "$tar_name")
    s3_manifest_uri=$(s3_object_uri "$s3_dest" "$manifest_name")

    if ! ensure_s3_object_absent "$s3_tar_uri" || ! ensure_s3_object_absent "$s3_manifest_uri"; then
        return 1
    fi

    echo "Iniciando backup $backup_id..."

    if [[ "$type" == "volume" ]]; then
        filter_mode="none"
        manifest_target_type="volume"
        if ! docker run --rm -v "$target_name":/data:ro -v "$BACWUPS3_WORKSPACE":/backup "$DOCKER_BACKUP_IMAGE" tar -czf "/backup/$tar_name" -C /data .; then
            echo "ERRO: Falha ao compactar o volume Docker '$target_name'."
            return 1
        fi
        origin_path="docker_volume:$target_name"
    else
        manifest_target_type="directory"
        if [[ "$filter_mode" == "gitignore" ]]; then
            if ! create_gitignore_tar "$target_name" "$tar_file"; then
                rm -f "$tar_file" "$manifest_file"
                return 1
            fi
            git_commit=$(get_git_commit "$target_name" || true)
            git_branch=$(get_git_branch "$target_name" || true)
            git_dirty=$(get_git_dirty "$target_name" || true)
            git_metadata_included="false"
        else
            filter_mode="none"
            if ! tar -czf "$tar_file" -C "$target_name" .; then
                echo "ERRO: Falha ao compactar o diretório '$target_name'."
                return 1
            fi
        fi
        origin_path="$target_name"
    fi

    local archive_size
    if ! archive_size=$(stat -c '%s' "$tar_file"); then
        echo "ERRO: Não foi possível obter o tamanho do pacote de backup."
        rm -f "$tar_file" "$manifest_file"
        return 1
    fi

    local checksum
    if ! checksum=$(sha256sum "$tar_file" | awk '{print $1}'); then
        echo "ERRO: Não foi possível calcular o SHA256 do pacote de backup."
        rm -f "$tar_file" "$manifest_file"
        return 1
    fi

    if [[ -z "$checksum" ]]; then
        echo "ERRO: Não foi possível calcular o SHA256 do pacote de backup."
        rm -f "$tar_file" "$manifest_file"
        return 1
    fi

    if ! validate_sha256_value "$checksum"; then
        rm -f "$tar_file" "$manifest_file"
        return 1
    fi

    if ! generate_manifest "$manifest_target_type" "$target_name" "${target_key}_${backup_id}" "$origin_path" "$archive_size" "$checksum" "$manifest_file" "$filter_mode" "$git_commit" "$git_branch" "$git_dirty" "$git_metadata_included"; then
        echo "ERRO: Falha ao gerar o manifesto do backup."
        rm -f "$tar_file" "$manifest_file"
        return 1
    fi

    if ! validate_manifest "$manifest_file"; then
        rm -f "$tar_file" "$manifest_file"
        return 1
    fi

    if ! aws s3 cp "$tar_file" "$s3_tar_uri"; then
        echo "ERRO: Falha no upload do arquivo de backup para o S3."
        rm -f "$tar_file" "$manifest_file"
        return 1
    fi

    if ! aws s3 cp "$manifest_file" "$s3_manifest_uri"; then
        echo "ERRO: Falha no upload do manifesto para o S3."
        remove_remote_object "$s3_tar_uri" || true
        rm -f "$tar_file" "$manifest_file"
        return 1
    fi

    rm -f "$tar_file" "$manifest_file"
    echo "Backup finalizado e enviado com sucesso!"
}

do_restore() {
    local type=$1
    local target_name=$2
    local s3_src_tar=$3
    local s3_src_manifest=${s3_src_tar/.tar.gz/.manifest.json}

    local target_existed_before=false
    if [[ "$type" == "volume" ]]; then
        if docker volume inspect "$target_name" >/dev/null 2>&1; then
            target_existed_before=true
        fi
    elif [[ -e "$target_name" ]]; then
        target_existed_before=true
    fi

    if check_target_exists "$type" "$target_name"; then
        echo "ERRO: O $type '$target_name' já existe e contém dados. Restauração abortada para evitar sobrescrita."
        return 1
    fi

    init_temp_workspace

    local tmp_tar="$BACWUPS3_WORKSPACE/$(basename "$s3_src_tar")"
    local tmp_manifest="$BACWUPS3_WORKSPACE/$(basename "$s3_src_manifest")"

    echo "Baixando arquivos do S3..."
    if ! aws s3 cp "$s3_src_tar" "$tmp_tar"; then
        echo "ERRO: Falha no download do pacote de backup."
        rm -f "$tmp_tar" "$tmp_manifest"
        return 1
    fi

    if [[ ! -s "$tmp_tar" ]]; then
        echo "ERRO: Pacote de backup ausente ou vazio após download."
        rm -f "$tmp_tar" "$tmp_manifest"
        return 1
    fi

    if ! aws s3 cp "$s3_src_manifest" "$tmp_manifest"; then
        echo "ERRO: Falha no download do manifesto do backup."
        rm -f "$tmp_tar" "$tmp_manifest"
        return 1
    fi

    if ! validate_manifest "$tmp_manifest"; then
        echo "ERRO: Falha na validação do manifesto do backup."
        rm -f "$tmp_tar" "$tmp_manifest"
        return 1
    fi

    local expected_hash
    if ! expected_hash=$(manifest_field "$tmp_manifest" "sha256"); then
        echo "ERRO: Não foi possível ler o SHA256 esperado no manifesto."
        rm -f "$tmp_tar" "$tmp_manifest"
        return 1
    fi

    if ! validate_sha256_value "$expected_hash"; then
        rm -f "$tmp_tar" "$tmp_manifest"
        return 1
    fi

    local expected_size
    if ! expected_size=$(manifest_field "$tmp_manifest" "archive_size"); then
        echo "ERRO: Não foi possível ler o tamanho esperado no manifesto."
        rm -f "$tmp_tar" "$tmp_manifest"
        return 1
    fi

    local actual_size
    if ! actual_size=$(stat -c '%s' "$tmp_tar"); then
        echo "ERRO: Falha ao obter o tamanho do pacote baixado."
        rm -f "$tmp_tar" "$tmp_manifest"
        return 1
    fi

    if [[ "$expected_size" != "$actual_size" ]]; then
        echo "ERRO: Tamanho do pacote diverge do manifesto."
        rm -f "$tmp_tar" "$tmp_manifest"
        return 1
    fi

    local actual_hash
    if ! actual_hash=$(sha256sum "$tmp_tar" | awk '{print $1}'); then
        echo "ERRO: Falha ao calcular o SHA256 do pacote baixado."
        rm -f "$tmp_tar" "$tmp_manifest"
        return 1
    fi

    if [[ "$expected_hash" != "$actual_hash" ]]; then
        echo "ERRO CRÍTICO: Falha na verificação SHA256! O arquivo foi corrompido. Abortando."
        rm -f "$tmp_tar" "$tmp_manifest"
        return 1
    fi
    echo "Integridade confirmada (SHA256 validado)."

    if ! validate_archive_before_restore "$tmp_tar"; then
        rm -f "$tmp_tar" "$tmp_manifest"
        return 1
    fi

    if [[ "$type" == "volume" ]]; then
        local created_volume=false
        if ! docker volume create "$target_name"; then
            echo "ERRO: Falha ao criar o volume Docker de destino '$target_name'."
            rm -f "$tmp_tar" "$tmp_manifest"
            return 1
        fi
        created_volume=true

        if ! docker run --rm -v "$target_name":/data -v "$BACWUPS3_WORKSPACE":/backup "$DOCKER_BACKUP_IMAGE" tar -xzf "/backup/$(basename "$s3_src_tar")" -C /data; then
            echo "ERRO: Falha ao extrair o pacote para o volume Docker '$target_name'."
            if [[ "$created_volume" == "true" && "$target_existed_before" == "false" ]]; then
                rollback_created_target "$type" "$target_name" || true
            fi
            rm -f "$tmp_tar" "$tmp_manifest"
            return 1
        fi
    else
        local created_dir=false
        if ! mkdir -p "$target_name"; then
            echo "ERRO: Falha ao criar o diretório de destino '$target_name'."
            rm -f "$tmp_tar" "$tmp_manifest"
            return 1
        fi
        [[ "$target_existed_before" == "false" ]] && created_dir=true

        if ! tar -xzf "$tmp_tar" -C "$target_name"; then
            echo "ERRO: Falha ao extrair o pacote para o diretório '$target_name'."
            if [[ "$created_dir" == "true" ]]; then
                rollback_created_target "$type" "$target_name" || true
            fi
            rm -f "$tmp_tar" "$tmp_manifest"
            return 1
        fi
    fi

    rm -f "$tmp_tar" "$tmp_manifest"
    echo "Restauração concluída com sucesso!"
}
