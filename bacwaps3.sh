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
    local AVAILABLE_BUCKETS
    AVAILABLE_BUCKETS=$(check_aws_session_and_list_buckets)

    if [[ $? -ne 0 ]]; then
        whiptail --title "Erro de Autenticação AWS" --msgbox \
"Não foi possível executar 'aws s3 ls'.\n\nVerifique se há uma sessão ativa/configuração válida da AWS CLI (credenciais, profile e região)." \
        $WT_HEIGHT $WT_WIDTH
        return 1
    fi

    if [[ -z "$AVAILABLE_BUCKETS" ]]; then
        whiptail --title "Nenhum Bucket Encontrado" --msgbox \
"A sessão AWS está ativa, mas nenhum bucket foi encontrado para essa conta." \
        $WT_HEIGHT $WT_WIDTH
        return 1
    fi

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
        if [[ "$ACTION" == "BACKUP" ]]; then
            if [[ "$TARGET_TYPE" == "volume" ]]; then
                local AVAILABLE_VOLUMES
                while true; do
                    AVAILABLE_VOLUMES=$(list_docker_volumes)

                    if [[ $? -ne 0 ]]; then
                        whiptail --title "Erro Docker" --msgbox \
"Não foi possível executar 'docker volume ls'.\n\nVerifique se o Docker está instalado e se o daemon está em execução." \
                        $WT_HEIGHT $WT_WIDTH
                        continue 2
                    fi

                    TARGET_NAME=$(select_docker_volume "$AVAILABLE_VOLUMES")
                    local volume_select_status=$?

                    if [[ $volume_select_status -eq 2 ]]; then
                        continue
                    fi

                    [[ $volume_select_status -ne 0 || -z "$TARGET_NAME" ]] && continue 2
                    break
                done
            else
                TARGET_NAME=$(select_directory "$HOME")
            fi
        else
            if [[ "$TARGET_TYPE" == "volume" ]]; then
                TARGET_NAME=$(get_input "Volume de Destino" "Digite o nome do volume Docker de destino (novo):" "")
            else
                TARGET_NAME=$(select_restore_directory "$HOME")
            fi
        fi

        [[ -z "$TARGET_NAME" ]] && continue

        local TARGET_KEY
        TARGET_KEY=$(build_target_key "$TARGET_TYPE" "$TARGET_NAME")

        local S3_PATH
        while true; do
            S3_PATH=$(select_s3_path "$AVAILABLE_BUCKETS")
            local s3_select_status=$?

            if [[ $s3_select_status -eq 2 ]]; then
                AVAILABLE_BUCKETS=$(check_aws_session_and_list_buckets)
                if [[ $? -ne 0 ]]; then
                    whiptail --title "Erro de Autenticação AWS" --msgbox \
"Falha ao atualizar buckets com 'aws s3 ls'.\n\nVerifique se sua sessão AWS continua ativa." \
                    $WT_HEIGHT $WT_WIDTH
                    continue 2
                fi

                if [[ -z "$AVAILABLE_BUCKETS" ]]; then
                    whiptail --title "Nenhum Bucket Encontrado" --msgbox \
"A sessão AWS está ativa, mas nenhum bucket foi encontrado para essa conta." \
                    $WT_HEIGHT $WT_WIDTH
                    continue 2
                fi

                continue
            fi

            [[ $s3_select_status -ne 0 || -z "$S3_PATH" ]] && continue 2
            break
        done

        [[ "${S3_PATH: -1}" != "/" ]] && S3_PATH="${S3_PATH}/"

        if [[ "$ACTION" == "BACKUP" ]]; then
            clear 
            echo "Iniciando processo de Backup..."
            do_backup "$TARGET_TYPE" "$TARGET_NAME" "$TARGET_KEY" "$S3_PATH"
            read -p "Pressione [ENTER] para voltar ao menu..."
        
        elif [[ "$ACTION" == "RESTORE" ]]; then
            local S3_TARGET_FILE
            S3_TARGET_FILE=$(select_s3_backup_file "$S3_PATH")
            [[ $? -ne 0 || -z "$S3_TARGET_FILE" ]] && continue

            local PREVIEW_MANIFEST
            PREVIEW_MANIFEST=$(download_manifest_preview "$S3_TARGET_FILE")
            if [[ $? -ne 0 || -z "$PREVIEW_MANIFEST" ]]; then
                whiptail --title "Erro" --msgbox \
"Não foi possível obter o manifesto correspondente ao arquivo selecionado.\n\nRestauração cancelada." \
                $WT_HEIGHT $WT_WIDTH
                continue
            fi

            confirm_restore_with_manifest "$PREVIEW_MANIFEST" "$S3_TARGET_FILE" "$TARGET_TYPE" "$TARGET_NAME"
            local restore_confirm_status=$?
            rm -f "$PREVIEW_MANIFEST"
            [[ $restore_confirm_status -ne 0 ]] && continue

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