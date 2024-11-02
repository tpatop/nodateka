#!/bin/bash

# Вызов скрипта для вывода имени
bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/main/name.sh)

# Функция для установки зависимостей
install_dependencies() {
    if confirm "Установить необходимые зависимости?"; then
        echo "Обновление пакетов и установка зависимостей..."
        sudo apt-get update -y && sudo apt upgrade -y
        sudo apt-get install -y \
            make build-essential unzip lz4 gcc git jq ncdu tmux cmake clang pkg-config libssl-dev python3-pip protobuf-compiler bc \
            curl
    else
        echo "Пропущена установка зависимостей."
    fi
}

# Функция для запроса подтверждения
confirm() {
    local prompt="$1"
    read -p "$prompt (нажмите Enter для продолжения или n для пропуска): " choice
    if [[ -z "$choice" || "$choice" == "y" ]]; then
        return 0  # Выполнить действие
    else
        return 1  # Пропустить действие
    fi
}

# Функция для установки Docker и Docker Compose
install_docker() {
    if confirm "Установить Docker и Docker Compose?"; then
        echo "Установка Docker и Docker Compose..."
        bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/main/docker.sh)
    else
        echo "Пропущена установка Docker и Docker Compose."
    fi
}

# Функция для клонирования репозитория ноды
clone_repository() {
    if confirm "Клонировать репозиторий infernet-container-starter?"; then
        echo "Клонирование репозитория infernet-container-starter..."
        git clone https://github.com/ritual-net/infernet-container-starter
        cd infernet-container-starter || exit
    else
        echo "Пропущено клонирование репозитория."
    fi
}

# Функция для запуска screen сессии
start_screen_session() {
    if confirm "Запустить screen сессию 'ritual'?"; then
        echo "Запуск screen сессии 'ritual'..."
        screen -S ritual -d -m bash -c "project=hello-world make deploy-container"
        echo "Открыто новое окно screen."
    else
        echo "Пропущен запуск screen сессии."
    fi
}

# Функция для настройки конфигурационных файлов
configure_files() {
    if confirm "Настроить файлы конфигурации?"; then
        echo "Настройка файлов конфигурации..."
        CONFIG_PATH="~/infernet-container-starter/deploy/config.json"
        HELLO_CONFIG_PATH="~/infernet-container-starter/projects/hello-world/container/config.json"
        DEPLOY_SCRIPT_PATH="~/infernet-container-starter/projects/hello-world/contracts/script/Deploy.s.sol"
        MAKEFILE_PATH="~/infernet-container-starter/projects/hello-world/contracts/Makefile"
        DOCKER_COMPOSE_PATH="~/infernet-container-starter/deploy/docker-compose.yaml"

        sed -i 's|\"rpc_url\":.*|\"rpc_url\": \"https://mainnet.base.org/\",|' "$CONFIG_PATH"
        sed -i 's|\"registry_address\":.*|\"registry_address\": \"0x3B1554f346DFe5c482Bb4BA31b880c1C18412170\",|' "$CONFIG_PATH"
        sed -i 's|\"private_key\":.*|\"private_key\": \"<YOUR_PRIVATE_KEY>\",|' "$CONFIG_PATH"
        sed -i 's|\"sleep\":.*|\"sleep\": 3,|' "$CONFIG_PATH"
        sed -i 's|\"batch_size\":.*|\"batch_size\": 1800,|' "$CONFIG_PATH"
        sed -i '/\"batch_size\":/a \ \ \"starting_sub_id\": 170000' "$CONFIG_PATH"

        cp "$CONFIG_PATH" "$HELLO_CONFIG_PATH"
        sed -i 's|address registry =.*|address registry = 0x3B1554f346DFe5c482Bb4BA31b880c1C18412170;|' "$DEPLOY_SCRIPT_PATH"

        sed -i 's|sender :=.*|sender := <YOUR_PRIVATE_KEY>|' "$MAKEFILE_PATH"
        sed -i 's|RPC_URL :=.*|RPC_URL := https://mainnet.base.org|' "$MAKEFILE_PATH"

        sed -i 's|ritualnetwork/infernet-node:1.3.1|ritualnetwork/infernet-node:1.4.0|' "$DOCKER_COMPOSE_PATH"
    else
        echo "Пропущена настройка файлов конфигурации."
    fi
}

# Функция для перезапуска Docker контейнеров
restart_docker_containers() {
    if confirm "Перезапустить Docker контейнеры?"; then
        echo "Перезапуск Docker контейнеров..."
        docker pull ritualnetwork/hello-world-infernet
        cd /root && docker compose -f infernet-container-starter/deploy/docker-compose.yaml down
        docker compose -f infernet-container-starter/deploy/docker-compose.yaml up -d
    else
        echo "Пропущен перезапуск Docker контейнеров."
    fi
}

# Функция для установки Foundry
install_foundry() {
    if confirm "Установить Foundry?"; then
        echo "Установка Foundry..."
        mkdir ~/foundry && cd ~/foundry || exit
        curl -L https://foundry.paradigm.xyz | bash
        source ~/.bashrc
        foundryup
    else
        echo "Пропущена установка Foundry."
    fi
}

# Функция для установки зависимостей проекта
install_project_dependencies() {
    if confirm "Установить зависимости для hello-world проекта?"; then
        echo "Установка зависимостей для hello-world проекта..."
        cd ~/infernet-container-starter/projects/hello-world/contracts || exit
        forge install --no-commit foundry-rs/forge-std || { echo "Ошибка при установке зависимости forge-std. Устраняем..."; rm -rf lib/forge-std && forge install --no-commit foundry-rs/forge-std; }
        forge install --no-commit ritual-net/infernet-sdk || { echo "Ошибка при установке зависимости infernet-sdk. Устраняем..."; rm -rf lib/infernet-sdk && forge install --no-commit ritual-net/infernet-sdk; }
    else
        echo "Пропущена установка зависимостей."
    fi
}

# Функция для развертывания контракта
deploy_contract() {
    if confirm "Развернуть контракт?"; then
        echo "Развертывание контракта..."
        cd ~/infernet-container-starter || exit
        project=hello-world make deploy-contracts
    else
        echo "Пропущено развертывание контракта."
    fi
}

# Основной скрипт
main() {
    install_dependencies
    install_docker
    clone_repository
    start_screen_session
    configure_files
    restart_docker_containers
    install_foundry
    install_project_dependencies
    deploy_contract
    echo "Скрипт завершен. Проверьте вывод выше для подтверждения успешного развертывания."
}

# Запуск основного скрипта
main
