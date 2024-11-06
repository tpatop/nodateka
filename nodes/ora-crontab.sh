#!/bin/bash

# Логотип команды
show_logotip(){
    bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/name.sh)
}

# Функция для скачивания скрипта ora-restart.sh, если его еще нет
download_script() {
    if [ ! -f ~/tora/ora-restart.sh ]; then
        mkdir -p ~/tora
        wget -O ~/tora/ora-restart.sh https://github.com/tpatop/nodateka/blob/main/nodes/ora-restart.sh
        chmod +x ~/tora/ora-restart.sh
        echo "Скрипт ora-restart.sh успешно скачан и установлен как исполняемый."
    else
        echo "Скрипт ora-restart.sh уже существует."
    fi
}

# Функция для добавления задания в crontab
add_cron_job() {
    cron_job="$1 ~/tora/ora-restart.sh"
    existing_jobs=$(crontab -l |grep ora-restart.sh)
    
    if [ -n "$existing_jobs" ]; then
        echo "Задание уже существует:"
        echo "$existing_jobs"
        echo "Пожалуйста, удалите дублирующие задания вручную, прежде чем добавлять новое."
    else
        # Добавляем новое задание
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
        echo "Задание добавлено в crontab."
    fi
    echo "Посмотреть задания: crontab -l"
}

# Функция для удаления задания из crontab
remove_cron_job() {
    crontab -l | grep -v "~/tora/ora-restart.sh" | crontab -
    echo "Задание для автоматического перезапуска контейнера удалено из crontab."
}

# Функция для запроса удаления файлов
delete_files() {
    read -p "Удалить скрипт и логи? (y/n) (default - n): " delete_files
    if [[ "$delete_files" =~ ^[Yy]$ ]]; then
        rm -f ~/tora/ora-restart.sh ~/tora/restart.log
        echo "Скрипт и логи успешно удалены."
    fi
}

# Основное меню
echo "Выберите действие:"
echo "1. Запуск проверки контейнера в определенное время."
echo "2. Запуск проверки контейнера каждые X часов."
echo "3. Удалить настройку автоматического перезапуска."
echo "0. Выход."
read -p "Введите номер действия (1, 2, 3 или 0): " action

case "$action" in
    1)
        # Установка запуска в определенное время
        download_script
        read -p "Введите время в формате ЧЧ:ММ для запуска скрипта (например, 04:15): " schedule_time
        # Разделяем введенное время на часы и минуты
        IFS=: read hour minute <<< "$schedule_time"
        cron_time="$minute $hour * * *"
        add_cron_job "$cron_time"
        ;;
    2)
        # Установка запуска каждые X часов
        download_script
        while true; do
            read -p "Введите интервал в часах для запуска скрипта (1-12): " interval_hours
            if [[ "$interval_hours" =~ ^[1-9]$ || "$interval_hours" =~ ^1[0-9]$ || "$interval_hours" == "12" ]]; then
                break
            else
                echo "Ошибка: интервал должен быть числом от 1 до 12. Пожалуйста, попробуйте снова."
            fi
        done
        cron_time="0 */$interval_hours * * *"
        add_cron_job "$cron_time"
        ;;
    3)
        # Удаление задания из crontab и запрос на удаление файлов
        remove_cron_job
        delete_files
        ;;
    0)
        echo "Выход из программы." ;;
    *)
        echo "Неверный выбор. Завершение работы." ;;
esac
