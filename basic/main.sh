#!/bin/bash

# Скрипт для отображения основной страницы по настройке сервера

# Логотип команды
show_logotip(){
    bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/name.sh)
}

# Функция для подтверждения выбора пользователя
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

# Функция для настройки iptables
setup_iptables() {
    echo "Загружается и выполняется скрипт для настройки iptables..."
    bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/admin/iptables.sh)
    echo "Настройка iptables завершена."
}

# Функция для установки Fail2ban
install_fail2ban() {
    echo "Загружается и выполняется скрипт для установки Fail2ban..."
    bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/admin/fail2ban.sh)
    echo "Установка Fail2ban завершена."
}

# Функция для очистки памяти
autoclear_memory() {
    echo "Загружается и выполняется скрипт для настройки автоматического очищения..."
    bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/admin/clear_auto.sh)
    echo "Успешно."
}

# Функция для очистки памяти
clear_memory() {
    echo "Загружается и выполняется скрипт для очистки памяти..."
    bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/admin/clear.sh)
    echo "Очистка памяти завершена."
}

show_node_list() {
    echo "Выберите действие:"
    echo -e "1. Elixir (mainnet/testnet)"
    echo -e "2. Unichain"
    echo -e "3. Ritual"
    echo -e "4. Ora (перезапуск)"
    echo "0. Выход"
}

BASE_URL="https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/nodes"
node_menu() {
    case "$1" in
        1) bash <(curl -s ${BASE_URL}/elixir.sh) ;;
        2) bash <(curl -s ${BASE_URL}/unichain.sh) ;;
        3) bash <(curl -s ${BASE_URL}/ritual.sh) ;;   
        4) bash <(curl -s ${BASE_URL}/ora-restart.sh) ;; 
        0) echo "Выход."; exit 0 ;;
        *) echo "Неверный выбор. Попробуйте снова." ;;
    esac
}

node_list_start() {
    while true; do
        show_node_list
        read -p "Ваш выбор: " action
        node_menu "$action"  # Используем переменную action
    done
}


# Функция для отображения меню
show_menu() {
    echo "Выберите действие:"
    echo "1. Настройка iptables"
    echo "2. Установка Fail2ban"
    echo "3. Установка автоудаления логов"
    echo "4. Экспресс очистка памяти"
    echo "9. Список скриптов установки/настройки нод"
    echo "0. Выход"
}

# Функция для обработки выбора пользователя
handle_choice() {
    case "$1" in
        1) setup_iptables ;;
        2) install_fail2ban ;;
        3) autoclear_memory ;;   
        4) clear_memory ;; 
        9) node_list_start ;;               
        0) echo "Выход."; exit 0 ;;
        *) echo "Неверный выбор. Попробуйте снова." ;;
    esac
}

while true; do
    show_logotip
    show_menu
    read -p "Ваш выбор: " action
    handle_choice "$action"  # Используем переменную action
done
