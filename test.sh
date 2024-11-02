#!/bin/bash

# Вызов скрипта для вывода имени
bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/main/name.sh)

# Функция для установки зависимостей
install_dependencies() {
    echo "Обновление пакетов и установка зависимостей..."
    sudo apt-get update -y && sudo apt upgrade -y
    sudo apt-get install -y \
        make build-essential unzip lz4 gcc git jq ncdu tmux cmake clang pkg-config libssl-dev python3-pip protobuf-compiler bc \
        curl
}

# Функция для установки Docker и Docker Compose
install_docker() {
    echo "Установка Docker и Docker Compose..."
    bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/main/docker.sh)
}

# Функция для клонирования репозитория ноды
clone_repository() {
    echo "Клонирование репозитория infernet-container-starter..."
    git clone https://github.com/ritual-net/infernet-container-starter
    cd infernet-container-starter || exit
}

# Функция для запуска screen сессии
start_screen_session() {
    echo "Запуск screen сессии 'ritual'..."
    screen -S ritual -d -m bash -c "project=hello-world make deploy-container"
    echo "Открыто новое окно screen."
}

# Функция для настройки конфигурационных файлов
configure_files() {
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
}

# Функция для перезапуска Docker контейнеров
restart_docker_containers() {
    echo "Перезапуск Docker контейнеров..."
    docker pull ritualnetwork/hello-world-infernet
    cd /root && docker compose -f infernet-container-starter/deploy/docker-compose.yaml down
    docker compose -f infernet-container-starter/deploy/docker-compose.yaml up -d
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
    echo "Установка Foundry..."
    curl -L https://foundry.paradigm.xyz | bash
    run_foundryup
}

# Функция для установки зависимостей проекта
install_project_dependencies() {
    echo "Установка зависимостей для hello-world проекта..."
    cd /root/infernet-container-starter/projects/hello-world/contracts || exit
    forge install --no-commit foundry-rs/forge-std || { echo "Ошибка при установке зависимости forge-std. Устраняем..."; rm -rf lib/forge-std && forge install --no-commit foundry-rs/forge-std; }
    forge install --no-commit ritual-net/infernet-sdk || { echo "Ошибка при установке зависимости infernet-sdk. Устраняем..."; rm -rf lib/infernet-sdk && forge install --no-commit ritual-net/infernet-sdk; }
}

# Функция для развертывания контракта
deploy_contract() {
    confirm "Развернуть контракт?" && {
        echo "Развертывание контракта..."
        cd /root/infernet-container-starter || exit
        project=hello-world make deploy-contracts
    } || echo "Пропущено развертывание контракта."
}

call_contract() {
    read -p "Введите Contract Address: " CONTRACT_ADDRESS
    echo "Заменяем старый номер в CallsContract.s.sol..."
    sed -i "s|SaysGM(.*)|SaysGM($CONTRACT_ADDRESS)|" ~/infernet-container-starter/projects/hello-world/contracts/script/CallContract.s.sol
    echo "Выполняем команду project=hello-world make call-contract..."
    project=hello-world make call-contract
}


# Функция для замены RPC URL
replace_rpc_url() {
    read -p "Введите новый RPC URL: " NEW_RPC_URL

    CONFIG_PATHS=(
        "/root/infernet-container-starter/projects/hello-world/container/config.json"
        "/root/infernet-container-starter/deploy/config.json"
        "/root/infernet-container-starter/projects/hello-world/contracts/Makefile"
    )

    # Переменная для отслеживания найденных файлов
    files_found=false

    for config_path in "${CONFIG_PATHS[@]}"; do
        if [[ -f "$config_path" ]]; then
            sed -i "s|https://mainnet.base.org|$NEW_RPC_URL|g" "$config_path"
            echo "RPC URL заменен в $config_path"
            files_found=true  # Устанавливаем флаг, если файл найден
        else
            echo "Файл $config_path не найден, пропускаем."
        fi
    done

    # Если не найдено ни одного файла, выводим сообщение
    if ! $files_found; then
        echo "Не удалось найти ни одного конфигурационного файла для замены RPC URL."
        return  # Завершаем выполнение функции
    fi

    # Используем функцию перезапуска контейнеров
    restart_docker_containers
    echo "Контейнеры перезапущены после замены RPC URL."
}

# Функция для удаления ноды
delete_node() {
    if confirm "Удалить ноду и очистить файлы?"; then
        echo "Удаление ноды и очистка файлов..."
        cd /root && docker compose -f infernet-container-starter/deploy/docker-compose.yaml down
        cd && rm -rf infernet-container-starter
        echo "Нода удалена и файлы очищены."
    else
        echo "Удаление ноды отменено."
    fi
}

# Функция для отображения меню
show_menu() {
    echo ""
    echo "Выберите действие:"
    echo "1. Установка ноды"
    echo "2. Логи ноды"
    echo "3. Замена RPC"
    echo "4. Удалить ноду"
    echo "5. Перезапуск ноды"
    echo "6. Выход"
}

# Основной цикл
while true; do
    show_menu
    read -p "Ваш выбор: " choice
    case $choice in
        1)
            install_dependencies
            install_docker
            clone_repository
            configure_files
            start_screen_session
            install_foundry
            install_project_dependencies
            deploy_contract
            ;;
        2)
            echo "Логи ноды:"
            docker logs $(docker ps -q --filter "ancestor=ritualnetwork/hello-world-infernet")
            ;;
        3)
            replace_rpc_url
            ;;
        4)
            delete_node
            ;;
        5)
            restart_docker_containers
            ;;
        6)
            echo "Выход..."
            exit 0
            ;;
        *)
            echo "Неверный выбор, попробуйте снова."
            ;;
    esac
done
