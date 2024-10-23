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
  sudo apt-get update
  sudo apt-get install -y docker-compose-plugin
  echo "Docker Compose успешно установлен."
}

# Проверка наличия Docker
if ! command -v docker &> /dev/null; then
  install_docker
else
  echo "Docker уже установлен."
fi

# Проверка наличия Docker Compose
if ! command -v docker compose &> /dev/null; then
  install_docker_compose
else
  echo "Docker Compose уже установлен."
fi
