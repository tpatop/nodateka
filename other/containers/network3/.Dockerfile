# Используем базовый образ Ubuntu
FROM ubuntu:latest

# Установить net-tools и wget
RUN apt update && apt install -y net-tools wget

# Скачиваем архив и распаковываем его
WORKDIR /root
RUN wget https://network3.io/ubuntu-node-v2.1.0.tar && \
    tar -xvf ubuntu-node-v2.1.0.tar && \
    rm ubuntu-node-v2.1.0.tar

# Переходим в папку ubuntu-node
WORKDIR /root/ubuntu-node

# Команда для запуска
CMD ["bash", "-c", "./manager.sh up && ./manager.sh key > /root/ubuntu-node/key_output.txt && tail -f /dev/null"]
