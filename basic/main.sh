#!/bin/bash

# Скрипт для отображения основной страницы по настройке сервера

# Логотип команды
bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/name.sh)

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
clear_memory() {
    echo "Загружается и выполняется скрипт для очистки памяти..."
    bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/admin/clear.sh)
    echo "Очистка памяти завершена."
}

# Функция для отображения меню
show_menu() {
    echo "Выберите действие:"
    echo "1. Настройка iptables"
    echo "2. Установка Fail2ban"
    echo "3. Очистка памяти"
    echo "0. Выход"
}

# Функция для обработки выбора пользователя
handle_choice() {
    case "$1" in
        1)
            setup_iptables ;;
        2)
            install_fail2ban ;;
        3)
            clear_memory ;;        
        0) 
            echo "Выход."; exit 0 ;;
        *) 
            echo "Неверный выбор. Попробуйте снова." ;;
    esac
}

while true; do
    show_menu
    read -p "Ваш выбор: " action
    handle_choice "$action"  # Используем переменную action
done
