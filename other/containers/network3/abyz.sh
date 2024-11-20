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

# Массив для хранения имен узлов и их портов
declare -A NODE_INFO

# Цикл для запуска введенного количества узлов
for i in $(seq 1 $NUM_NODES); do
    NODE_PORT=$((BASE_PORT + i))
    NODE_NAME="ubuntu-node-$i"

    echo "Запуск узла $NODE_NAME на порту $NODE_PORT..."

    # Удаление существующего контейнера с таким именем
    if docker ps -a --format '{{.Names}}' | grep -q "^$NODE_NAME$"; then
        echo "Уже запущен. Пропуск."
        NODE_INFO[$NODE_NAME]=$NODE_PORT
        continue
    fi

    # Запуск контейнера с указанием нового порта
    docker run -d --name $NODE_NAME -p $NODE_PORT:8080  \
        --cap-add=NET_ADMIN \
        --device=/dev/net/tun \
        --restart=always \
        ubuntu-node:latest

    # Сохранение информации об узле
    NODE_INFO[$NODE_NAME]=$NODE_PORT

    echo "Узел $NODE_NAME запущен."
done

echo "Все узлы запущены. Выполняется получение ключей..."

# Необходимая пауза для полного запуска работы
sleep 5

# Обработка каждого контейнера для получения ключей и сохранения в файл
for NODE_NAME in "${!NODE_INFO[@]}"; do
    NODE_PORT=${NODE_INFO[$NODE_NAME]}
    
    # Получение ключа и удаление ненужной строки из всего вывода
    NODE_KEY=$(docker exec $NODE_NAME bash -c "./manager.sh key" | sed 's/System architecture is x86_64 (64-bit)//g')

    if [ $? -ne 0 ]; then
        echo "Ошибка получения ключа для узла $NODE_NAME."
        continue
    fi

    NODE_URL="https://account.network3.ai/main?o=$HOST_IP:$NODE_PORT"
    OUTPUT_LINE="$NODE_URL $NODE_KEY"

    # Сохранение строки в файл
    echo $OUTPUT_LINE >> $OUTPUT_FILE
    echo "Ключ для узла $NODE_NAME сохранен."
done

echo "Все данные сохранены в $OUTPUT_FILE."
