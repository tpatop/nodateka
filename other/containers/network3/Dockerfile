# Используем базовый образ Ubuntu
FROM ubuntu:latest

# Установить net-tools, wget, iproute2 и iptables
RUN apt update && apt install -y net-tools wget iproute2 iptables

# Скачиваем архив и распаковываем его
WORKDIR /root
RUN wget https://network3.io/ubuntu-node-v2.1.0.tar && \
    tar -xvf ubuntu-node-v2.1.0.tar && \
    rm ubuntu-node-v2.1.0.tar

# Переходим в папку ubuntu-node
WORKDIR /root/ubuntu-node

# Команда для запуска и удержания контейнера активным
CMD ["bash", "-c", "./manager.sh up && tail -f /dev/null"]
