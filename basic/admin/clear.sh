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

# # 4. Сортировка файлов по размеру в текущей директории
# list_sorted_files() {
#     if confirm "Отсортировать файлы по размеру в текущей директории?"; then
#         echo "Список файлов по размеру:"
#         find . -type f -exec du -h {} + | sort -hr | head -n 10
#     else
#         echo "Сортировка файлов отменена."
#     fi
# }

# Вызов всех функций с подтверждением пользователя
clear_logs
clear_docker
delete_archives
# list_sorted_files
