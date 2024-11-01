#!/bin/bash

# Определяем переменные
SSHD_CONFIG="/etc/ssh/sshd_config"
RSYSLOG_CONFIG="/etc/rsyslog.conf"
LOG_FILE="/var/log/auth_setup.log"

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
    echo "[$(date)] Настройка логирования SSH..." | tee -a "$LOG_FILE"
    set_param_in_config "$SSHD_CONFIG" "LogLevel" "INFO"
    echo "[$(date)] Уровень логирования SSH установлен на INFO." | tee -a "$LOG_FILE"
}

# Функция для перезапуска службы SSH
restart_ssh_service() {
    echo "[$(date)] Перезапуск службы SSH..." | tee -a "$LOG_FILE"
    sudo systemctl restart ssh
    echo "[$(date)] Служба SSH перезапущена." | tee -a "$LOG_FILE"
}

# Функция для установки rsyslog
install_rsyslog() {
    echo "[$(date)] Установка rsyslog..." | tee -a "$LOG_FILE"
    sudo apt update
    # Используем DEBIAN_FRONTEND=noninteractive для установки без интерактивных запросов
    sudo DEBIAN_FRONTEND=noninteractive apt install -y rsyslog
    echo "[$(date)] rsyslog установлен." | tee -a "$LOG_FILE"
}


# Функция для проверки и запуска службы rsyslog
check_rsyslog_service() {
    echo "[$(date)] Проверка состояния службы rsyslog..." | tee -a "$LOG_FILE"
    if systemctl is-active --quiet rsyslog; then
        echo "[$(date)] Служба rsyslog уже запущена." | tee -a "$LOG_FILE"
    else
        echo "[$(date)] Служба rsyslog не запущена. Запускаем..." | tee -a "$LOG_FILE"
        sudo systemctl start rsyslog
        echo "[$(date)] Служба rsyslog запущена." | tee -a "$LOG_FILE"
    fi
}

# Функция для настройки rsyslog для логов аутентификации
configure_rsyslog() {
    echo "[$(date)] Проверка конфигурации rsyslog на предмет записи логов аутентификации..." | tee -a "$LOG_FILE"
    if grep -q "auth,authpriv.* /var/log/auth.log" "$RSYSLOG_CONFIG"; then
        echo "[$(date)] Конфигурация rsyslog для логов аутентификации найдена." | tee -a "$LOG_FILE"
    else
        echo "[$(date)] Добавляем конфигурацию rsyslog для логов аутентификации..." | tee -a "$LOG_FILE"
        echo "auth,authpriv.*                 /var/log/auth.log" | sudo tee -a "$RSYSLOG_CONFIG" > /dev/null
        sudo systemctl restart rsyslog
        echo "[$(date)] Конфигурация rsyslog обновлена." | tee -a "$LOG_FILE"
    fi
}

# Функция для проверки наличия логов аутентификации
check_auth_logs() {
    echo "[$(date)] Проверка наличия логов аутентификации..." | tee -a "$LOG_FILE"
    if [ -f /var/log/auth.log ]; then
        echo "[$(date)] Логи аутентификации доступны:" | tee -a "$LOG_FILE"
        tail -n 10 /var/log/auth.log | tee -a "$LOG_FILE"
    else
        echo "[$(date)] Логи аутентификации не найдены." | tee -a "$LOG_FILE"
    fi
}

# Основная функция
main() {
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

    echo "[$(date)] Настройка завершена." | tee -a "$LOG_FILE"
}

# Запуск основной функции
main
