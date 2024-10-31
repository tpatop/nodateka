#!/bin/bash

# Скачиваем файл ora-restart.sh в папку ~/tora
wget -O ~/tora/ora-restart.sh https://raw.githubusercontent.com/tpatop/nodateka/main/ora-restart.sh

# Делаем скрипт исполняемым
chmod +x ~/tora/ora-restart.sh

# Добавляем задание в crontab для запуска скрипта каждый час
(crontab -l 2>/dev/null; echo "0 * * * * ~/tora/ora-restart.sh") | crontab -

echo "Скрипт успешно скачан, установлен как исполняемый и добавлен в crontab для выполнения каждый час."
