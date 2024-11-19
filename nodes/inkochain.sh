#!/bin/bash

# Логотип команды
show_logotip() {
    bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/name.sh)
}

# Функция для подтверждения действия
confirm() {
    local prompt="$1"
    read -p "$prompt [y/n]: " choice
    if [[ -z "$choice" || "$choice" == "y" ]]; then
        return 0  # Выполнить действие
    else
        return 1  # Пропустить действие
    fi
}

ink_dir="$HOME/node"

# Функция для установки зависимостей
install_dependencies() {
    if confirm "Установить необходимые пакеты и зависимости?"; then
        bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/admin/docker.sh)
        sudo apt install jq net-tools
    else
        echo "Отменено."
    fi
}

clone_rep() {
    echo "Клонирование репозитория Ink node..."
    git clone https://github.com/inkonchain/node.git "$ink_dir" || {
        echo "Ошибка при клонировании репозитория!"
        exit 1
    }
}

# Функция установки ноды
install_node() {
    if confirm "Скачать репозиторий узла?"; then
        clone_rep
    else 
        echo "Пропущено"
    fi

    echo "Переход в директорию узла..."
    cd "$ink_dir" || {
        echo "Ошибка: директория node не найдена!"
        exit 1
    }

    # Массив с необходимыми портами
    required_ports=("8525" "8526" "30313" "7301" "9535" "9232" "7300" "6060")

    # Проверка доступности портов
    for port in "${required_ports[@]}"; do
        if ss -tuln | grep -q ":$port "; then
            echo "Порт $port: ЗАНЯТ"
            exit 1
        else
            echo "Порт $port: СВОБОДЕН"
        fi
    done

    # Проверка и замена переменных в .env.ink-sepolia
    env_file="$ink_dir/.env.ink-sepolia"
    if [ -f "$env_file" ]; then
        echo "Файл $env_file найден. Замена переменных..."
        read -p "Введите URL для OP_NODE_L1_ETH_RPC [https://ethereum-sepolia-rpc.publicnode.com]: " input_rpc
        OP_NODE_L1_ETH_RPC=${input_rpc:-https://ethereum-sepolia-rpc.publicnode.com}

        read -p "Введите URL для OP_NODE_L1_BEACON [https://ethereum-sepolia-beacon-api.publicnode.com]: " input_beacon
        OP_NODE_L1_BEACON=${input_beacon:-https://ethereum-sepolia-beacon-api.publicnode.com}

        sed -i "s|^OP_NODE_L1_ETH_RPC=.*|OP_NODE_L1_ETH_RPC=$OP_NODE_L1_ETH_RPC|" "$env_file"
        sed -i "s|^OP_NODE_L1_BEACON=.*|OP_NODE_L1_BEACON=$OP_NODE_L1_BEACON|" "$env_file"
        echo "Переменные успешно обновлены"
    else
        echo "Ошибка: файл $env_file не найден!"
        exit 1
    fi

    # Проверка и замена портов в docker-compose.yml
    compose_file="$ink_dir/docker-compose.yml"
    if [ -f "$compose_file" ]; then
        echo "Файл $compose_file найден. Замена портов..."
        sed -i 's|8545:|8525:|g' "$compose_file"
        sed -i 's|8546:|8526:|g' "$compose_file"
        sed -i 's|30303:|30313:|g' "$compose_file"
        sed -i 's|9545:|9535:|g' "$compose_file"
        sed -i 's|9222:|9232:|g' "$compose_file"
        echo "Порты успешно заменены."
    else
        echo "Ошибка: файл $compose_file не найден!"
        exit 1
    fi

    # Запуск скрипта установки
    if [ -x "./setup.sh" ]; then
        echo "Запускаю скрипт установки..."
        ./setup.sh
    else
        echo "Ошибка: setup.sh не найден или не является исполняемым!"
        exit 1
    fi

    # Фикс проблемы с правами на доступ к директории
    sudo chown -R 1000:1000 "$ink_dir/geth"
    sudo chmod -R 755 "$ink_dir/geth"

    # Запуск Docker Compose
    echo "Запуск ноды..."
    docker compose up -d || {
        echo "Перезапуск Docker Compose..."
        docker compose down && docker compose up -d || {
            echo "Ошибка при повторном запуске Docker Compose!"
            exit 1
        }
    }
    echo "Установка и запуск выполнены успешно!"
}

# Удаление ноды
delete() {
    echo "Остановка и удаление контейнеров"
    cd "$ink_dir" && docker compose down 
    if confirm "Удалить директорию и все данные?"; then
        cd ~ && rm -rf "$ink_dir"
    else
        echo "Не удалено."
    fi
}

# Меню с командами
show_menu() {
    show_logotip
    echo "Выберите действие:"
    echo "1. Установить ноду"
    echo "2. Тестовый запрос к ноде"
    echo "3. Вывод приватного ключа"
    echo "4. Просмотр логов ноды"
    echo "5. Удаление ноды"
    echo "0. Выход"
}

menu() {
    case $1 in
        1)  
            install_dependencies
            install_node 
            ;;
        2)  curl -d '{"id":1,"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest",false]}' -H "Content-Type: application/json" http://localhost:8525 | jq ;;
        3)  cat "$ink_dir/var/secrets/jwt.txt" && echo "" ;;
        4)  cd "$ink_dir" && docker compose logs -f --tail 20 ;;
        5)  delete ;;
        0)  exit 0 ;;
        *)  echo "Неверный выбор, попробуйте снова." ;;
    esac
}

while true; do
    show_menu
    read -p "Ваш выбор: " choice
    menu "$choice"
done
