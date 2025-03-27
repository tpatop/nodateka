#!/bin/bash

# Функция для подтверждения выбора пользователя
confirm() {
    local prompt="$1"
    read -p "$prompt [y/n, Enter = yes]: " choice
    case "$choice" in
        ""|y|Y|yes|Yes)  # Пустой ввод или "да"
            return 0  # Подтверждение действия
            ;;
        n|N|no|No)  # Любой вариант "нет"
            return 1  # Отказ от действия
            ;;
        *)
            echo "Пожалуйста, введите y или n."
            confirm "$prompt"  # Повторный запрос, если ответ не распознан
            ;;
    esac
}

set_iptables_rules() {
    # Определяем внешний интерфейс (может потребоваться изменить под вашу систему)
    EXT_IF=$(ip route | grep default | awk '{print $5}' | head -n1)
    if [ -z "$EXT_IF" ]; then
        echo "Не удалось определить внешний интерфейс!"
        exit 1
    fi
    
    echo "Внешний интерфейс определен как: $EXT_IF"
    
    echo "Очистка существующих правил FORWARD и INPUT (осторожно!)"
    iptables -F FORWARD
    iptables -F INPUT

    # Разрешаем локальный трафик
    echo "Разрешение локального трафика"
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -i docker0 -j ACCEPT

    # Разрешаем связанные/установленные соединения
    echo "Разрешение связанных соединений"
    iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

    echo "Разрешение входящего трафика в диапазоне Docker от 172.17.0.0/16 до 172.40.0.0/16"
    for i in $(seq 17 40); do
        iptables -A INPUT -s 172.$i.0.0/16 -j ACCEPT
    done
    sleep 1

    echo "Добавление блокирующих правил для внешнего интерфейса $EXT_IF"
    iptables -A INPUT -i $EXT_IF -d 10.0.0.0/8 -j DROP
    iptables -A INPUT -i $EXT_IF -d 100.64.0.0/10 -j DROP
    iptables -A INPUT -i $EXT_IF -d 169.254.0.0/16 -j DROP
    iptables -A INPUT -i $EXT_IF -d 172.16.0.0/12 -j DROP
    iptables -A INPUT -i $EXT_IF -d 192.0.0.0/24 -j DROP
    iptables -A INPUT -i $EXT_IF -d 192.0.2.0/24 -j DROP
    iptables -A INPUT -i $EXT_IF -d 192.88.99.0/24 -j DROP
    iptables -A INPUT -i $EXT_IF -d 192.168.0.0/16 -j DROP
    iptables -A INPUT -i $EXT_IF -d 198.18.0.0/15 -j DROP
    iptables -A INPUT -i $EXT_IF -d 198.51.100.0/24 -j DROP
    iptables -A INPUT -i $EXT_IF -d 203.0.113.0/24 -j DROP
    iptables -A INPUT -i $EXT_IF -d 224.0.0.0/4 -j DROP
    iptables -A INPUT -i $EXT_IF -d 240.0.0.0/4 -j DROP

    # Разрешаем ICMP (ping) - рекомендуется для диагностики
    echo "Разрешение ICMP (ping) запросов"
    iptables -A INPUT -i $EXT_IF -p icmp -j ACCEPT

    sudo iptables-save

    echo "Блокирующие правила для внешнего интерфейса успешно применены!"
}

if confirm "Будет произведена очистка существующих правил INPUT/FORWARD и добавление новых, согласны?"; then
    set_iptables_rules
else
    echo "Отменено"
fi
