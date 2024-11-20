#!/bin/bash

# Логотип команды
show_logotip() {
    bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/name.sh)
}

# Вывод названия узла
show_name() {
    echo ""
    echo "INK chain node"
    echo ""
}

# Функция для подтверждения действия
confirm() {
    local prompt="$1"
    read -p "$prompt [y/n, Enter = yes]: " choice
    case "$choice" in
        ""|y|Y|yes|Yes)  # Пустой ввод или "да"
            return 0  # Подтверждение действия
            ;;
        n|N|no|No)  # Любой вариант "нет"
            return 1  # Отказ от действия
            ;;
        *)
            echo "Пожалуйста, введите y или n."
            confirm "$prompt"  # Повторный запрос, если ответ не распознан
            ;;
    esac
}

ink_dir="$HOME/ink/node"

# Функция для установки зависимостей
install_dependencies() {
    bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/admin/docker.sh)
    sudo apt install jq net-tools -y
}

clone_rep() {
    echo "Клонирование репозитория Ink node..."
    if [ -d "$ink_dir" ]; then
        echo "Репозиторий уже скачан. Пропуск клонирования."
    else
        git clone https://github.com/inkonchain/node.git "$ink_dir" || {
            echo "Ошибка: не удалось клонировать репозиторий."
            exit 1
        }
    fi
}

# Функция установки ноды
install_node() {
    mkdir -p ~/ink && cd ~/ink
    clone_rep

    echo "Переход в директорию узла..."
    cd "$ink_dir" || {
        echo "Ошибка: директория node не найдена!"
    }

    # Проверка и замена портов в docker-compose.yml
    compose_file="$ink_dir/docker-compose.yml"
    if [ -f "$compose_file" ]; then
        echo "Файл $compose_file найден. Проверка и настройка портов..."

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
            echo "Проверка порта $new_port..."

            # Если порт занят, запрос нового значения
            while ss -tuln | grep -q ":$new_port "; do
                echo "Порт $new_port занят."
                read -p "Введите новый порт для замены $original_port (текущий: $new_port): " user_port
                if [[ $user_port =~ ^[0-9]+$ && $user_port -ge 1 && $user_port -le 65535 ]]; then
                    if ss -tuln | grep -q ":$user_port "; then
                        echo "Ошибка: введённый порт $user_port тоже занят. Попробуйте снова."
                    else
                        new_port=$user_port
                        break  # Выход из цикла, если порт свободен
                    fi
                else
                    echo "Некорректный ввод. Попробуйте снова."
                fi
            done

            # Замена порта в файле docker-compose.yml
            sed -i "s|$original_port:|$new_port:|g" "$compose_file"
            if [ "$original_port" -eq 8545 ]; then
                export INK_RPC_PORT="$new_port"
                echo "INK_RPC_PORT=$new_port" >> ~/.bashrc  # Сохранение в .bashrc для будущих сессий
            fi
            echo "Настройка порта завершена."
        done
    fi

    # Проверка и замена переменных в .env.ink-sepolia
    env_file="$ink_dir/.env.ink-sepolia"
    if [ -f "$env_file" ]; then
        echo "Файл $env_file найден. Замена переменных..."
        read -p "Введите URL для OP_NODE_L1_ETH_RPC [Enter = https://ethereum-sepolia-rpc.publicnode.com]: " input_rpc
        OP_NODE_L1_ETH_RPC=${input_rpc:-https://ethereum-sepolia-rpc.publicnode.com}

        read -p "Введите URL для OP_NODE_L1_BEACON [Enter = https://ethereum-sepolia-beacon-api.publicnode.com]: " input_beacon
        OP_NODE_L1_BEACON=${input_beacon:-https://ethereum-sepolia-beacon-api.publicnode.com}

        sed -i "s|^OP_NODE_L1_ETH_RPC=.*|OP_NODE_L1_ETH_RPC=$OP_NODE_L1_ETH_RPC|" "$env_file"
        sed -i "s|^OP_NODE_L1_BEACON=.*|OP_NODE_L1_BEACON=$OP_NODE_L1_BEACON|" "$env_file"
        echo "Переменные успешно обновлены"
    else
        echo "Ошибка: файл $env_file не найден!"
        exit 0
    fi

    # Запуск скрипта установки
    if [ -x "./setup.sh" ]; then
        echo "Запускаю скрипт установки..."
        ./setup.sh
        echo "Удаление архива снепшота"
        rm -f *.tar.gz
    else
        echo "Ошибка: setup.sh не найден или не является исполняемым!"
        exit 0
    fi

    # Фикс проблемы с правами на доступ к директории
    sudo mkdir -p "$ink_dir/geth"
    sudo chown -R 1000:1000 "$ink_dir/geth"
    sudo chmod -R 755 "$ink_dir/geth"

    # Запуск Docker Compose
    echo "Запуск ноды..."
    docker compose up -d || {
        echo "Перезапуск Docker Compose..."
        docker compose down && docker compose up -d || {
            echo "Ошибка при повторном запуске Docker Compose!"
            exit 0
        }
    }
    echo "Установка и запуск выполнены успешно!"
}  # Закрытие функции install_node

# Удаление ноды
delete() {
    echo "Остановка и удаление контейнеров"
    cd "$ink_dir" && docker compose down 
    if confirm "Удалить директорию и все данные?"; then
        cd ~ && rm -rf ~/ink
        echo "Успешно удалено." 
    else
        echo "Не удалено."
    fi
}

# Меню с командами
show_menu() {
    show_logotip
    show_name
    echo "Выберите действие:"
    echo "1. Установить ноду"
    echo "2. Просмотр логов ноды"
    echo "3. Тестовый запрос к ноде"
    echo "4. Проверка контейнеров"
    echo "8. Вывод приватного ключа"
    echo "9. Удаление ноды"
    echo "0. Выход"
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
                echo "Ошибка: jq не установлен. Установите его с помощью: sudo apt install jq"
                exit 1
            fi
            if curl -s http://localhost:"$INK_RPC_PORT" &>/dev/null; then
                curl -s -d '{"id":1,"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest",false]}' \
                     -H "Content-Type: application/json" \
                     http://localhost:"$INK_RPC_PORT" | jq
            else
                echo "Ошибка: RPC на порту $INK_RPC_PORT недоступен. Проверьте, запущен ли узел."
            fi ;;
        4)  
            if [ -d "$ink_dir" ]; then
                cd "$ink_dir" && docker compose ps -a
            else
                echo "Ошибка: директория $ink_dir не найдена."
            fi ;;
        8)  cat "$ink_dir/var/secrets/jwt.txt" && echo "" ;;
        9)  delete ;;
        0)  exit 0 ;;
        *)  echo "Неверный выбор, попробуйте снова." ;;
    esac
}

while true; do
    show_menu
    read -p "Ваш выбор: " choice
    menu "$choice"
done
