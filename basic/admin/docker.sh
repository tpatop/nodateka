#!/bin/bash

# Функция для установки или обновления Docker
install_or_update_docker() {
  echo "Обновляю список пакетов..."
  sudo apt update

  if ! command -v docker &> /dev/null; then
    echo "Docker не найден. Устанавливаю Docker..."
    sudo apt install -y ca-certificates curl gnupg lsb-release
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  fi
  
  echo "Обновляю Docker до последней стабильной версии..."
  sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io
  sudo usermod -aG docker $USER
#  newgrp docker
  docker version
  echo "Docker успешно установлен или обновлен."
}

# Функция для установки или обновления Docker Compose
install_or_update_docker_compose() {
  echo "Обновляю Docker Compose..."
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
  echo "Docker Compose успешно установлен или обновлен."
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

install_or_update_docker
install_or_update_docker_compose
check_docker_daemon
# Перезапуск всех упавших контейнеров
sleep 2
docker ps -a --filter "status=exited" --format "{{.ID}}" | xargs -r docker restart
echo 'Скрипт выполнен!'