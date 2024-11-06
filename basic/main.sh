#!/bin/bash

# Скрипт для отображения основной страницы по настройке сервера

# Функция для отображения меню
show_menu() {
    echo "Выберите действие:"
    echo "1. Настройка iptables"
    echo "2. Установка Fail2ban"
    echo "3. Очистка памяти"
    echo "0. Выход"
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
    bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/admin/iptables.sh)
    echo "Установка Fail2ban завершена."
}

# Функция для очистки памяти
clear_memory() {
    echo "Очистка памяти..."
    # Здесь можно добавить конкретные команды для очистки памяти
    echo "Очистка памяти завершена."
}

# Основной цикл меню
while true; do
    show_menu
    read -p "Введите номер действия: " choice
    case $choice in
        1) setup_iptables ;;
        2) install_fail2ban ;;
        3) clear_memory ;;
        0) echo "Выход."; exit 0 ;;
        *) echo "Неверный выбор. Попробуйте снова." ;;
    esac
done
