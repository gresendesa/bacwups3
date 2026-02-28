#!/bin/bash

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
    result=$(whiptail --title "$title" --inputbox "$prompt" $WT_HEIGHT $WT_WIDTH "$default_text" 3>&1 1>&2 2>&3)
    
    if [ $? -ne 0 ]; then
        return 1
    fi
    echo "$result"
}

select_s3_version() {
    local s3_base_path=$1
    local target_name=$2

    local files_raw
    files_raw=$(aws s3 ls "$s3_base_path" | grep -oP "${target_name}_v\d+\.tar\.gz" | sort -V)

    if [[ -z "$files_raw" ]]; then
        whiptail --title "Erro" --msgbox "Nenhum backup encontrado no S3 para '$target_name' no caminho:\n$s3_base_path" $WT_HEIGHT $WT_WIDTH
        return 1
    fi

    local options=()
    for file in $files_raw; do
        options+=("$file" "")
    done

    local selected_file
    selected_file=$(whiptail --title "Selecionar Versão" --menu "Escolha qual versão de '$target_name' deseja restaurar:" \
        $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT "${options[@]}" 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
        return 1
    fi

    echo "${s3_base_path}${selected_file}"
}