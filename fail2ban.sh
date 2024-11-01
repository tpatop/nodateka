#!/bin/bash
# Скрипт управления Fail2ban для защиты SSH

# Логотип команды
bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/main/name.sh)

# Функция установки Fail2ban
install_fail2ban() {
    # Установка и настройка логирования, если отсутствует
    bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/auth_log.sh)
    
    echo "🔍 Проверка наличия Fail2ban..."
    if dpkg -l | grep -q fail2ban; then
        echo "⚠️ Fail2ban уже установлен. Пропускаем установку."
    else
        echo "🛠️ Установка Fail2ban..."
        sudo apt update
        sudo apt install -y fail2ban
        echo "✅ Fail2ban успешно установлен."
    fi
}


# Функция для создания конфигурационного файла джейла SSH
create_jail_local() {
    local jail_local="/etc/fail2ban/jail.local"
    echo -e "\n📁 Создание конфигурационного файла $jail_local..."

    cat <<EOL > $jail_local
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
findtime = 6000
bantime = 36000
EOL

    echo "✅ Конфигурация для sshd создана."
}

# Функция перезапуска Fail2ban
restart_fail2ban() {
    echo -e "\n🔄 Перезапуск Fail2ban..."
    systemctl restart fail2ban
    if systemctl is-active --quiet fail2ban; then
        echo "✅ Fail2ban успешно запущен."
    else
        echo "❌ Ошибка: Fail2ban не удалось запустить. Проверьте конфигурацию."
        exit 1
    fi
}

# Функция проверки статуса джейла sshd
check_jail_status() {
    echo -e "\nℹ️ Проверка статуса джейла sshd..."
    fail2ban-client status sshd
}

# Функция изменения параметров конфигурации
change_settings() {
    local jail_local="/etc/fail2ban/jail.local"
    echo -e "\n⚙️ Изменение настроек джейла sshd:"
    
    # Запрос значений у пользователя с указанием значений по умолчанию
    read -rp "Введите количество попыток перед блокировкой (maxretry) [3]: " maxretry
    read -rp "Введите время отслеживания (findtime, в секундах) [3600]: " findtime
    read -rp "Введите время блокировки (bantime, по умолчанию -1 для постоянной блокировки): " bantime

    # Применяем значения по умолчанию, если пользователь оставил поле пустым
    maxretry="${maxretry:-3}"
    findtime="${findtime:-3600}"
    bantime="${bantime:--1}"  # Постоянная блокировка по умолчанию

    # Применение изменений в jail.local
    sed -i "/maxretry/c\maxretry = $maxretry" "$jail_local"
    sed -i "/findtime/c\findtime = $findtime" "$jail_local"
    sed -i "/bantime/c\bantime = $bantime" "$jail_local"

    echo -e "\n✅ Новые параметры сохранены в $jail_local:"
    echo "maxretry = $maxretry, findtime = $findtime, bantime = $bantime"

    restart_fail2ban
}


# Функция меню
show_menu() {
    echo -e "\n==============================="
    echo "    Выберите действие:"
    echo "==============================="
    echo "1. 🛠 Установка Fail2ban"
    echo "2. 📊 Проверка статуса джейла sshd"
    echo "3. ⚙️  Изменение настроек (maxretry, findtime, bantime)"
    echo "0. 🚪 Выход"
    echo "==============================="
    read -rp "Ваш выбор: " choice
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
            echo "👋 Выход..."
            exit 0
            ;;
        *)
            echo "❌ Неверный выбор, попробуйте снова."
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
