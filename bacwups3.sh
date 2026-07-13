#!/bin/bash
set -Eeuo pipefail

# ==========================================
# bacwups3 - Main Entrypoint
# ==========================================

# Descobre o diretório real onde este script está salvo
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Importa as bibliotecas
source "$DIR/lib_core.sh"
source "$DIR/lib_ui.sh"

load_env_file "$DIR/.env"

main_loop() {
    local AVAILABLE_BUCKETS
    if ! AVAILABLE_BUCKETS=$(check_aws_session_and_list_buckets); then
        whiptail --title "Erro de Autenticação AWS" --msgbox \
"Não foi possível validar o acesso ao S3.\n\nVerifique credenciais, profile/região e, para usuário IAM restrito a um bucket, configure BACWUPS3_S3_BUCKET no .env." \
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
        if ! ACTION=$(whiptail --title "Gerenciador S3 de Backups" --menu "O que você deseja fazer?" \
            $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT \
            "BACKUP" "Enviar dados para o S3" \
            "RESTORE" "Recuperar dados do S3" \
            "VERIFY" "Verificar backup sem restaurar" \
            "SAIR" "Sair da aplicação" 3>&1 1>&2 2>&3); then
            break
        fi
        
        [[ "$ACTION" == "SAIR" ]] && break

        local TARGET_TYPE=""
        local TARGET_NAME=""
        local TARGET_KEY=""
        local FILTER_MODE="none"

        if [[ "$ACTION" == "BACKUP" || "$ACTION" == "RESTORE" ]]; then
            if ! TARGET_TYPE=$(whiptail --title "Tipo de Alvo" --menu "Escolha o tipo de dado:" \
                $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT \
                "volume" "Volume Docker" \
                "dir" "Diretório Local" 3>&1 1>&2 2>&3); then
                continue
            fi

            if [[ "$ACTION" == "BACKUP" ]]; then
                if [[ "$TARGET_TYPE" == "volume" ]]; then
                    local AVAILABLE_VOLUMES
                    while true; do
                        if ! AVAILABLE_VOLUMES=$(list_docker_volumes); then
                            whiptail --title "Erro Docker" --msgbox \
"Não foi possível executar 'docker volume ls'.\n\nVerifique se o Docker está instalado e se o daemon está em execução." \
                            $WT_HEIGHT $WT_WIDTH
                            continue 2
                        fi

                        local volume_select_status=0
                        TARGET_NAME=$(select_docker_volume "$AVAILABLE_VOLUMES") || volume_select_status=$?

                        if [[ $volume_select_status -eq 2 ]]; then
                            continue
                        fi

                        [[ $volume_select_status -ne 0 || -z "$TARGET_NAME" ]] && continue 2
                        break
                    done
                else
                    if ! TARGET_NAME=$(select_directory "$HOME"); then
                        continue
                    fi
                fi
            else
                if [[ "$TARGET_TYPE" == "volume" ]]; then
                    if ! TARGET_NAME=$(get_input "Volume de Destino" "Digite o nome do volume Docker de destino (novo):" ""); then
                        continue
                    fi
                else
                    if ! TARGET_NAME=$(select_restore_directory "$HOME"); then
                        continue
                    fi
                fi
            fi

            [[ -z "$TARGET_NAME" ]] && continue

            if [[ "$ACTION" == "BACKUP" && "$TARGET_TYPE" == "dir" ]]; then
                if ! FILTER_MODE=$(select_directory_backup_mode); then
                    continue
                fi
                [[ -z "$FILTER_MODE" ]] && continue
            fi

            TARGET_KEY=$(build_target_key "$TARGET_TYPE" "$TARGET_NAME")
        fi

        local S3_PATH
        while true; do
            local s3_select_status=0
            S3_PATH=$(select_s3_path "$AVAILABLE_BUCKETS" "$ACTION") || s3_select_status=$?

            if [[ $s3_select_status -eq 2 ]]; then
                if ! AVAILABLE_BUCKETS=$(check_aws_session_and_list_buckets); then
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
            if ! do_backup "$TARGET_TYPE" "$TARGET_NAME" "$TARGET_KEY" "$S3_PATH" "$FILTER_MODE"; then
                echo "Backup não concluído."
            fi
            read -r -p "Pressione [ENTER] para voltar ao menu..." || true
        
        elif [[ "$ACTION" == "RESTORE" ]]; then
            local S3_TARGET_FILE
            if ! S3_TARGET_FILE=$(select_s3_backup_file "$S3_PATH"); then
                continue
            fi
            [[ -z "$S3_TARGET_FILE" ]] && continue

            local PREVIEW_MANIFEST
            if ! PREVIEW_MANIFEST=$(download_manifest_preview "$S3_TARGET_FILE"); then
                whiptail --title "Erro" --msgbox \
"Não foi possível obter o manifesto correspondente ao arquivo selecionado.\n\nRestauração cancelada." \
                $WT_HEIGHT $WT_WIDTH
                continue
            fi
            if [[ -z "$PREVIEW_MANIFEST" ]]; then
                whiptail --title "Erro" --msgbox \
"Manifesto correspondente vazio.\n\nRestauração cancelada." \
                $WT_HEIGHT $WT_WIDTH
                continue
            fi

            if [[ "$TARGET_TYPE" == "dir" ]]; then
                if ! TARGET_NAME=$(confirm_restore_directory_name "$TARGET_NAME" "$PREVIEW_MANIFEST"); then
                    rm -f "$PREVIEW_MANIFEST"
                    continue
                fi
                [[ -z "$TARGET_NAME" ]] && {
                    rm -f "$PREVIEW_MANIFEST"
                    continue
                }
            fi

            local restore_confirm_status=0
            confirm_restore_with_manifest "$PREVIEW_MANIFEST" "$S3_TARGET_FILE" "$TARGET_TYPE" "$TARGET_NAME" || restore_confirm_status=$?
            rm -f "$PREVIEW_MANIFEST"
            [[ $restore_confirm_status -ne 0 ]] && continue

            clear
            echo "Iniciando processo de Restauração..."
            if ! do_restore "$TARGET_TYPE" "$TARGET_NAME" "$S3_TARGET_FILE"; then
                echo "Restauração não concluída."
            fi
            read -r -p "Pressione [ENTER] para voltar ao menu..." || true

        elif [[ "$ACTION" == "VERIFY" ]]; then
            local S3_TARGET_FILE
            if ! S3_TARGET_FILE=$(select_s3_backup_file "$S3_PATH"); then
                continue
            fi
            [[ -z "$S3_TARGET_FILE" ]] && continue

            clear
            echo "Iniciando verificação do backup..."
            if ! do_verify_backup "$S3_TARGET_FILE"; then
                echo "Verificação não concluída."
            fi
            read -r -p "Pressione [ENTER] para voltar ao menu..." || true
        fi
    done

    clear
    echo "Saindo... Até logo!"
}

# Inicia a aplicação
main_loop
