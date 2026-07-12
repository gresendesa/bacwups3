#!/bin/bash

# ==========================================
# lib_core.sh - Funções de Segurança, S3 e Execução
# ==========================================

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
    local tmp_manifest="/tmp/preview_$(basename "$s3_src_manifest")_$$"

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

get_next_version() {
    local s3_base_path=$1
    local item_name=$2
    local last_version=$(aws s3 ls "$s3_base_path" | grep -oP "${item_name}_v\K\d+(?=\.tar\.gz)" | sort -n | tail -1)
    
    if [[ -z "$last_version" ]]; then
        echo "1"
    else
        echo $((last_version + 1))
    fi
}

generate_manifest() {
    local item_name=$1
    local version=$2
    local origin_path=$3
    local checksum=$4
    local manifest_file=$5
    local filter_mode=${6:-none}
    local git_commit=${7:-}
    local git_branch=${8:-}
    local git_dirty=${9:-}
    local git_metadata_included=${10:-}

    {
        cat <<EOF
{
  "nome_origem": "$item_name",
  "versao": "v$version",
  "maquina_origem": "$(hostname)",
  "usuario": "$(whoami)",
  "data_backup": "$(date --iso-8601=seconds)",
  "caminho_original": "$origin_path",
  "filter_mode": "$filter_mode",
  "sha256": "$checksum"
EOF

        if [[ "$filter_mode" == "gitignore" ]]; then
            printf ',\n  "git_commit": '
            if [[ -n "$git_commit" ]]; then
                printf '"%s"' "$git_commit"
            else
                printf 'null'
            fi

            printf ',\n  "git_branch": '
            if [[ -n "$git_branch" ]]; then
                printf '"%s"' "$git_branch"
            else
                printf 'null'
            fi

            printf ',\n  "git_dirty": '
            if [[ -n "$git_dirty" ]]; then
                printf '%s' "$git_dirty"
            else
                printf 'null'
            fi

            printf ',\n  "git_metadata_included": %s' "$git_metadata_included"
        fi

        printf '\n}\n'
    } > "$manifest_file"
}

create_gitignore_tar() {
    local project_dir=$1
    local tar_file=$2
    local file_list

    if ! git -C "$project_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "ERRO: O diretório '$project_dir' não pertence a um repositório Git."
        return 1
    fi

    file_list=$(mktemp "/tmp/bacwaps3_git_files.XXXXXX")
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

    local next_v
    next_v=$(get_next_version "$s3_dest" "$target_key")
    local tar_file="/tmp/${target_key}_v${next_v}.tar.gz"
    local manifest_file="/tmp/${target_key}_v${next_v}.manifest.json"
    local origin_path
    local git_commit=""
    local git_branch=""
    local git_dirty=""
    local git_metadata_included=""

    echo "Iniciando backup da versão v${next_v}..."

    if [[ "$type" == "volume" ]]; then
        filter_mode="none"
        if ! docker run --rm -v "$target_name":/data -v /tmp:/backup alpine tar -czf "/backup/${target_key}_v${next_v}.tar.gz" -C /data .; then
            echo "ERRO: Falha ao compactar o volume Docker '$target_name'."
            return 1
        fi
        origin_path="docker_volume:$target_name"
    else
        if [[ "$filter_mode" == "gitignore" ]]; then
            if ! create_gitignore_tar "$target_name" "$tar_file"; then
                rm -f "$tar_file" "$manifest_file"
                return 1
            fi
            git_commit=$(get_git_commit "$target_name")
            git_branch=$(get_git_branch "$target_name")
            git_dirty=$(get_git_dirty "$target_name")
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

    local checksum
    checksum=$(sha256sum "$tar_file" | awk '{print $1}')
    if [[ -z "$checksum" ]]; then
        echo "ERRO: Não foi possível calcular o SHA256 do pacote de backup."
        rm -f "$tar_file" "$manifest_file"
        return 1
    fi

    if ! generate_manifest "$target_name" "$next_v" "$origin_path" "$checksum" "$manifest_file" "$filter_mode" "$git_commit" "$git_branch" "$git_dirty" "$git_metadata_included"; then
        echo "ERRO: Falha ao gerar o manifesto do backup."
        rm -f "$tar_file" "$manifest_file"
        return 1
    fi

    if ! aws s3 cp "$tar_file" "$s3_dest"; then
        echo "ERRO: Falha no upload do arquivo de backup para o S3."
        rm -f "$tar_file" "$manifest_file"
        return 1
    fi

    if ! aws s3 cp "$manifest_file" "$s3_dest"; then
        echo "ERRO: Falha no upload do manifesto para o S3."
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

    if check_target_exists "$type" "$target_name"; then
        echo "ERRO: O $type '$target_name' já existe e contém dados. Restauração abortada para evitar sobrescrita."
        return 1
    fi

    local tmp_tar="/tmp/$(basename "$s3_src_tar")"
    local tmp_manifest="/tmp/$(basename "$s3_src_manifest")"

    echo "Baixando arquivos do S3..."
    aws s3 cp "$s3_src_tar" "$tmp_tar"
    aws s3 cp "$s3_src_manifest" "$tmp_manifest"

    local expected_hash=$(grep -oP '"sha256": "\K[^"]+' "$tmp_manifest")
    local actual_hash=$(sha256sum "$tmp_tar" | awk '{print $1}')

    if [[ "$expected_hash" != "$actual_hash" ]]; then
        echo "ERRO CRÍTICO: Falha na verificação SHA256! O arquivo foi corrompido. Abortando."
        rm -f "$tmp_tar" "$tmp_manifest"
        return 1
    fi
    echo "Integridade confirmada (SHA256 validado)."

    if [[ "$type" == "volume" ]]; then
        docker volume create "$target_name"
        docker run --rm -v "$target_name":/data -v /tmp:/backup alpine tar -xzf "/backup/$(basename "$s3_src_tar")" -C /data
    else
        mkdir -p "$target_name"
        tar -xzf "$tmp_tar" -C "$target_name"
    fi

    rm -f "$tmp_tar" "$tmp_manifest"
    echo "Restauração concluída com sucesso!"
}
