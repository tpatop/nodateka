#!/bin/bash

# Этот скрипт устанавливает и настраивает logrotate для автоматической очистки логов.
# logrotate — это инструмент, который помогает управлять лог-файлами, ограничивая их размер и предотвращая переполнение диска.
# Он автоматически создает архивы старых логов, сжимает их и удаляет самые старые файлы после заданного количества ротаций.
#
# В данном скрипте logrotate будет настроен на:
# 1. Ежедневную ротацию логов, что предотвращает их накопление.
# 2. Ограничение объема логов до 100 MB, удаляя старые записи, если лимит превышен.
# 3. Сжатие логов для экономии места и создание новых после ротации.
#
# Используйте этот скрипт, чтобы поддерживать контроль за лог-файлами на сервере.

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

install_logrotate() {
    # Проверка и установка logrotate
    if ! command -v logrotate &> /dev/null; then
        echo "Установка logrotate..."
        sudo apt update && sudo apt install -y logrotate
    else
        echo "logrotate уже установлен."
    fi

    # Настройка конфигурации logrotate
    echo "Настройка logrotate для очистки логов..."

    # Создаем или перезаписываем конфигурацию
    sudo tee /etc/logrotate.conf > /dev/null <<EOL
# Это глобальная конфигурация для logrotate
# Ротация логов ежедневно
daily
# Хранить последние 7 файлов логов
rotate 7
# Сжимать старые файлы
compress
# Пропускать, если файл не существует
missingok
# Пропускать, если файл пустой
notifempty
# Ожидать один день перед сжатием
delaycompress
# Ограничение на максимальный размер логов
maxsize 100M
# Включаем проверку файлов
create
# Перезапускать службу после ротации логов (например, syslog)
postrotate
    systemctl reload syslog.service
endscript
EOL

    echo "logrotate настроен на ежедневную очистку логов, хранения логов до 100 MB."
    echo "Запуск проверки logrotate..."
    sudo logrotate -f /etc/logrotate.conf -v
    echo "Настройка завершена."
}

# Для очистки логов, хранящихся в бинарных файла (journal)
configure_journald() {
    echo "Настройка systemd-journald для ограничения размера и времени хранения журналов..."

    # Редактирование конфигурации systemd-journald
    sudo tee -a /etc/systemd/journald.conf > /dev/null <<EOL
[Journal]
SystemMaxUse=100M
MaxRetentionSec=3d
EOL

    # Перезапуск systemd-journald для применения настроек
    sudo systemctl restart systemd-journald
    echo "Настройка systemd-journald завершена."
}

install_rsyslog() {
    # Проверка и установка rsyslog
    if ! command -v rsyslogd &> /dev/null; then
        echo "Установка rsyslog..."
        sudo apt update && sudo apt install -y rsyslog
    else
        echo "rsyslog уже установлен."
    fi

    # Редактирование конфигурации rsyslog
    RSYSLOG_CONF="/etc/rsyslog.conf"
    echo "Настройка rsyslog для ограничения размера и хранения логов..."

    # Добавляем ограничения в конфигурацию rsyslog
    sudo tee -a "$RSYSLOG_CONF" > /dev/null <<EOL
# Ограничение по времени для хранения логов
$MaxMessageSize 1M    # Максимальный размер для каждого сообщения
$MaxFileSize 100M     # Максимальный размер файлов логов
# Удаление логов старше 3 дней
$FileRetentionTime 3d # Удаление логов старше 3 дней
EOL

    # Перезагрузка rsyslog для применения изменений
    sudo systemctl restart rsyslog
    echo "Настройка rsyslog завершена."
}


echo "logrotate и rsyslog — это инструменты, которые помогают управлять лог-файлами, ограничивая их размер и предотвращая переполнение диска."
echo "logrotate управляет ротацией и удалением старых логов, а rsyslog ограничивает размер логов и задает параметры их хранения."
echo "systemd-journald управляет бинарными журналами, и мы будем настраивать его для ограничения размера и времени хранения."

if confirm "Установить и настроить logrotate и rsyslog?"; then
    install_logrotate
    install_rsyslog
else
    echo "Отменено"
fi

if confirm "Настроить systemd-journald для ограничения размера журналов и времени хранения?"; then
    configure_journald
else
    echo "Отменено"
fi
