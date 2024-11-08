#!/bin/bash

# Функция для установки Docker
install_docker() {
  echo "Docker не найден. Устанавливаю Docker..."
  sudo apt install -y ca-certificates curl gnupg lsb-release
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io
  sudo usermod -aG docker $USER
  newgrp docker
  docker version
  echo "Docker успешно установлен."
}

# Функция для установки Docker Compose
install_docker_compose() {
  echo "Docker Compose не найден. Устанавливаю docker-compose и docker compose (plugin)..."

  VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
  
  # Установка бинарной версии docker-compose
  sudo curl -L "https://github.com/docker/compose/releases/download/${VER}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose

  # Установка плагина docker compose
  DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
  mkdir -p $DOCKER_CONFIG/cli-plugins
  sudo curl -SL "https://github.com/docker/compose/releases/download/${VER}/docker-compose-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)" -o $DOCKER_CONFIG/cli-plugins/docker-compose
  sudo chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose

  docker-compose version
  docker compose version
  echo "docker-compose и docker compose (plugin) установлены."
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
