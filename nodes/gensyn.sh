#!/bin/bash

NODE_DIR="$HOME/rl-swarm"
DOCKER_COMPOSE_FILE="$NODE_DIR/docker-compose.yaml"

find_free_port() {
    local port=8080
    while ss -tuln | grep -q ":$port " ; do
        ((port++))
    done
    echo $port
}

install_node() {
    echo "Выберите режим работы:"
    echo "1) С GPU"
    echo "2) Без GPU"
    read -p "Введите номер режима: " MODE
    
    # Установка логотипа
    bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/name.sh)
    
    # Установка Docker
    bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/admin/docker.sh)
    
    sudo apt-get update && sudo apt-get upgrade -y
    sudo apt install -y curl iptables build-essential git wget lz4 jq make gcc nano \
                        automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev \
                        libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev
    
    git clone https://github.com/gensyn-ai/rl-swarm.git $NODE_DIR
    cd $NODE_DIR || { echo "Ошибка: директория $NODE_DIR не найдена."; return; }
    
    FREE_PORT=$(find_free_port)
    echo "Используем свободный порт: $FREE_PORT"
    
    cat > $DOCKER_COMPOSE_FILE <<EOF
version: '3'

services:
  otel-collector:
    image: otel/opentelemetry-collector-contrib:0.120.0
    ports:
      - "4317:4317"
      - "4318:4318"
      - "55679:55679"
    environment:
      - OTEL_LOG_LEVEL=DEBUG

  swarm_node:
    image: europe-docker.pkg.dev/gensyn-public-b7d9/public/rl-swarm:v0.0.2
    command: ./run_hivemind_docker.sh
EOF

    if [ "$MODE" == "1" ]; then
        echo "    runtime: nvidia" >> $DOCKER_COMPOSE_FILE
    fi

    cat >> $DOCKER_COMPOSE_FILE <<EOF
    environment:
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
      - PEER_MULTI_ADDRS=/ip4/38.101.215.13/tcp/30002/p2p/QmQ2gEXoPJg6iMBSUFWGzAabS2VhnzuS782Y637hGjfsRJ
      - HOST_MULTI_ADDRS=/ip4/0.0.0.0/tcp/38331
    ports:
      - "38331:38331"
    depends_on:
      - otel-collector

  fastapi:
    build:
      context: .
      dockerfile: Dockerfile.webserver
    environment:
      - OTEL_SERVICE_NAME=rlswarm-fastapi
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
      - INITIAL_PEERS=/ip4/38.101.215.13/tcp/30002/p2p/QmQ2gEXoPJg6iMBSUFWGzAabS2VhnzuS782Y637hGjfsRJ
    ports:
      - "${FREE_PORT}:8000"
    depends_on:
      - otel-collector
      - swarm_node
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/api/healthz"]
      interval: 30s
      retries: 3
EOF

    docker compose up --build -d
    echo "Нода успешно установлена и запущена на порту $FREE_PORT."
}

view_logs() {
    [ -d "$NODE_DIR" ] || { echo "Ошибка: директория $NODE_DIR не найдена."; return; }
    cd $NODE_DIR
    docker-compose logs -f swarm_node
}

status_containers() {
    [ -d "$NODE_DIR" ] || { echo "Ошибка: директория $NODE_DIR не найдена."; return; }
    cd $NODE_DIR
    docker-compose ps
}

delete_node() {
    [ -d "$NODE_DIR" ] || { echo "Ошибка: директория $NODE_DIR не найдена."; return; }
    cd $NODE_DIR
    docker compose down
    rm -rf $NODE_DIR
    echo "Нода удалена."
}

while true; do
    echo "\nВыберите действие:"
    echo "1) Установить ноду"
    echo "2) Посмотреть логи"
    echo "3) Статус контейнеров"
    echo "4) Удалить ноду"
    echo "0) Выйти из скрипта"
    read -p "Введите номер действия: " ACTION

    case $ACTION in
        1) install_node ;;
        2) view_logs ;;
        3) status_containers ;;
        4) delete_node ;;
        0) echo "Выход..."; exit 0 ;;
        *) echo "Неверный ввод. Попробуйте снова." ;;
    esac
done
