#!/bin/bash

# Логотип команды
#show_logotip() {
#    bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/name.sh)
#}
# Цвета для текста
TERRACOTTA='\033[38;5;208m'
LIGHT_BLUE='\033[38;5;117m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'
PURPLE='\033[0;35m'

# Функции для форматирования текста
function show() {
    echo -e "${TERRACOTTA}$1${NC}"
}

function show_bold() {
    echo -en "${TERRACOTTA}${BOLD}$1${NC}"
}

function show_blue() {
    echo -e "${LIGHT_BLUE}$1${NC}"
}

function show_war() {
    echo -e "${RED}${BOLD}$1${NC}"
}

function show_purple() {
    echo -e "${PURPLE}$1${NC}"
}

# Вывод названия узла
show_name() {
#    echo ""
#    echo -e "\033[1;35mINK chain 11111111111node\033[0m"
#    echo ""
#}

# ASCII-арт
echo ""
show_purple '░░░░░▀█▀░█▄░░█░█░▄▀░░░█▀▀█░█░░█░█▀▀█░▀█▀░█▄░░█░░░█▄░░█░█▀▀█░█▀▀▄░█▀▀▀░░░░░'
show_purple '░░░░░░█░░█░█░█░█▀▄░░░░█░░░░█▀▀█░█▄▄█░░█░░█░█░█░░░█░█░█░█░░█░█░░█░█▀▀▀░░░░░'
show_purple '░░░░░▄█▄░█░░▀█░█░░█░░░█▄▄█░█░░█░█░░█░▄█▄░█░░▀█░░░█░░▀█░█▄▄█░█▄▄▀░█▄▄▄░░░░░'
echo ""
}

# Функция для подтверждения действия
confirm() {
    local prompt="$1"
    echo -en "$prompt [y/n, Enter = yes]: "  # Выводим вопрос с цветом
    read choice  # Читаем ввод пользователя
    case "$choice" in
        ""|y|Y|yes|Yes)  # Пустой ввод или "да"
            return 0  # Подтверждение действия
            ;;
        n|N|no|No)  # Любой вариант "нет"
            return 1  # Отказ от действия
            ;;
        *)
            show_war 'Пожалуйста, введите y или n.'
            confirm "$prompt"  # Повторный запрос, если ответ не распознан
            ;;
    esac
}

ink_dir="$HOME/ink/node"

# Функция для установки зависимостей
install_dependencies() {
    show_bold 'Установить необходимые пакеты и зависимости?'
    if confirm ''; then
        bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/admin/docker.sh)
        sudo apt install jq net-tools
    else
        show_war 'Отменено.'
    fi
}

clone_rep() {
    show 'Клонирование репозитория Ink node..'
    if [ -d "$ink_dir" ]; then
        show "Репозиторий уже скачан. Пропуск клонирования."
    else
        git clone https://github.com/inkonchain/node.git "$ink_dir" || {
            show_war 'Ошибка: не удалось клонировать репозиторий.'
            exit 0
        }
    fi
}

# Функция установки ноды
install_node() {
    mkdir -p ~/ink && cd ~/ink
    clone_rep

    show "Переход в директорию узла..."
    cd "$ink_dir" || {
        show_war "Ошибка: директория node не найдена!"
    }
   
    # Проверка и замена портов в docker-compose.yml
    compose_file="$ink_dir/docker-compose.yml"
    if [ -f "$compose_file" ]; then
        show "Файл $compose_file найден. Проверка и настройка портов..."
        docker compose down
        # Массив с портами и их назначением
        declare -A port_mapping=(
            ["8545"]="8525"
            ["8546"]="8526"
            ["30303"]="30313"
            ["9545"]="9515"
            ["9222"]="9232"
        )

        for original_port in "${!port_mapping[@]}"; do
            new_port=${port_mapping[$original_port]}
            show "Проверка порта $new_port..."

            # Если порт занят, запрос нового значения
            while ss -tuln | grep -q ":$new_port "; do
                show_war "Порт $new_port занят."
                read -p "$(echo -e "${TERRACOTTA}${BOLD}Введите новый порт для замены $original_port (текущий: $new_port): ${NC}")" user_port
                if [[ $user_port =~ ^[0-9]+$ && $user_port -ge 1 && $user_port -le 65535 ]]; then
                    if ss -tuln | grep -q ":$user_port "; then
                        show_war "Ошибка: введённый порт $user_port тоже занят. Попробуйте снова."
                    else
                        new_port=$user_port
                        break  # Выход из цикла, если порт свободен
                    fi
                else
                    show_war "Некорректный ввод. Попробуйте снова."
                fi
            done

            # Замена порта в файле docker-compose.yml
            sed -i "s|$original_port:|$new_port:|g" "$compose_file"
            if [ "$original_port" -eq 8545 ]; then
                export INK_RPC_PORT="$new_port"
                echo "INK_RPC_PORT=$new_port" >> ~/.bashrc  # Сохранение в .bashrc для будущих сессий
            fi
            show_bold "Настройка порта завершена."
            echo ''
        done
    fi

    # Проверка и замена переменных в .env.ink-sepolia
    env_file="$ink_dir/.env.ink-sepolia"
    if [ -f "$env_file" ]; then
        show "Файл $env_file найден. Замена переменных..."
        read -p "$(echo -e "${TERRACOTTA}${BOLD}Введите URL для L1_RPC_URL ${NC}[Enter = https://ethereum-sepolia-rpc.publicnode.com]: ")" input_rpc
        L1_RPC_URL=${input_rpc:-https://ethereum-sepolia-rpc.publicnode.com}

        read -p "$(echo -e "${TERRACOTTA}${BOLD}Введите URL для L1_BEACON_URL ${NC}[Enter = https://ethereum-sepolia-beacon-api.publicnode.com]: ")" input_beacon
        L1_BEACON_URL=${input_beacon:-https://ethereum-sepolia-beacon-api.publicnode.com}

        sed -i "s|^L1_RPC_URL=.*|L1_RPC_URL=$L1_RPC_URL|" "$env_file"
        sed -i "s|^L1_BEACON_URL=.*|L1_BEACON_URL=$L1_BEACON_URL|" "$env_file"
        show_bold "Переменные успешно обновлены"
        echo ''
    else
        show_war "Ошибка: файл $env_file не найден!"
        exit 0
    fi

    # Запуск скрипта установки
    if [ -x "./setup.sh" ]; then
        show "Запускаю скрипт установки..."
        ./setup.sh
        show "Удаление архива снепшота"
        rm -f *.tar.gz
    else
        show_war "Ошибка: setup.sh не найден или не является исполняемым!"
        exit 1
    fi

    # Фикс проблемы с правами на доступ к директории
    sudo mkdir -p "$ink_dir/geth"
    sudo chown -R 1000:1000 "$ink_dir/geth"
    sudo chmod -R 755 "$ink_dir/geth"

    # Запуск Docker Compose
    show "Запуск ноды..."
    docker compose up -d || {
        show "Перезапуск Docker Compose..."
        docker compose down && docker compose up -d || {
            show_war "Ошибка при повторном запуске Docker Compose!"
            exit 1
        }
    }
    show_bold "Установка и запуск выполнены успешно!"
    echo ''
}

# Обновление узла до mainnet
update_mainnet() {
    show "Обновление узла до mainnet..."
    cd "$ink_dir" && docker compose down
    rm -rf "$ink_dir/geth/chaindata" && mkdir -p "$ink_dir/geth/chaindata"
    git stash && git pull

    show "Добавление переменных в .env..."
    cat > "$ink_dir/.env" <<EOL
# ("ink-mainnet", "ink-sepolia", etc.)
NETWORK_NAME=ink-mainnet

# ("full" or "archive"), note that "archive" is 10x bigger
NODE_TYPE=full

# Вставь сюда свои OP_NODE__RPC_ENDPOINT и OP_NODE__L1_BEACON
OP_NODE__RPC_ENDPOINT=https://ethereum-rpc.publicnode.com
OP_NODE__L1_BEACON=https://eth-beacon-chain.drpc.org/rest/

# alchemy -Alchemy, quicknode -Quicknode, erigon -Erigon, basic -Other providers
OP_NODE__RPC_TYPE=basic

# https://rpc-gel-sepolia.inkonchain.com for ink-sepolia or https://rpc-gel.inkonchain.com for ink-mainnet)
HEALTHCHECK__REFERENCE_RPC_PROVIDER=https://rpc-gel.inkonchain.com

###############################################################################
#                                ↓ OPTIONAL ↓                                 #
###############################################################################

# snap - Snap Sync (Default), full - Full Sync (For archive node)
OP_GETH__SYNCMODE=snap

# Feel free to customize your image tag if you want, uses "latest" by default
# See here for all available images: https://hub.docker.com/u/ethereumoptimism
IMAGE_TAG__DTL=
IMAGE_TAG__HEALTCHECK=
IMAGE_TAG__PROMETHEUS=
IMAGE_TAG__GRAFANA=
IMAGE_TAG__INFLUXDB=
IMAGE_TAG__OP_GETH=
IMAGE_TAG__OP_NODE=

# Exposed server ports (must be unique)
# See docker-compose.yml for default values
PORT__DTL=33391
PORT__HEALTHCHECK_METRICS=7301
PORT__PROMETHEUS=9390
PORT__GRAFANA=3301
PORT__INFLUXDB=8386
PORT__TORRENT_UI=33396
PORT__TORRENT=33398
PORT__OP_GETH_HTTP=9393
PORT__OP_GETH_WS=33394
PORT__OP_GETH_P2P=33393
PORT__OP_NODE_P2P=9303
PORT__OP_NODE_HTTP=9345
EOL

    show "Запуск Docker Compose..."
    docker compose up -d --build || {
        show_war "Ошибка при запуске Docker Compose!"
        exit 1
    }
    show_bold "Узел успешно обновлён до mainnet!"
    echo ''
}

# Удаление ноды
delete() {
    show "Остановка и удаление контейнеров"
    cd "$ink_dir" && docker compose down
    show_bold 'Удалить директорию и все данные?'
    if confirm ''; then
        cd ~ && rm -rf ~/ink
        show_bold "Успешно удалено." 
    else
        show_war "Не удалено."
    fi
}

# Меню с командами
show_menu() {
   # show_logotip
    show_name
    show_bold 'Выберите действие:'
    echo ''
    actions=(
        "1. Установить ноду"
        "2. Просмотр логов ноды"
        "3. Тестовый запрос к ноде"
        "4. Проверка контейнеров"
        "7. Вывод приватного ключа"
        "8. Обновить узел до mainnet"
        "9. Удаление ноды"
        "0. Выход"
    )
    for action in "${actions[@]}"; do
        show "$action"
    done
}

menu() {
    case $1 in
        1)  
            install_dependencies
            install_node 
            ;;
        2)  cd "$ink_dir" && docker compose logs -f --tail 20 ;;
        3)  
            : "${INK_RPC_PORT:=8525}"
            if ! command -v jq &>/dev/null; then
                show_war 'Ошибка: jq не установлен. Установите его с помощью: sudo apt install jq'
                exit 1
            fi
            if curl -s http://localhost:"$INK_RPC_PORT" &>/dev/null; then
                curl -s -d '{"id":1,"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest",false]}' \
                     -H "Content-Type: application/json" \
                     http://localhost:"$INK_RPC_PORT" | jq
            else
                show_war 'Ошибка: RPC на порту $INK_RPC_PORT недоступен. Проверьте, запущен ли узел.'
            fi ;;
        4)  
            if [ -d "$ink_dir" ]; then
                cd "$ink_dir" && docker compose ps -a
            else
                show_war 'Ошибка: директория $ink_dir не найдена.'
            fi ;;
        7)  cat "$ink_dir/var/secrets/jwt.txt" && echo "" ;;
        8)  update_mainnet ;;
        9)  delete ;;
        0)  
            echo -en "${TERRACOTTA}${BOLD}Присоединяйся к Нодатеке, будем ставить ноды вместе! ${NC}${LIGHT_BLUE}https://t.me/cryptotesemnikov/778${NC}\n"
            exit 0 ;;
        *)  show_war "Неверный выбор, попробуйте снова." ;;
    esac
}

while true; do
    show_menu
    show_bold 'Ваш выбор:'
    read choice
    menu "$choice"
done
