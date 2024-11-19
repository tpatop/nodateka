#!/bin/bash

# Получение списка всех контейнеров, связанных с узлами
NODE_CONTAINERS=$(docker ps -a --filter "name=ubuntu-node-" --format "{{.ID}}")

if [ -z "$NODE_CONTAINERS" ]; then
    echo "Нет контейнеров для удаления."
    exit 0
fi

# Остановка и удаление контейнеров
echo "Остановка и удаление всех узлов..."
docker stop $NODE_CONTAINERS
docker rm $NODE_CONTAINERS

echo "Все узлы успешно удалены."
