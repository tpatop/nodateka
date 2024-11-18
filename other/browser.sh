#!/bin/bash

# Логотип команды
bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/name.sh)

# Вызов скрипта для проверки и установки Docker и Docker Compose
bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/admin/docker.sh)

# Функция для вывода ошибок
error() {
  echo -e "\e[31m[ERROR]\e[0m $1"
}

# Функция для вывода информации
show() {
  echo -e "\e[32m[INFO]\e[0m $1"
}

sudo apt install redsocks iptables -y 

# Запрашиваем имя пользователя
read -p "Введите имя пользователя: " USERNAME
if [[ -z "$USERNAME" ]]; then
  error "Имя пользователя не может быть пустым."
  exit 1
fi

# Запрашиваем пароль с подтверждением
read -s -p "Введите пароль: " PASSWORD
echo
read -s -p "Подтвердите пароль: " PASSWORD_CONFIRM
echo

if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
  error "Пароли не совпадают. Пожалуйста, запустите скрипт заново и введите пароли правильно."
  exit 1
fi

# Сохранение учетных данных
CREDENTIALS_FILE="$HOME/vps-browser-credentials.json"
cat <<EOL > "$CREDENTIALS_FILE"
{
  "username": "$USERNAME",
  "password": "$PASSWORD"
}
EOL
chmod 600 "$CREDENTIALS_FILE"

# Читаем прокси из файла
PROXY_FILE="proxy.txt"
if [[ ! -f $PROXY_FILE ]]; then
  error "Файл proxy.txt не найден!"
  exit 1
fi

# Счетчик контейнеров и начальные порты
container_count=1
start_local_port=12000

while read -r proxy; do
  [[ -z "$proxy" ]] && continue

  IFS=':' read -r proxy_type proxy_ip proxy_port proxy_username proxy_password <<< "$proxy"
  proxy_ip=$(echo "$proxy_ip" | sed 's#^//##')
  container_name="chromium_container_$container_count"
  local_port=$((start_local_port + container_count - 1))

  # Создаем уникальную конфигурационную папку для каждого контейнера
  CONFIG_DIR="$HOME/chromium/config_$container_name"
  mkdir -p "$CONFIG_DIR"

  # Создаем индивидуальный redsocks.conf
  REDSOCKS_CONF="$HOME/redsocks_$container_name.conf"
  cat <<EOL > "$REDSOCKS_CONF"
base {
    log_debug = off;
    log_info = on;
    log = "file:/var/log/redsocks.log";
    daemon = on;
    redirector = iptables;
}

redsocks {
    local_ip = 127.0.0.1;
    local_port = $local_port;
    ip = $proxy_ip;
    port = $proxy_port;
    type = $proxy_type;
EOL

  [[ -n "$proxy_username" ]] && echo "    login = \"$proxy_username\";" >> "$REDSOCKS_CONF"
  [[ -n "$proxy_password" ]] && echo "    password = \"$proxy_password\";" >> "$REDSOCKS_CONF"
  echo "}" >> "$REDSOCKS_CONF"

  if [[ $? -ne 0 ]]; then
    error "Не удалось создать файл конфигурации $REDSOCKS_CONF"
    exit 1
  fi

  # Запуск контейнера
  show "Запуск контейнера $container_name..."
  docker run -d --name "$container_name" \
    --privileged \
    --network host \
    -e TITLE=Nodateka \
    -e DISPLAY=:1 \
    -e PASSWORD="$PASSWORD" \
    -v "$CONFIG_DIR:/config" \
    --shm-size="2gb" \
    --restart unless-stopped \
    lscr.io/linuxserver/chromium:latest

  if [[ $? -eq 0 ]]; then
    show "Контейнер $container_name успешно запущен."
  else
    error "Не удалось запустить контейнер $container_name."
    exit 1
  fi

  # Настройка iptables внутри контейнера
  show "Добавление правила iptables в контейнер $container_name"
  docker exec "$container_name" iptables -t nat -A OUTPUT -p tcp -j REDIRECT --to-ports "$local_port"
  if [[ $? -eq 0 ]]; then
    show "Правило iptables для контейнера $container_name успешно добавлено."
  else
    error "Не удалось добавить правило iptables для контейнера $container_name."
    exit 1
  fi

  container_count=$((container_count + 1))

  # Запуск redsocks на хосте
  show "Запуск redsocks на хосте для контейнера $container_name"
  sudo redsocks -c "$REDSOCKS_CONF" &
  if [[ $? -eq 0 ]]; then
    show "Redsocks успешно запущен на хосте для контейнера $container_name."
  else
    error "Не удалось запустить redsocks на хосте для контейнера $container_name."
    exit 1
  fi

  # Вывод информации о подключении
  show "Откройте этот адрес http://$(hostname -I | awk '{print $1}'):$local_port/ для запуска браузера извне"

done < "$PROXY_FILE"
