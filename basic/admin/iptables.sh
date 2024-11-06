#!/bin/bash

echo "Очистка всех существующих правил OUTPUT"
iptables -F OUTPUT

# echo "Разрешение трафика к 127.0.0.1"
# iptables -A OUTPUT -d 127.0.0.1/8 -j ACCEPT

echo "Разрешение исходящего трафика в диапазоне Docker от 172.17.0.0/16 до 172.40.0.0/16"
for i in $(seq 17 40); do
    iptables -A OUTPUT -d 172.$i.0.0/16 -j ACCEPT
    iptables -A INPUT -s 172.$i.0.0/16 -j ACCEPT
done
sleep 2

echo "Добавление блокирующих правил"
iptables -A OUTPUT -d 10.0.0.0/8 -j DROP
iptables -A OUTPUT -d 100.64.0.0/10 -j DROP
iptables -A OUTPUT -d 169.254.0.0/16 -j DROP
iptables -A OUTPUT -d 172.16.0.0/12 -j DROP
iptables -A OUTPUT -d 192.0.0.0/24 -j DROP
iptables -A OUTPUT -d 192.0.2.0/24 -j DROP
iptables -A OUTPUT -d 192.88.99.0/24 -j DROP
iptables -A OUTPUT -d 192.168.0.0/16 -j DROP
iptables -A OUTPUT -d 198.18.0.0/15 -j DROP
iptables -A OUTPUT -d 198.51.100.0/24 -j DROP
iptables -A OUTPUT -d 203.0.113.0/24 -j DROP
iptables -A OUTPUT -d 224.0.0.0/4 -j DROP
iptables -A OUTPUT -d 240.0.0.0/4 -j DROP

sudo iptables-save

echo "Блокирующие правила успешно применены!"
