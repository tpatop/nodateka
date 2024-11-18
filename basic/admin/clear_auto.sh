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
# Хранить последние 1 файлов логов
rotate 1
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
# Перезапускать службу после ротации логов
postrotate
    systemctl reload rsyslog > /dev/null 2>/dev/null || true
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
    sudo tee /etc/systemd/journald.conf > /dev/null <<EOL
[Journal]
SystemMaxUse=100M
MaxRetentionSec=2d
EOL

    # Перезапуск systemd-journald для применения настроек
    sudo systemctl restart systemd-journald.socket
    sudo systemctl restart systemd-journald
    echo "Настройка systemd-journald завершена."
}

install_rsyslog() {
    # Проверка и установка rsyslog
    if ! command -v rsyslogd &> /dev/null; then
        echo "Установка rsyslog..."
        sudo apt update && sudo apt install -y rsyslog
        echo "Установка rsyslog завершена."
    else
        echo "rsyslog уже установлен."
    fi
}

# Добавление задания в crontab на очистку syslog и kern.log
clean_syslog() {
    echo "Добавление задачи в crontab для очистки логов каждые 15 минут..."
    CRON_JOB="*/15 * * * * echo '' > /var/log/kern.log && echo '' > /var/log/syslog"
    (crontab -l 2>/dev/null | grep -v -F "$CRON_JOB" ; echo "$CRON_JOB") | crontab -
    echo "Задача успешно добавлена в crontab."
}

echo "logrotate и rsyslog — это инструменты, которые помогают управлять лог-файлами, ограничивая их размер и предотвращая переполнение диска."
echo "logrotate управляет ротацией и удалением старых логов, а rsyslog отвечает за создание и запись логов в файлы."
echo "systemd-journald управляет бинарными журналами, настроем его для ограничения размера и времени хранения."

# Основной сценарий
echo "Настройка управления логами: logrotate, journald и rsyslog."

if confirm "Установить и настроить logrotate и rsyslog?"; then
    install_logrotate
    install_rsyslog
fi

if confirm "Настроить systemd-journald?"; then
    configure_journald
fi

echo "В некоторых случаях (лично у меня(tpatop)) проходит настолько большой трафик, что syslog и kern.log занимают ~80гб за сутки каждый."
echo "самый простой способ для решения данной проблемы - переодически обнулять файлы, что и будет предложено далее."
if confirm "Добавить задачу для очистки syslog и kern.log каждые 15 минут?"; then
    clean_syslog
fi
