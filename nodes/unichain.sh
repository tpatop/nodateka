#!/bin/bash

change_rpc() {
  if [ -f "$HOME/unichain-node/.env.mainnet" ]; then
    read -p "Изменить адреса RPC? [y/N]: " confirm
    confirm=${confirm,,} # Приводим к нижнему регистру
    if [[ "$confirm" == "y" ]]; then
        read -p "Введите новый OP_NODE_L1_ETH_RPC (по умолчанию https://ethereum-rpc.publicnode.com): " eth_rpc
        read -p "Введите новый OP_NODE_L1_BEACON (по умолчанию https://ethereum-beacon-api.publicnode.com): " beacon
        eth_rpc=${eth_rpc:-https://ethereum-rpc.publicnode.com}
        beacon=${beacon:-https://ethereum-beacon-api.publicnode.com}
    else
        eth_rpc="https://ethereum-rpc.publicnode.com"
        beacon="https://ethereum-beacon-api.publicnode.com"
    fi
    
    sed -i "s|^OP_NODE_L1_ETH_RPC=.*|OP_NODE_L1_ETH_RPC=$eth_rpc|" $HOME/unichain-node/.env.mainnet
    sed -i "s|^OP_NODE_L1_BEACON=.*|OP_NODE_L1_BEACON=$beacon|" $HOME/unichain-node/.env.mainnet
    echo 'Изменение RPC успешно применено!'
  else
    echo "Ошибка: файл .env.mainnet не найден!"; exit 1;
  fi
}

# Функция изменения настроек узла
 change_settings() {
  if [ -f "$HOME/unichain-node/docker-compose.yml" ]; then
    sed -i 's|30303:|33303:|g' $HOME/unichain-node/docker-compose.yml
    sed -i 's|8545:|8945:|g' $HOME/unichain-node/docker-compose.yml
    sed -i 's|8546:|8946:|g' $HOME/unichain-node/docker-compose.yml
    sed -i 's/^#\s\+- .env.mainnet/      - .env.mainnet/' $HOME/unichain-node/docker-compose.yml
  else
    echo "Ошибка: файл docker-compose.yml не найден!"; exit 0;
  fi
 }

# Функция установки ноды
install_node() {
  echo "Запуск установки ноды..."
  bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/admin/docker.sh)

  echo "Клонирование репозитория Uniswap unichain-node..."
  # Удаление директории при наличии
  if [ -d "$HOME/unichain-node" ]; then
    delete_node
  fi
  # Скачивание директории проекта
  git clone https://github.com/Uniswap/unichain-node "$HOME/unichain-node" || {
    echo "Ошибка при клонировании репозитория!"; exit 1;
  }
  # Изменение настроек
  change_settings
  change_rpc
  # Запуск Docker Compose
  docker compose -f "$HOME/unichain-node/docker-compose.yml" up -d || {
    echo "Ошибка при запуске Docker Compose!"; exit 1;
  }
  echo "Установка выполнена успешно!"
}

# Функция обновления узла до mainnet
update_node_to_mainnet() {
  if [ -d $HOME/unichain-node ]; then
    echo "Обновление до mainnet"
    # Делаем бекап приватного ключа
    if [ -f $HOME/unichain-node/geth-data/geth/nodekey ]; then
      cp $HOME/unichain-node/geth-data/geth/nodekey ~/unichain-nodekey-backup
    else
      echo "Приватный ключ не найден!"
      exit 0
    fi
    # Удаляем ноду
    delete_node
    # Скачиваем директорию проекта
    git clone https://github.com/Uniswap/unichain-node || {
      echo "Ошибка при клонировании репозитория!"; exit 0;
    }
    # Вносим необходимые изменения в файлы проекта
    change_settings
    change_rpc
    # Запускаем узел для инициализации необходимых файлов
    docker compose -f $HOME/unichain-node/docker-compose.yml up -d
    # Выключаем узел для внесения изменений
    docker compose -f $HOME/unichain-node/docker-compose.yml down --volumes
    # Удаляем старый ключ и восстанавливаем новый
    rm $HOME/unichain-node/geth-data/geth/nodekey  
    cp ~/unichain-nodekey-backup $HOME/unichain-node/geth-data/geth/nodekey
    # Запускаем узел
    docker compose -f $HOME/unichain-node/docker-compose.yml up -d
    echo ''
    echo 'Поздравляю с запуском MAINNET UNICHAIN NODE!'
  else
    echo 'Проект не запущен, установите его!'
  fi
}

# Функция обновления узла
update_node() {
  echo "Обновление узла (op-node:v1.11.1-rc.1)..."
  cd ~/unichain-node
  git stash && git pull
  change_settings
  change_rpc
  docker compose -f $HOME/unichain-node/docker-compose.yml down && \
  docker compose -f $HOME/unichain-node/docker-compose.yml up -d || {
    echo "Ошибка при запуске Docker Compose!"; exit 0;
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
  docker compose -f $HOME/unichain-node/docker-compose.yml logs -f --tail 20
}

# Функция вывода приватного ключа
show_private_key() {
  echo "Вывод приватного ключа..."
  if [ -f $HOME/unichain-node/geth-data/geth/nodekey ]; then
    echo ''
    cat $HOME/unichain-node/geth-data/geth/nodekey
    echo ''
  else
    echo "Приватный ключ не найден!"
  fi
}

# Функция удаления ноды
delete_node() {
  echo "Удаление ноды..."
  docker compose -f $HOME/unichain-node/docker-compose.yml down --volumes
  rm -rf ~/unichain-node
  echo "Нода успешно удалена."
}

# Функция для отображения меню
show_menu() {
  echo ""
  echo "Выберите действие:"
  echo "1. Установка ноды (mainnet)"
  echo "2. Обновление узла (15.02.2025)"
  echo "3. Тестовый запрос"
  echo "4. Логи ноды"
  echo "7. Переход с testnet в mainnet"
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
    7) update_node_to_mainnet ;;
    8) show_private_key ;;
    9) delete_node ;;
    0) echo "Выход."; break ;;
    *) echo "Неверный выбор, попробуйте снова." ;;
  esac
done
