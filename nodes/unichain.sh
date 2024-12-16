#!/bin/bash


# Функция изменения настроек узла
 change_settings() {
   ~/unichain-node
   if [ -f ".env.sepolia" ]; then
    sed -i 's|^OP_NODE_L1_ETH_RPC=.*|OP_NODE_L1_ETH_RPC=https://ethereum-sepolia-rpc.publicnode.com|' .env.sepolia
    sed -i 's|^OP_NODE_L1_BEACON=.*|OP_NODE_L1_BEACON=https://ethereum-sepolia-beacon-api.publicnode.com|' .env.sepolia
  else
    echo "Ошибка: файл .env.sepolia не найден!"; exit 1;
  fi

  if [ -f "docker-compose.yml" ]; then
    sed -i 's|30303:|33303:|g' docker-compose.yml
    sed -i 's|8545:|8945:|g' docker-compose.yml
    sed -i 's|8546:|8946:|g' docker-compose.yml
  else
    echo "Ошибка: файл docker-compose.yml не найден!"; exit 1;
  fi
 }

# Функция установки ноды
install_node() {
  echo "Запуск установки ноды..."
  bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/admin/docker.sh)

  echo "Клонирование репозитория Uniswap unichain-node..."
  git clone https://github.com/Uniswap/unichain-node || {
    echo "Ошибка при клонировании репозитория!"; exit 1;
  }

  cd ~/unichain-node || exit 1

  # Изменение настроек
  change_settings

  docker compose up -d || {
    echo "Ошибка при запуске Docker Compose!"; exit 1;
  }

  echo "Установка выполнена успешно!"
}

# Функция обновления узла
update_node() {
  echo "Обновление узла (запланировано на 18.12.2024)..."
  cd ~/unichain-node
  git stash && git pull
  change_settings
  docker compose down && docker compose up -d || {
    echo "Ошибка при запуске Docker Compose!"; exit 1;
  }
  echo "Обновление узла прошло успешно!"
}

# Функция тестового запроса
send_test_request() {
  echo "Выполнение тестового запроса к ноде..."
  curl -d '{"id":1,"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest",false]}' -H "Content-Type: application/json" http://localhost:8945 | jq
}

# Функция отображения логов ноды
show_logs() {
  echo "Просмотр логов ноды..."
  cd ~/unichain-node || exit 1
  docker compose logs -f
}

# Функция вывода приватного ключа
show_private_key() {
  echo "Вывод приватного ключа..."
  if [ -f ~/unichain-node/geth-data/geth/nodekey ]; then
    echo ''
    cat ~/unichain-node/geth-data/geth/nodekey
    echo ''
  else
    echo "Приватный ключ не найден!"
  fi
}

# Функция удаления ноды
delete_node() {
  echo "Удаление ноды..."
  cd ~/unichain-node || exit 1
  docker compose down
  cd ~
  rm -rf ~/unichain-node
  echo "Нода успешно удалена."
}

# Функция для отображения меню
show_menu() {
  echo ""
  echo "Выберите действие:"
  echo "1. Установка ноды"
  echo "2. Обновление узла (18.12.2024)"
  echo "3. Тестовый запрос"
  echo "4. Логи ноды"
  echo "8. Вывод приватного ключа"
  echo "9. Удаление ноды"
  echo "0. Выход"
}

# Основной цикл программы
while true; do
  bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/name.sh)
  show_menu
  read -p "Ваш выбор: " choice
  case $choice in
    1) install_node ;;
    2) update_node ;;
    3) send_test_request ;;
    4) show_logs ;;
    8) show_private_key ;;
    9) delete_node ;;
    0) echo "Выход."; break ;;
    *) echo "Неверный выбор, попробуйте снова." ;;
  esac
done
