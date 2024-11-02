#!/bin/bash

# Вызов скрипта для вывода имени
bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/main/name.sh)

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

        # Параметры с пользовательским вводом
        read -p "Введите ваш private_key: " PRIVATE_KEY
        read -p "Введите значение sleep (по умолчанию 3): " SLEEP
        SLEEP=${SLEEP:-3}  # Устанавливаем значение по умолчанию
        read -p "Введите значение batch_size (по умолчанию 1800): " BATCH_SIZE
        BATCH_SIZE=${BATCH_SIZE:-1800}  # Устанавливаем значение по умолчанию
        read -p "Введите значение starting_sub_id (по умолчанию 170000): " STARTING_SUB_ID
        STARTING_SUB_ID=${STARTING_SUB_ID:-170000}  # Устанавливаем значение по умолчанию

        CONFIG_PATH="/root/infernet-container-starter/deploy/config.json"
        HELLO_CONFIG_PATH="/root/infernet-container-starter/projects/hello-world/container/config.json"
        DEPLOY_SCRIPT_PATH="/root/infernet-container-starter/projects/hello-world/contracts/script/Deploy.s.sol"
        MAKEFILE_PATH="/root/infernet-container-starter/projects/hello-world/contracts/Makefile"
        DOCKER_COMPOSE_PATH="/root/infernet-container-starter/deploy/docker-compose.yaml"

        sed -i "s|\"rpc_url\":.*|\"rpc_url\": \"https://mainnet.base.org/\",|" "$CONFIG_PATH"
        sed -i "s|\"registry_address\":.*|\"registry_address\": \"0x3B1554f346DFe5c482Bb4BA31b880c1C18412170\",|" "$CONFIG_PATH"
        sed -i "s|\"private_key\":.*|\"private_key\": \"$PRIVATE_KEY\",|" "$CONFIG_PATH"
        sed -i "s|\"sleep\":.*|\"sleep\": $SLEEP,|" "$CONFIG_PATH"
        sed -i "s|\"batch_size\":.*|\"batch_size\": $BATCH_SIZE,|" "$CONFIG_PATH"
        sed -i "/\"batch_size\":/a \ \ \"starting_sub_id\": $STARTING_SUB_ID" "$CONFIG_PATH"

        # Изменение порта в docker-compose.yaml
        sed -i 's|4000:|5000:|' "$DOCKER_COMPOSE_PATH"

        cp "$CONFIG_PATH" "$HELLO_CONFIG_PATH"
        sed -i "s|address registry =.*|address registry = 0x3B1554f346DFe5c482Bb4BA31b880c1C18412170;|" "$DEPLOY_SCRIPT_PATH"

        sed -i "s|sender :=.*|sender := $PRIVATE_KEY|" "$MAKEFILE_PATH"
        sed -i "s|RPC_URL :=.*|RPC_URL := https://mainnet.base.org|" "$MAKEFILE_PATH"

        sed -i "s|ritualnetwork/infernet-node:1.3.1|ritualnetwork/infernet-node:1.4.0|" "$DOCKER_COMPOSE_PATH"
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

# Функция для проверки и выполнения foundryup
run_foundryup() {
    # Проверяем, добавлен ли путь до Foundry в .bashrc
    if grep -q 'foundry' ~/.bashrc; then
        source ~/.bashrc
        echo "Запускаем foundryup..."
        foundryup
    else
        echo "Путь до foundryup не найден в .bashrc."
        echo "Пожалуйста, выполните 'source ~/.bashrc' вручную или перезапустите терминал."
    fi
}

# Функция для установки Foundry
install_foundry() {
    if confirm "Установить Foundry?"; then
        echo "Установка Foundry..."
        curl -L https://foundry.paradigm.xyz | bash
        run_foundryup
    else
        echo "Пропущена установка Foundry."
    fi
}


# Функция для установки зависимостей проекта
install_project_dependencies() {
    if confirm "Установить зависимости для hello-world проекта?"; then
        echo "Установка зависимостей для hello-world проекта..."
        cd /root/infernet-container-starter/projects/hello-world/contracts || exit
        forge install --no-commit foundry-rs/forge-std || { echo "Ошибка при установке зависимости forge-std. Устраняем..."; rm -rf lib/forge-std && forge install --no-commit foundry-rs/forge-std; }
        forge install --no-commit ritual-net/infernet-sdk || { echo "Ошибка при установке зависимости infernet-sdk. Устраняем..."; rm -rf lib/infernet-sdk && forge install --no-commit ritual-net/infernet-sdk; }
    else
        echo "Пропущена установка зависимостей."
    fi
}

# Функция для замены адреса контракта
replace_contract_address() {
    if confirm "Вставить Contract Address из предыдущего шага?"; then
        read -p "Введите Contract Address: " CONTRACT_ADDRESS
        echo "Заменяем старый номер в CallsContract.s.sol..."
        sed -i "s|SaysGM(.*)|SaysGM($CONTRACT_ADDRESS)|" ~/infernet-container-starter/projects/hello-world/contracts/script/CallContract.s.sol
        echo "Выполняем команду project=hello-world make call-contract..."
        project=hello-world make call-contract
    else
        echo "Пропущена вставка Contract Address."
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
    replace_contract_address  # Вызов функции для замены адреса контракта
    echo "Скрипт завершен. Проверьте вывод выше для подтверждения успешного развертывания."
}

# Запуск основного скрипта
main
