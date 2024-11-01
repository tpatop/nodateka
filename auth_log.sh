#!/bin/bash

# Функция для добавления или изменения параметра в конфигурационном файле
set_param_in_config() {
    local file=$1
    local param=$2
    local value=$3

    if grep -q "^$param" "$file"; then
        sed -i "s|^$param.*|$param $value|g" "$file"
    else
        echo "$param $value" >> "$file"
    fi
}

# Функция для настройки уровня логирования SSH
configure_ssh_logging() {
    echo "Настройка логирования SSH..."
    set_param_in_config "$SSHD_CONFIG" "LogLevel" "INFO"
    echo "Уровень логирования SSH установлен на INFO."
}

# Функция для перезапуска службы SSH
restart_ssh_service() {
    echo "Перезапуск службы SSH..."
    sudo systemctl restart ssh
    echo "Служба SSH перезапущена."
}

# Функция для проверки и запуска службы rsyslog
check_rsyslog_service() {
    echo "Проверка состояния службы rsyslog..."
    if systemctl is-active --quiet rsyslog; then
        echo "Служба rsyslog уже запущена."
    else
        echo "Служба rsyslog не запущена. Запускаем..."
        sudo systemctl start rsyslog
        echo "Служба rsyslog запущена."
    fi
}

# Функция для настройки rsyslog для логов аутентификации
configure_rsyslog() {
    echo "Проверка конфигурации rsyslog на предмет записи логов аутентификации..."
    if grep -q "auth,authpriv.* /var/log/auth.log" "$RSYSLOG_CONFIG"; then
        echo "Конфигурация rsyslog для логов аутентификации найдена."
    else
        echo "Добавляем конфигурацию rsyslog для логов аутентификации..."
        echo "auth,authpriv.*                 /var/log/auth.log" | sudo tee -a "$RSYSLOG_CONFIG" > /dev/null
        sudo systemctl restart rsyslog
        echo "Конфигурация rsyslog обновлена."
    fi
}

# Функция для проверки наличия логов аутентификации
check_auth_logs() {
    echo "Проверка наличия логов аутентификации..."
    if [ -f /var/log/auth.log ]; then
        echo "Логи аутентификации доступны:"
        tail -n 10 /var/log/auth.log
    else
        echo "Логи аутентификации не найдены."
    fi
}

# Функция для установки rsyslog
install_rsyslog() {
    echo "Установка rsyslog..."
    sudo apt update
    sudo apt install -y rsyslog
    echo "rsyslog установлен."
}

# Функция для проверки и запуска службы rsyslog
check_rsyslog_service() {
    echo "Проверка состояния службы rsyslog..."
    if systemctl is-active --quiet rsyslog; then
        echo "Служба rsyslog уже запущена."
    else
        echo "Служба rsyslog не запущена. Запускаем..."
        sudo systemctl start rsyslog
        echo "Служба rsyslog запущена."
    fi
}

# Основная функция
main() {
    # Определяем переменные
    SSHD_CONFIG="/etc/ssh/sshd_config"
    RSYSLOG_CONFIG="/etc/rsyslog.conf"

    # Проверка на наличие rsyslog
    if ! dpkg -l | grep -q rsyslog; then
        install_rsyslog
    fi

    # Выполняем настройки
    configure_ssh_logging
    restart_ssh_service
    check_rsyslog_service
    configure_rsyslog
    check_auth_logs

    echo "Настройка завершена."
}

