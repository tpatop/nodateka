#!/bin/bash

# Переменные для путей
CONFIG_PATH="/root/infernet-container-starter/deploy/config.json"
HELLO_CONFIG_PATH="/root/infernet-container-starter/projects/hello-world/container/config.json"
DEPLOY_SCRIPT_PATH="/root/infernet-container-starter/projects/hello-world/contracts/script/Deploy.s.sol"
MAKEFILE_PATH="/root/infernet-container-starter/projects/hello-world/contracts/Makefile"
DOCKER_COMPOSE_PATH="/root/infernet-container-starter/deploy/docker-compose.yaml"
FORGE_PATH="$HOME/.foundry/bin/forge"

# Вызов скрипта для вывода имени
bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/main/name.sh)

# Функция подтверждения
confirm() {
    read -p "$1 (Enter для продолжения или n для пропуска): " choice
    [[ -z "$choice" || "$choice" == "y" ]]
}

# Установка зависимостей
install_dependencies() {
    echo "Обновление пакетов и установка зависимостей..."
    sudo apt-get update -y && sudo apt upgrade -y
    sudo apt-get install -y make build-essential unzip lz4 gcc git jq ncdu tmux cmake clang pkg-config \
    libssl-dev python3-pip protobuf-compiler bc curl
}

install_docker() {
    echo "Установка Docker и Docker Compose..."
    bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/main/docker.sh)
}

clone_repository() {
    echo "Клонирование репозитория infernet-container-starter..."
    git clone https://github.com/ritual-net/infernet-container-starter || { echo "Ошибка клонирования"; exit 1; }
    cd infernet-container-starter || exit
    # Изменение порта в docker-compose.yaml
    sed -i 's|4000:|5000:|' "$DOCKER_COMPOSE_PATH"
    sed -i 's|8545:|4999:|' "$DOCKER_COMPOSE_PATH"
}

# Запуск screen сессии
start_screen_session() {
    echo "Запуск screen сессии 'ritual'..."
    screen -S ritual -d -m bash -c "project=hello-world make deploy-container"
    echo "Открыто новое окно screen."
    sleep 5
}

# Настройка конфигурационных файлов
configure_files() {
    echo "Настройка файлов конфигурации..."
    read -p "Введите ваш private_key: " PRIVATE_KEY
    read -p "Введите значение sleep (по умолчанию 3): " SLEEP
    SLEEP=${SLEEP:-3}
    read -p "Введите значение batch_size (по умолчанию 1800): " BATCH_SIZE
    BATCH_SIZE=${BATCH_SIZE:-1800}
    read -p "Введите значение starting_sub_id (по умолчанию 170000): " STARTING_SUB_ID
    STARTING_SUB_ID=${STARTING_SUB_ID:-170000}

    sed -i "s|\"registry_address\":.*|\"registry_address\": \"0x3B1554f346DFe5c482Bb4BA31b880c1C18412170\",|" "$CONFIG_PATH"
    sed -i "s|\"private_key\":.*|\"private_key\": \"$PRIVATE_KEY\",|" "$CONFIG_PATH"
    sed -i "s|\"sleep\":.*|\"sleep\": $SLEEP,|" "$CONFIG_PATH"
    sed -i "s|\"batch_size\":.*|\"batch_size\": $BATCH_SIZE,|" "$CONFIG_PATH"
    sed -i "/\"batch_size\":/a \ \ \"starting_sub_id\": $STARTING_SUB_ID" "$CONFIG_PATH"
    cp "$CONFIG_PATH" "$HELLO_CONFIG_PATH"

    sed -i "s|address registry =.*|address registry = 0x3B1554f346DFe5c482Bb4BA31b880c1C18412170;|" "$DEPLOY_SCRIPT_PATH"
    sed -i "s|sender :=.*|sender := $PRIVATE_KEY|" "$MAKEFILE_PATH"
    sed -i "s|ritualnetwork/infernet-node:1.3.1|ritualnetwork/infernet-node:1.4.0|" "$DOCKER_COMPOSE_PATH"

    replace_rpc_url
}

restart_docker_containers() {
    echo "Перезапуск Docker контейнеров..."
    docker pull ritualnetwork/hello-world-infernet
    docker compose -f "$DOCKER_COMPOSE_PATH" down
    docker compose -f "$DOCKER_COMPOSE_PATH" up -d
}

install_foundry() {
    echo "Установка Foundry..."
    curl -L https://foundry.paradigm.xyz | bash
    source ~/.bashrc
    "$FORGE_PATH" || echo "Foundry не найден."
}

install_project_dependencies() {
    echo "Установка зависимостей для hello-world проекта..."
    if [ ! -f "$FORGE_PATH" ]; then
        echo "forge не найден в $FORGE_PATH. Убедитесь, что Foundry установлен."
        return 1
    fi
    cd /root/infernet-container-starter/projects/hello-world/contracts || exit
    "$FORGE_PATH" install --no-commit foundry-rs/forge-std || rm -rf lib/forge-std && "$FORGE_PATH" install --no-commit foundry-rs/forge-std
    "$FORGE_PATH" install --no-commit ritual-net/infernet-sdk || rm -rf lib/infernet-sdk && "$FORGE_PATH" install --no-commit ritual-net/infernet-sdk
}

# Функция для развертывания контракта
deploy_contract() {
    if confirm "Развернуть контракт?"; then
        echo "Развертывание контракта..."
        cd /root/infernet-container-starter || exit
        project=hello-world make deploy-contracts
    else
        echo "Пропущено развертывание контракта."
    fi
}
# Запрос
call_contract() {
    if confirm "Вызвать новый запрос?"; then
        read -p "Введите Contract Address: " CONTRACT_ADDRESS
        echo "Заменяем старый номер в CallsContract.s.sol..."
        sed -i "s|SaysGM(.*)|SaysGM($CONTRACT_ADDRESS)|" ~/infernet-container-starter/projects/hello-world/contracts/script/CallContract.s.sol
        echo "Выполняем команду project=hello-world make call-contract..."
        project=hello-world make call-contract
    else
        echo "Пропущен вызов запроса."
    fi
}

replace_rpc_url() {
    if confirm "Заменить RPC URL?"; then
        read -p "Введите новый RPC URL (по умолчанию https://mainnet.base.org): " NEW_RPC_URL
        NEW_RPC_URL=${NEW_RPC_URL:-"https://mainnet.base.org"}
        CONFIG_PATHS=("$HELLO_CONFIG_PATH" "$CONFIG_PATH" "$MAKEFILE_PATH")
        for config_path in "${CONFIG_PATHS[@]}"; do
            [[ -f "$config_path" ]] && sed -i "s|https://mainnet.base.org|$NEW_RPC_URL|g" "$config_path" && echo "Заменен RPC URL в $config_path"
        done
        restart_docker_containers
    fi
}

delete_node() {
    if confirm "Удалить ноду и очистить файлы?"; then
        echo "Удаление ноды..."
        docker compose -f "$DOCKER_COMPOSE_PATH" down
        rm -rf /root/infernet-container-starter
    fi
}

show_menu() {
    echo ""
    echo "1. Установка ноды"
    echo "2. Логи ноды"
    echo "3. Замена RPC"
    echo "9. Удаление ноды"
    echo "0. Выход"
}

handle_choice() {
    case "$1" in
        1)
            echo "Запущена установка ноды..."
            install_dependencies
            install_docker
            clone_repository
            start_screen_session
            configure_files
            restart_docker_containers
            install_foundry
            install_project_dependencies
            deploy_contract
            call_contract
            ;;
        2) docker logs -f --tail 20 infernet-node ;;
        3) replace_rpc_url ;;
        9) delete_node ;;
        0) exit 0 ;;
        *) echo "Неверный выбор" ;;
    esac
}

while true; do
    show_menu
    read -p "Ваш выбор: " action
    handle_choice "$action"
done
