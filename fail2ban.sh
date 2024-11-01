#!/bin/bash

# Скрипт управления Fail2ban для защиты SSH
# Только root

# Вызов скрипта для вывода имени
bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/main/name.sh)

# Функция установки Fail2ban
install_fail2ban() {
    echo "Установка Fail2ban..."
    apt install -y fail2ban
    if ! command -v fail2ban-server > /dev/null; then
        echo "Ошибка: Fail2ban не установлен. Проверьте подключение к интернету и повторите попытку."
        exit 1
    fi
    echo "Fail2ban успешно установлен."
}

# Функция для создания конфигурационного файла джейла SSH
create_jail_local() {
    local jail_local="/etc/fail2ban/jail.local"
    echo "Создание конфигурационного файла $jail_local..."

    cat <<EOL > $jail_local
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
findtime = 600
bantime = 3600
EOL

    echo "Конфигурация для sshd создана."
}

# Функция перезапуска Fail2ban
restart_fail2ban() {
    echo "Перезапуск Fail2ban..."
    systemctl restart fail2ban
    if systemctl is-active --quiet fail2ban; then
        echo "Fail2ban успешно запущен."
    else
        echo "Ошибка: Fail2ban не удалось запустить. Проверьте конфигурацию."
        exit 1
    fi
}

# Функция проверки статуса джейла sshd
check_jail_status() {
    echo "Проверка статуса блокировок sshd..."
    fail2ban-client status sshd
}

# Функция изменения параметров конфигурации
change_settings() {
    local jail_local="/etc/fail2ban/jail.local"
    echo "Введите количество попыток перед блокировкой (maxretry):"
    read -r maxretry
    echo "Введите время отслеживания (findtime, в секундах):"
    read -r findtime
    echo "Введите время блокировки (bantime, в секундах):"
    read -r bantime

    sed -i "/maxretry/c\maxretry = $maxretry" $jail_local
    sed -i "/findtime/c\findtime = $findtime" $jail_local
    sed -i "/bantime/c\bantime = $bantime" $jail_local

    echo "Новые параметры сохранены в $jail_local:"
    echo "maxretry = $maxretry, findtime = $findtime, bantime = $bantime"

    restart_fail2ban
}

# Функция меню
show_menu() {
    echo "Выберите действие:"
    echo "1. Установка Fail2ban"
    echo "2. Проверка статуса джейла sshd"
    echo "3. Изменение настроек (maxretry, findtime, bantime)"
    echo "0. Выход"
    read -r choice
    case $choice in
        1)
            install_fail2ban
            create_jail_local
            restart_fail2ban
            ;;
        2)
            check_jail_status
            ;;
        3)
            change_settings
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

# Главная функция
main() {
    while true; do
        show_menu
    done
}

# Запуск главной функции
main
