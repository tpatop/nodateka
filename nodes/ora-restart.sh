#!/bin/bash

# Проверка, запущен ли контейнер ora-tora
if [ "$(docker inspect -f '{{.State.Running}}' ora-tora)" == "false" ]; then
    echo "$(date): Ora-tora упал, выполняется перезапуск..." >> ~/tora/restart.log
    docker start ora-tora
    echo "$(date): Ora-tora успешно перезапущен." >> ~/tora/restart.log
else
    echo "$(date): Ora-tora работает корректно." >> ~/tora/restart.log
fi
