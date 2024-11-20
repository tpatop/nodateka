Создание и обновление образа
```
docker build -t chromium-proxy .
```

Запуск контейнера
```
docker run -d --name "$container_name" \
    --privileged \
    -e TITLE="Tpatop (team: Nodateka)" \
    -e DISPLAY=:1 \
    -e PUID=1000 \
    -e PGID=1000 \
    -e CUSTOM_USER=user \
    -e PASSWORD=password \
    -e LANGUAGE=en_US.UTF-8 \
    -v "$HOME/chromium/config_$i:/config" \
    -p 11111:3000 \
    --shm-size="2gb" \
    --restart unless-stopped \
    chromium-proxy
```