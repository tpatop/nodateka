#!/bin/bash

# Сборка образа
docker build -t ubuntu-node:latest .

# Получение IP-адреса хоста
HOST_IP=$(hostname -I | awk '{print $1}')

# Создание файла для вывода
OUTPUT_FILE="network3.txt"
> $OUTPUT_FILE  # Очистка файла перед началом

# Запрос количества узлов у пользователя
read -p "Введите количество узлов для запуска: " NUM_NODES

# Проверка на корректность введенного числа
if ! [[ $NUM_NODES =~ ^[0-9]+$ ]]; then
    echo "Ошибка: введите корректное число."
    exit 1
fi

# Базовый порт
BASE_PORT=21000

# Цикл для запуска введенного количества узлов
for i in $(seq 1 $NUM_NODES); do
    NODE_PORT=$((BASE_PORT + i))
    NODE_NAME="ubuntu-node-$i"

    echo "Запуск узла $NODE_NAME на порту $NODE_PORT..."

    # Запуск контейнера с указанием нового порта
    docker run -d --name $NODE_NAME -p $NODE_PORT:8080 ubuntu-node:latest

    # Выполнение команды ./manager.sh key внутри контейнера и получение ключа
    NODE_KEY=$(docker exec $NODE_NAME bash -c "./manager.sh key")

    # Формирование строки с URL и ключом
    NODE_URL="https://account.network3.ai/main?o=$HOST_IP:$NODE_PORT"
    OUTPUT_LINE="$NODE_URL ./manager.sh key: $NODE_KEY"

    # Сохранение строки в файл
    echo $OUTPUT_LINE >> $OUTPUT_FILE

    echo "Узел $NODE_NAME запущен. Данные сохранены."
done

echo "Все узлы запущены. Данные сохранены в $OUTPUT_FILE."
