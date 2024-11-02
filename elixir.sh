#!/bin/bash

# Вызов скрипта для вывода имени
bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/main/name.sh)

# Функция для отображения меню
show_menu() {
    echo ""
    echo "Выберите действие:"
    echo "1. Установить узел (настройка)"
    echo "2. Запуск узла в Mainnet"
    echo "3. Запуск узла в Testnet"
    echo "4. Обновить узлы"
    echo "5. Мониторинг работы узла (Mainnet)"
    echo "6. Мониторинг работы узла (Testnet)"
    echo "0. Выход"
    read -p "Ваш выбор: " action
}

# Функция для установки узла
install_node() {
    echo "Устанавливаем узел..."

    # Вызов скрипта для проверки и установки Docker и Docker Compose
    bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/main/docker.sh)

    # Создание каталога и загрузка файла конфигурации
    mkdir ~/elixir && cd ~/elixir
    wget https://files.elixir.finance/validator.env

    # Запрос данных для заполнения переменных
    read -p "Введите STRATEGY_EXECUTOR_DISPLAY_NAME: " STRATEGY_EXECUTOR_DISPLAY_NAME
    read -p "Введите STRATEGY_EXECUTOR_BENEFICIARY: " STRATEGY_EXECUTOR_BENEFICIARY
    read -p "Введите SIGNER_PRIVATE_KEY: " SIGNER_PRIVATE_KEY

    # Замена значений в validator.env
    sed -i "s/^STRATEGY_EXECUTOR_DISPLAY_NAME=.*/STRATEGY_EXECUTOR_DISPLAY_NAME=$STRATEGY_EXECUTOR_DISPLAY_NAME/" validator.env
    sed -i "s/^STRATEGY_EXECUTOR_BENEFICIARY=.*/STRATEGY_EXECUTOR_BENEFICIARY=$STRATEGY_EXECUTOR_BENEFICIARY/" validator.env
    sed -i "s/^SIGNER_PRIVATE_KEY=.*/SIGNER_PRIVATE_KEY=$SIGNER_PRIVATE_KEY/" validator.env

    # Скачивание образа
    docker pull elixirprotocol/validator:v3

    echo "Настройка завершена, дальше запустите узел в выбранной сети"
}

# Функция для обновления узла
update_node() {
    echo "Обновляем узел..."

    # Проверка, в какой сети запущен узел и обновление соответствующего контейнера
    if docker ps --format '{{.Names}}' | grep -q "elixir-mainnet"; then
        # Обновление Mainnet узла
        echo "Обновляем узел в Mainnet..."
        docker rm -f elixir-mainnet
        docker pull elixirprotocol/validator:v3
        docker run -d --env-file ~/elixir/validator.env --name elixir-mainnet --platform linux/amd64 -p 17690:17690 --restart unless-stopped elixirprotocol/validator:v3
    fi

    if docker ps --format '{{.Names}}' | grep -q "elixir-testnet"; then
        # Обновление Testnet узла
        echo "Обновляем узел в Testnet..."
        docker rm -f elixir-testnet
        docker pull elixirprotocol/validator:v3
        docker run -d --env-file ~/elixir/testnet.env --name elixir-testnet --platform linux/amd64 -p 17691:17690 --restart unless-stopped elixirprotocol/validator:v3
    fi
}
# Функция для мониторинга работы узла в Mainnet
monitor_mainnet_node() {
    echo "Мониторинг работы узла в Mainnet..."
    docker logs -f --tail 100 elixir-mainnet
}

# Функция для мониторинга работы узла в Testnet
monitor_testnet_node() {
    echo "Мониторинг работы узла в Testnet..."
    docker logs -f --tail 100 elixir-testnet
}

# Функция для запуска узла в Mainnet
start_mainnet() {
    echo "Запуск узла в Mainnet..."
    sed -i 's/^ENV=.*/ENV=prod/' "/root/elixir/validator.env"
    # Проверка и удаление старого контейнера с именем "elixir" или "elixir-mainnet"
    if docker ps -a --format '{{.Names}}' | grep -q "^elixir$"; then
        echo "Найден старый контейнер 'elixir'. Удаление..."
        docker rm -f elixir
    fi

    if docker ps -a --format '{{.Names}}' | grep -q "^elixir-mainnet$"; then
        echo "Найден старый контейнер 'elixir-mainnet'. Удаление..."
        docker rm -f elixir-mainnet
    fi
    docker pull elixirprotocol/validator:v3
    docker run -d --env-file ~/elixir/validator.env --name elixir-mainnet --platform linux/amd64 -p 17690:17690 --restart unless-stopped elixirprotocol/validator:v3
}

# Функция для запуска узла в Testnet
start_testnet() {
    echo "Запуск узла в Testnet..."
    cp ~/elixir/validator.env ~/elixir/testnet.env
    sed -i 's/^ENV=.*/ENV=testnet-3/' "/root/elixir/testnet.env"
    # Проверка и удаление старого контейнера с именем "elixir" или "elixir-testnet"
    if docker ps -a --format '{{.Names}}' | grep -q "^elixir$"; then
        echo "Найден старый контейнер 'elixir'. Удаление..."
        docker rm -f elixir
    fi

    if docker ps -a --format '{{.Names}}' | grep -q "^elixir-testnet$"; then
        echo "Найден старый контейнер 'elixir-testnet'. Удаление..."
        docker rm -f elixir-testnet
    fi
    docker pull elixirprotocol/validator:v3
    docker run -d --env-file ~/elixir/testnet.env --name elixir-testnet --platform linux/amd64 -p 17691:17690 --restart unless-stopped elixirprotocol/validator:v3
}

# Основной цикл для работы меню
while true; do
    show_menu

    case "$action" in
        1)
            install_node
            ;;
        
        2)
            start_mainnet
            ;;
        
        3)
            start_testnet
            ;;
        
        4)
            update_node
            ;;
        
        5)
            monitor_mainnet_node
            ;;
        
        6)
            monitor_testnet_node
            ;;
        
        0)
            echo "Завершение работы."
            exit 0
            ;;
        
        *)
            echo "Неверный выбор. Пожалуйста, попробуйте снова."
            ;;

    esac
done
