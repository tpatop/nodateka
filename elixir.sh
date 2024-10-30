#!/bin/bash

# Вызов скрипта для вывода имени
bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/main/name.sh)

# Функция для отображения меню
show_menu() {
    echo ""
    echo "Выберите действие:"
    echo "1. Установить узел"
    echo "2. Обновить узел"
    echo "3. Мониторинг работы узла"
    echo "0. Выход"
    read -p "Введите номер действия (1, 2, 3 или 0): " action
}

# Основной цикл для работы меню
while true; do
    show_menu

    case "$action" in
        1)
            # Установка узла
            echo "Устанавливаем узел..."
            # Установка пакетов
            sudo apt install -y curl git jq lz4 build-essential unzip
            # Вызов скрипта для проверки и установки Docker и Docker Compose
            bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/main/docker.sh)

            # Создание каталога и загрузка файла конфигурации
            mkdir ~/elixir && cd ~/elixir
            wget https://files.elixir.finance/validator.env

            # Запрос данных для заполнения переменных
            read -p "Введите имя вашего валидатора: " STRATEGY_EXECUTOR_DISPLAY_NAME
            read -p "Введите публичный ключ (с 0х): " STRATEGY_EXECUTOR_BENEFICIARY
            read -p "Введите приватный ключ (с 0х): " SIGNER_PRIVATE_KEY

            # Замена значений в validator.env
            sed -i "s/^STRATEGY_EXECUTOR_DISPLAY_NAME=.*/STRATEGY_EXECUTOR_DISPLAY_NAME=$STRATEGY_EXECUTOR_DISPLAY_NAME/" validator.env
            sed -i "s/^STRATEGY_EXECUTOR_BENEFICIARY=.*/STRATEGY_EXECUTOR_BENEFICIARY=$STRATEGY_EXECUTOR_BENEFICIARY/" validator.env
            sed -i "s/^SIGNER_PRIVATE_KEY=.*/SIGNER_PRIVATE_KEY=$SIGNER_PRIVATE_KEY/" validator.env

            # Запуск Docker-контейнера
            docker pull elixirprotocol/validator:v3
            docker run -d --env-file ~/elixir/validator.env --name elixir --platform linux/amd64 elixirprotocol/validator:v3
            ;;
        
        2)
            # Обновление узла
            echo "Обновляем узел..."

            # Удаление существующего контейнера и загрузка новой версии
            docker rm -f elixir
            docker pull elixirprotocol/validator:v3
            docker run -d --env-file ~/elixir/validator.env --name elixir --platform linux/amd64 elixirprotocol/validator:v3
            ;;

        3)
            # Мониторинг работы узла
            echo "Запуск мониторинга работы узла..."
            docker logs -f elixir
            ;;

        0)
            # Выход
            echo "Завершение работы."
            exit 0
            ;;

        *)
            echo "Неверный выбор. Пожалуйста, попробуйте снова."
            ;;
    esac
done
