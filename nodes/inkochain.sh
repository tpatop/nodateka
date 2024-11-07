#!/bin/bash

# Логотип команды
show_logotip() {
    bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/name.sh)
}

# Функция для установки зависимостей
install_dependencies() {
    if confirm "Установить необходимые пакеты и зависимости?"; then
        bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/admin/docker.sh)
    else
        echo "Отменено."
    fi
}

# Клонирование репозитория 
echo "Клонирование репозитория Ink node..."
git clone https://github.com/inkonchain/node.git

# Проверка успешности клонирования
if [ $? -ne 0 ]; then
  echo "Ошибка при клонировании репозитория!"
  exit 1
fi

echo "Переход в директорию узла..."
cd node

echo "Запускаю скрипт установки"
./setup.sh

required_ports=("3000" "5000" "2020" "24224" "6379" "4999", "4998")
    
for port in "${required_ports[@]}"; do
    if ss -tuln | grep -q ":$port "; then
        echo "Порт $port: ЗАНЯТ"
    else
        echo "Порт $port: СВОБОДЕН"
    fi
done



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

echo "Установка выполнена успешно!"

# Справочная информация
echo "Справочная информация:"
echo "1. Тестовый запрос к ноде:"
echo '   curl -d '\''{"id":1,"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest",false]}'\'' -H "Content-Type: application/json" http://localhost:8545 | jq'
echo "2. Вывод приватного ключа:"
echo '   cat ~/unichain-node/geth-data/geth/nodekey'
echo "3. Логи ноды:"
echo '   cd ~/unichain-node && docker compose logs -f'
echo "4. Удаление ноды:"
echo '   cd ~/unichain-node && docker compose down && cd ~ && rm -rf ~/unichain-node'
