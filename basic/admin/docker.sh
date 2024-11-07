#!/bin/bash

# Функция для установки Docker
install_docker() {
  echo "Docker не найден. Устанавливаю Docker..."
  sudo apt update
  sudo apt install -y docker.io
  sudo systemctl start docker
  sudo systemctl enable docker
  echo "Docker успешно установлен."
}

# Функция для установки Docker Compose
install_docker_compose() {
  echo "Docker Compose не найден. Устанавливаю Docker Compose..."
  sudo apt update
  sudo apt install -y docker-compose-plugin
  echo "Docker Compose успешно установлен."
}

# Функция для проверки и включения Docker демона
check_docker_daemon() {
  if ! sudo systemctl is-active --quiet docker; then
    echo "Docker демон отключен. Включаю Docker..."
    sudo systemctl start docker
    echo "Docker демон успешно запущен."
  else
    echo "Docker демон уже запущен."
  fi
}

# Проверка наличия Docker
if ! command -v docker &> /dev/null; then
  install_docker
else
  echo "Docker уже установлен."
fi

# Проверка наличия Docker Compose
if ! docker compose version &> /dev/null; then
  install_docker_compose
else
  echo "Docker Compose уже установлен."
fi

check_docker_daemon
