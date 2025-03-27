#!/bin/bash

confirm() {
    local prompt="$1"
    read -p "$prompt [y/n, Enter = yes]: " choice
    case "$choice" in
        ""|y|Y|yes|Yes) return 0 ;;
        n|N|no|No) return 1 ;;
        *) echo "Пожалуйста, введите y или n."; confirm "$prompt" ;;
    esac
}

set_iptables_rules() {
    echo "Очистка всех существующих правил OUTPUT"
    iptables -F OUTPUT

    # Разрешить локальный трафик и Docker
    iptables -A OUTPUT -d 127.0.0.1/8 -j ACCEPT
    for i in $(seq 17 40); do
        iptables -A OUTPUT -d 172.$i.0.0/16 -j ACCEPT
    done

    # Разрешить публичный интернет (но блокировать частные сети)
    iptables -A OUTPUT -j ACCEPT  # Разрешаем всё, кроме запрещённого ниже

    # Блокировка частных подсетей (исходящие)
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
    echo "Исходящий трафик в частные сети заблокирован!"
}

if confirm "Блокировать исходящий трафик в частные сети?"; then
    set_iptables_rules
else
    echo "Отменено"
fi
