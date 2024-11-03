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
    echo "Обновление пакетов и установка зависимостей..."
    sudo apt-get update -y && sudo apt upgrade -y
    sudo apt-get install -y make build-essential unzip lz4 gcc git jq ncdu tmux cmake clang pkg-config \
    libssl-dev python3-pip protobuf-compiler bc curl
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
    sleep 5  # Добавляем паузу в 5 секунд
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

 #    sed -i "s|\"rpc_url\":.*|\"rpc_url\": \"https://mainnet.base.org/\",|" "$CONFIG_PATH"
    sed -i "s|\"registry_address\":.*|\"registry_address\": \"0x3B1554f346DFe5c482Bb4BA31b880c1C18412170\",|" "$CONFIG_PATH"
    sed -i "s|\"private_key\":.*|\"private_key\": \"$PRIVATE_KEY\",|" "$CONFIG_PATH"
    sed -i "s|\"sleep\":.*|\"sleep\": $SLEEP,|" "$CONFIG_PATH"
    sed -i "s|\"batch_size\":.*|\"batch_size\": $BATCH_SIZE,|" "$CONFIG_PATH"
    sed -i "/\"batch_size\":/a \ \ \"starting_sub_id\": $STARTING_SUB_ID," "$CONFIG_PATH"

    # Изменение порта в docker-compose.yaml
    sed -i 's|4000:|5000:|' "$DOCKER_COMPOSE_PATH"
    sed -i 's|8545:|4999:|' "$DOCKER_COMPOSE_PATH"

    cp "$CONFIG_PATH" "$HELLO_CONFIG_PATH"
    sed -i "s|address registry =.*|address registry = 0x3B1554f346DFe5c482Bb4BA31b880c1C18412170;|" "$DEPLOY_SCRIPT_PATH"

    sed -i "s|sender :=.*|sender := $PRIVATE_KEY|" "$MAKEFILE_PATH"
#    sed -i "s|RPC_URL :=.*|RPC_URL := https://mainnet.base.org|" "$MAKEFILE_PATH"
    sed -i "s|ritualnetwork/infernet-node:1.3.1|ritualnetwork/infernet-node:1.4.0|" "$DOCKER_COMPOSE_PATH"
    replace_rpc_url
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
        ./.foundry/bin/foundryup
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

    # Проверка наличия forge
    if [ ! -f "$HOME/.foundry/bin/forge" ]; then
        echo "forge не найден в $HOME/.foundry/bin. Пожалуйста, убедитесь, что Foundry установлен."
        return 1
    fi

    # Указываем путь к forge и продолжаем установку
    FORGE_PATH="$HOME/.foundry/bin/forge"
    echo "Используем forge из $FORGE_PATH"

    # Переход в нужный каталог
    cd /root/infernet-container-starter/projects/hello-world/contracts || exit

    # Установка зависимостей с явным указанием пути до forge
    "$FORGE_PATH" install --no-commit foundry-rs/forge-std || { 
        echo "Ошибка при установке зависимости forge-std. Устраняем...";
        rm -rf lib/forge-std && "$FORGE_PATH" install --no-commit foundry-rs/forge-std;
    }
    "$FORGE_PATH" install --no-commit ritual-net/infernet-sdk || { 
        echo "Ошибка при установке зависимости infernet-sdk. Устраняем..."; 
        rm -rf lib/infernet-sdk && "$FORGE_PATH" install --no-commit ritual-net/infernet-sdk;
    }
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

# Функция для замены RPC URL
replace_rpc_url() {
    if confirm "Заменить RPC URL?"; then
        read -p "Введите новый RPC URL (по умолчанию https://mainnet.base.org): " NEW_RPC_URL
        NEW_RPC_URL=${NEW_RPC_URL:-"https://mainnet.base.org"}  # Устанавливаем значение по умолчанию, если ввод пропущен

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
    else
        echo "Замена RPC URL отменена. Устанавливаем значение по умолчанию."
        # Если пользователь отменил, заменяем на значение по умолчанию
        DEFAULT_RPC_URL="https://mainnet.base.org"
        sed -i "s|RPC_URL :=.*|RPC_URL := $DEFAULT_RPC_URL|" "/root/infernet-container-starter/projects/hello-world/contracts/Makefile"
    fi
}


    # Если не найдено ни одного файла, выводим сообщение
    if ! $files_found; then
        echo "Не удалось найти ни одного конфигурационного файла для замены RPC URL."
        return  # Завершаем выполнение функции
    fi

    # Используем функцию перезапуска контейнеров
    restart_docker_containers
    echo "Контейнеры перезапущены с новым RPC URL."
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
    echo "9. Удаление ноды"
    echo "0. Выход"
}

# Функция для обработки выбора пользователя
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
        2)
            echo "Отображение логов ноды..."
            docker logs -f --tail 20 infernet-node
            ;;
        3)
            echo "Замена RPC URL..."
            replace_rpc_url
            restart_docker_containers
            ;;
        9)
            echo "Удаление ноды..."
            delete_node
            ;;
        0)
            echo "Выход..."
            exit 0
            ;;
        *)
            echo "Неверный выбор, попробуйте снова."
            ;;
    esac
}

while true; do
    show_menu
    read -p "Ваш выбор: " action
    handle_choice "$action"  # Используем переменную action
done
