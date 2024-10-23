#!/bin/bash

# Вызов скрипта для вывода имени
bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/main/name.sh)

# Вызов скрипта для проверки и установки Docker и Docker Compose
bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/main/docker.sh)

# Клонирование репозитория Uniswap unichain-node
echo "Клонирование репозитория Uniswap unichain-node..."
git clone https://github.com/Uniswap/unichain-node

# Проверка успешности клонирования
if [ $? -ne 0 ]; then
  echo "Ошибка при клонировании репозитория!"
  exit 1
fi

echo "Переход в директорию unichain-node..."
cd unichain-node

# Проверяем, существует ли файл .env.sepolia
if [ -f ".env.sepolia" ]; then
  echo "Файл .env.sepolia найден. Замена переменных..."
  sed -i 's|^OP_NODE_L1_ETH_RPC=.*|OP_NODE_L1_ETH_RPC=https://ethereum-sepolia-rpc.publicnode.com|' .env.sepolia
  sed -i 's|^OP_NODE_L1_BEACON=.*|OP_NODE_L1_BEACON=https://ethereum-sepolia-beacon-api.publicnode.com|' .env.sepolia
  echo "Переменные успешно заменены."
else
  echo "Ошибка: файл .env.sepolia не найден!"
  exit 1
fi

# Проверяем, существует ли файл docker-compose.yml
if [ -f "docker-compose.yml" ]; then
  echo "Файл docker-compose.yml найден. Замена портов..."
  sed -i 's|30303:|33303:|g' docker-compose.yml
  sed -i 's|8545:|8945:|g' docker-compose.yml
  sed -i 's|8546:|8946:|g' docker-compose.yml
  echo "Порты успешно заменены."
else
  echo "Ошибка: файл docker-compose.yml не найден!"
  exit 1
fi

echo "Запуск Docker Compose..."
docker compose up -d

# Проверка успешности запуска Docker Compose
if [ $? -eq 0 ]; then
  echo "Docker Compose успешно запущен!"
else
  echo "Ошибка при запуске Docker Compose!"
  exit 1
fi

echo "Скрипт выполнен успешно!"
