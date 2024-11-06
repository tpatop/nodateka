#!/bin/bash

# Функция для подтверждения действия
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

# 1. Очистка журналов логирования старше заданного периода
clear_logs() {
    if confirm "Очистить журналы логирования?"; then
        echo "Очистка старых журналов..."
        sudo journalctl --vacuum-time=1s
        sudo find /var/log -type f \( -name "*.gz" -o -name "*.xz" -o -name "*.tar" -o -name "*.zip" \) -delete
        sudo find /run/log -type f \( -name "*.gz" -o -name "*.xz" -o -name "*.tar" -o -name "*.zip" \) -delete
        sudo rm /var/log/syslog*
        sudo rm /var/log/kern.log*
        sudo systemctl restart rsyslog
        echo "Журналы успешно очищены."
    else
        echo "Очистка журналов отменена."
    fi
}

# 2. Очистка Docker
clear_docker() {
    if confirm "Очистить Docker, удалив неиспользуемые контейнеры, образы и сети?"; then
        echo "Очистка Docker..."
        sudo docker system prune -a -f
        echo "Docker успешно очищен."
    else
        echo "Очистка Docker отменена."
    fi
}

# 3. Удаление архивов в папке
delete_archives() {
    if confirm "Удалить все архивы (*.tar, *.gz, *.zip) в текущей директории?"; then
        echo "Удаление архивов..."
        find . -type f \( -name "*.tar" -o -name "*.gz" -o -name "*.zip" \) -exec rm -v {} \;
        echo "Архивы успешно удалены."
    else
        echo "Удаление архивов отменено."
    fi
}

# 4. Удаление кеша, временных файлов и пр.
delete_cache() {
    if confirm "Будет произведена очистка кеша, приступить?"; then
        echo "очистка кеша"
        sudo apt clean
        sudo apt autoremove --purge
        sudo apt autoremove
        sudo sync; sudo sysctl -w vm.drop_caches=3
        rm -rf ~/.cache/thumbnails/*
        echo "Кеш успешно очищен."
    else 
        echo "Отменено"
    fi
}

# Вызов всех функций с подтверждением пользователя
clear_logs
clear_docker
delete_archives
delete_cache
