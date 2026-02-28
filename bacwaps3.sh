#!/bin/bash

# ==========================================
# S3 Sync Manager - Main Entrypoint
# ==========================================

# Descobre o diretório real onde este script está salvo
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Importa as bibliotecas
source "$DIR/lib_core.sh"
source "$DIR/lib_ui.sh"

main_loop() {
    show_warning

    while true; do
        local ACTION
        ACTION=$(whiptail --title "Gerenciador S3 de Backups" --menu "O que você deseja fazer?" \
            $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT \
            "BACKUP" "Enviar dados para o S3" \
            "RESTORE" "Recuperar dados do S3" \
            "SAIR" "Sair da aplicação" 3>&1 1>&2 2>&3)
        
        [[ $? -ne 0 || "$ACTION" == "SAIR" ]] && break

        local TARGET_TYPE
        TARGET_TYPE=$(whiptail --title "Tipo de Alvo" --menu "Escolha o tipo de dado:" \
            $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT \
            "volume" "Volume Docker" \
            "dir" "Diretório Local" 3>&1 1>&2 2>&3)

        [[ $? -ne 0 ]] && continue

        local TARGET_NAME
        local PROMPT_MSG="Digite o nome do volume:"
        [[ "$TARGET_TYPE" == "dir" ]] && PROMPT_MSG="Digite o caminho completo do diretório (ex: /opt/app):"
        
        TARGET_NAME=$(get_input "Identificação do Alvo" "$PROMPT_MSG" "")
        [[ -z "$TARGET_NAME" ]] && continue

        local S3_PATH
        S3_PATH=$(get_input "Destino S3" "Digite o caminho do bucket S3 (ex: s3://meu-bucket/backups/):" "s3://")
        [[ -z "$S3_PATH" ]] && continue

        [[ "${S3_PATH: -1}" != "/" ]] && S3_PATH="${S3_PATH}/"

        if [[ "$ACTION" == "BACKUP" ]]; then
            clear 
            echo "Iniciando processo de Backup..."
            do_backup "$TARGET_TYPE" "$TARGET_NAME" "$S3_PATH"
            read -p "Pressione [ENTER] para voltar ao menu..."
        
        elif [[ "$ACTION" == "RESTORE" ]]; then
            local S3_TARGET_FILE
            S3_TARGET_FILE=$(select_s3_version "$S3_PATH" "$TARGET_NAME")
            [[ $? -ne 0 || -z "$S3_TARGET_FILE" ]] && continue

            clear
            echo "Iniciando processo de Restauração..."
            do_restore "$TARGET_TYPE" "$TARGET_NAME" "$S3_TARGET_FILE"
            read -p "Pressione [ENTER] para voltar ao menu..."
        fi
    done

    clear
    echo "Saindo... Até logo!"
}

# Inicia a aplicação
main_loop