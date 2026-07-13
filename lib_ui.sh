#!/bin/bash
set -Eeuo pipefail

# ==========================================
# lib_ui.sh - Configurações e Telas do Whiptail
# ==========================================

WT_HEIGHT=15
WT_WIDTH=60
WT_MENU_HEIGHT=6

show_warning() {
    whiptail --title "AVISO IMPORTANTE" --msgbox \
"Esta ferramenta NÃO pausa contêineres automaticamente.

Certifique-se de que os serviços que escrevem no volume ou diretório alvo estejam parados para evitar corrupção de dados durante o backup/restore." \
    $WT_HEIGHT $WT_WIDTH
}

get_input() {
    local title=$1
    local prompt=$2
    local default_text=$3
    
    local result
    if ! result=$(whiptail --title "$title" --inputbox "$prompt" $WT_HEIGHT $WT_WIDTH "$default_text" 3>&1 1>&2 2>&3); then
        return 1
    fi
    echo "$result"
}

select_docker_volume() {
    local volumes_raw=$1
    local options=()

    options+=("ATUALIZAR" "Recarregar volumes do Docker")

    while IFS= read -r volume; do
        [[ -n "$volume" ]] && options+=("$volume" "Volume disponível")
    done <<< "$volumes_raw"

    if [[ ${#options[@]} -eq 2 ]]; then
        whiptail --title "Erro" --msgbox "Nenhum volume Docker encontrado neste host." $WT_HEIGHT $WT_WIDTH
        return 1
    fi

    local selected_volume
    if ! selected_volume=$(whiptail --title "Selecionar Volume" --menu "Escolha o volume Docker:" \
        $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT "${options[@]}" 3>&1 1>&2 2>&3); then
        return 1
    fi

    if [[ "$selected_volume" == "ATUALIZAR" ]]; then
        return 2
    fi

    echo "$selected_volume"
}

select_directory() {
    local current_dir=${1:-$HOME}

    while true; do
        [[ ! -d "$current_dir" ]] && current_dir="$HOME"

        local options=()
        options+=("SELECIONAR_ATUAL" "$current_dir")
        options+=("ATUALIZAR" "Recarregar diretórios")

        if [[ "$current_dir" != "/" ]]; then
            options+=("SUBIR" "Ir para $(dirname "$current_dir")")
        fi

        local dir_map=()
        local idx=1
        local child
        while IFS= read -r child; do
            [[ -z "$child" ]] && continue
            options+=("$idx" "$(basename "$child")/")
            dir_map[$idx]="$child"
            idx=$((idx + 1))
        done < <(find "$current_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)

        local selected
        if ! selected=$(whiptail --title "Selecionar Diretório" --menu "Diretório atual: $current_dir" \
            $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT "${options[@]}" 3>&1 1>&2 2>&3); then
            return 1
        fi

        case "$selected" in
            "SELECIONAR_ATUAL")
                echo "$current_dir"
                return 0
                ;;
            "ATUALIZAR")
                continue
                ;;
            "SUBIR")
                current_dir=$(dirname "$current_dir")
                [[ -z "$current_dir" ]] && current_dir="/"
                ;;
            *)
                if [[ -n "${dir_map[$selected]}" ]]; then
                    current_dir="${dir_map[$selected]}"
                fi
                ;;
        esac
    done
}

select_directory_backup_mode() {
    local selected_mode

    if ! selected_mode=$(whiptail --title "Modo de Backup do Diretório" --menu "Escolha como o diretório deve ser empacotado:" \
        $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT \
        "none" "Diretório completo" \
        "gitignore" "Projeto Git, respeitando .gitignore" 3>&1 1>&2 2>&3); then
        return 1
    fi

    echo "$selected_mode"
}

select_restore_directory() {
    local current_dir=${1:-$HOME}

    while true; do
        [[ ! -d "$current_dir" ]] && current_dir="$HOME"

        local options=()
        options+=("RESTAURAR_AQUI" "Usar este diretório como destino")
        options+=("NOVA_PASTA_AQUI" "Criar/usar subpasta dentro deste diretório")
        options+=("ATUALIZAR" "Recarregar diretórios")

        if [[ "$current_dir" != "/" ]]; then
            options+=("SUBIR" "Ir para $(dirname "$current_dir")")
        fi

        local dir_map=()
        local idx=1
        local child
        while IFS= read -r child; do
            [[ -z "$child" ]] && continue
            options+=("$idx" "$(basename "$child")/")
            dir_map[$idx]="$child"
            idx=$((idx + 1))
        done < <(find "$current_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)

        local selected
        if ! selected=$(whiptail --title "Destino da Restauração" --menu "Diretório atual: $current_dir" \
            $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT "${options[@]}" 3>&1 1>&2 2>&3); then
            return 1
        fi

        case "$selected" in
            "RESTAURAR_AQUI")
                echo "$current_dir"
                return 0
                ;;
            "NOVA_PASTA_AQUI")
                local folder_name
                if ! folder_name=$(whiptail --title "Nova Subpasta" --inputbox "Digite o nome da subpasta destino:" \
                    $WT_HEIGHT $WT_WIDTH "" 3>&1 1>&2 2>&3); then
                    continue
                fi
                folder_name="${folder_name#/}"
                folder_name="${folder_name%/}"
                [[ -z "$folder_name" ]] && continue

                if [[ "$current_dir" == "/" ]]; then
                    echo "/${folder_name}"
                else
                    echo "${current_dir}/${folder_name}"
                fi
                return 0
                ;;
            "ATUALIZAR")
                continue
                ;;
            "SUBIR")
                current_dir=$(dirname "$current_dir")
                [[ -z "$current_dir" ]] && current_dir="/"
                ;;
            *)
                if [[ -n "${dir_map[$selected]}" ]]; then
                    current_dir="${dir_map[$selected]}"
                fi
                ;;
        esac
    done
}

sanitize_restore_subdir_name() {
    local folder_name=$1

    folder_name="${folder_name#/}"
    folder_name="${folder_name%/}"
    folder_name="${folder_name//../}"
    folder_name="${folder_name#/}"
    folder_name="${folder_name%/}"
    folder_name="${folder_name//\//_}"
    echo "$folder_name"
}

join_restore_directory_path() {
    local parent_dir=$1
    local folder_name=$2

    folder_name=$(sanitize_restore_subdir_name "$folder_name")
    [[ -z "$folder_name" ]] && return 1

    if [[ "$parent_dir" == "/" ]]; then
        echo "/${folder_name}"
    else
        echo "${parent_dir%/}/${folder_name}"
    fi
}

default_restore_directory_name_from_manifest() {
    local manifest_file=$1
    local target_name=""
    local origin_path=""
    local default_name=""

    if target_name=$(manifest_field "$manifest_file" "target_name" 2>/dev/null); then
        target_name="${target_name%/}"
        default_name=$(basename "$target_name")
    fi

    if [[ -z "$default_name" || "$default_name" == "." || "$default_name" == "/" || "$default_name" == "null" ]]; then
        if origin_path=$(manifest_field "$manifest_file" "origin_path" 2>/dev/null); then
            origin_path="${origin_path%/}"
            default_name=$(basename "$origin_path")
        fi
    fi

    [[ "$default_name" == "." || "$default_name" == "/" || "$default_name" == "null" ]] && default_name=""
    echo "$default_name"
}

confirm_restore_directory_name() {
    local parent_dir=$1
    local manifest_file=$2
    local default_name

    default_name=$(default_restore_directory_name_from_manifest "$manifest_file")

    while true; do
        local folder_name
        if ! folder_name=$(whiptail --title "Diretório Restaurado" --inputbox \
"Confirme o nome do diretório que será criado dentro de:\n$parent_dir" \
            $WT_HEIGHT $WT_WIDTH "$default_name" 3>&1 1>&2 2>&3); then
            return 1
        fi

        folder_name=$(sanitize_restore_subdir_name "$folder_name")
        [[ -z "$folder_name" ]] && continue

        join_restore_directory_path "$parent_dir" "$folder_name"
        return 0
    done
}

select_s3_path() {
    local buckets_raw=$1
    local mode=${2:-backup}
    local options=()
    local title="Destino S3"
    local bucket_prompt="Selecione o bucket de destino:"
    local prefix_prompt="Informe um prefixo/pasta de destino (opcional). Ex: backups/projeto"

    if [[ "$mode" == "restore" || "$mode" == "RESTORE" || "$mode" == "verify" || "$mode" == "VERIFY" ]]; then
        title="Origem S3"
        bucket_prompt="Selecione o bucket onde o backup está armazenado:"
        prefix_prompt="Informe o prefixo/pasta onde o backup está armazenado (opcional). Ex: backups/projeto"
    fi

    options+=("ATUALIZAR" "Recarregar buckets da AWS")

    while IFS= read -r bucket; do
        [[ -n "$bucket" ]] && options+=("$bucket" "Bucket disponível")
    done <<< "$buckets_raw"

    if [[ ${#options[@]} -eq 2 ]]; then
        whiptail --title "Erro" --msgbox "Nenhum bucket S3 disponível para a conta autenticada." $WT_HEIGHT $WT_WIDTH
        return 1
    fi

    local selected_bucket
    if ! selected_bucket=$(whiptail --title "$title" --menu "$bucket_prompt" \
        $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT "${options[@]}" 3>&1 1>&2 2>&3); then
        return 1
    fi

    if [[ "$selected_bucket" == "ATUALIZAR" ]]; then
        return 2
    fi

    local prefix
    if ! prefix=$(whiptail --title "$title - Prefixo no Bucket" --inputbox "$prefix_prompt" \
        $WT_HEIGHT $WT_WIDTH "" 3>&1 1>&2 2>&3); then
        return 1
    fi

    prefix="${prefix#/}"
    [[ -n "$prefix" && "${prefix: -1}" != "/" ]] && prefix="${prefix}/"

    echo "s3://${selected_bucket}/${prefix}"
}

select_s3_version() {
    local s3_base_path=$1
    local target_key=$2
    local target_label=$3

    local files_raw
    files_raw=$(aws s3 ls "$s3_base_path" | awk '{print $4}' | grep -E "^${target_key}_v[0-9]+\.tar\.gz$" | sort -V || true)

    if [[ -z "$files_raw" ]]; then
        whiptail --title "Erro" --msgbox "Nenhum backup encontrado no S3 para '$target_label' no caminho:\n$s3_base_path" $WT_HEIGHT $WT_WIDTH
        return 1
    fi

    local options=()
    for file in $files_raw; do
        options+=("$file" "")
    done

    local selected_file
    if ! selected_file=$(whiptail --title "Selecionar Versão" --menu "Escolha qual versão de '$target_label' deseja restaurar:" \
        $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT "${options[@]}" 3>&1 1>&2 2>&3); then
        return 1
    fi

    echo "${s3_base_path}${selected_file}"
}

select_s3_backup_file() {
    local s3_base_path=$1

    local files_raw
    files_raw=$(aws s3 ls "$s3_base_path" | awk '{print $4}' | grep -E '\.tar\.gz$' | sort -V || true)

    if [[ -z "$files_raw" ]]; then
        whiptail --title "Erro" --msgbox "Nenhum arquivo de backup (.tar.gz) encontrado em:\n$s3_base_path" $WT_HEIGHT $WT_WIDTH
        return 1
    fi

    local options=()
    local file
    for file in $files_raw; do
        options+=("$file" "Backup disponível")
    done

    local selected_file
    if ! selected_file=$(whiptail --title "Selecionar Backup" --menu "Escolha o arquivo de backup:" \
        $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT "${options[@]}" 3>&1 1>&2 2>&3); then
        return 1
    fi

    echo "${s3_base_path}${selected_file}"
}

confirm_restore_with_manifest() {
    local manifest_file=$1
    local s3_tar_file=$2
    local target_type=$3
    local target_name=$4

    if ! whiptail --title "Manifesto do Backup" --textbox "$manifest_file" $WT_HEIGHT $WT_WIDTH; then
        return 1
    fi

    whiptail --title "Confirmar Restauração" --yesno \
"Arquivo selecionado:\n$s3_tar_file\n\nDestino ($target_type):\n$target_name\n\nDeseja continuar com a restauração?" \
    $WT_HEIGHT $WT_WIDTH

    return $?
}
