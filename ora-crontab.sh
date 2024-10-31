#!/bin/bash

# Вызов скрипта для вывода имени
bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/main/name.sh)

# Скачиваем файл ora-restart.sh в папку ~/tora, если его еще нет
if [ ! -f ~/tora/ora-restart.sh ]; then
    mkdir -p ~/tora
    wget -O ~/tora/ora-restart.sh https://raw.githubusercontent.com/tpatop/nodateka/main/ora-restart.sh
    chmod +x ~/tora/ora-restart.sh
    echo "Скрипт ora-restart.sh успешно скачан и установлен как исполняемый."
else
    echo "Скрипт ora-restart.sh уже существует."
fi

# Выбор действия
echo "Выберите действие:"
echo "1. Создать проверку контейнера каждый час."
echo "2. Удалить проверку контейнера из crontab."
read -p "Введите номер действия (1 или 2): " action

if [ "$action" -eq 1 ]; then
    # Добавляем задание в crontab для перезапуска контейнера
    (crontab -l 2>/dev/null; echo "0 * * * * ~/tora/ora-restart.sh") | crontab -
    echo "Задание для проверки контейнера ora-tora добавлено в crontab и будет выполняться каждый час."

elif [ "$action" -eq 2 ]; then
    # Удаляем задание на перезапуск
    crontab -l | grep -v "~/tora/ora-restart.sh" | crontab -
    echo "Задание для проверки контейнера ora-tora удалено из crontab."

else
    echo "Неверный выбор. Завершение работы."
fi
