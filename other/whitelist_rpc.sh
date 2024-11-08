#!/bin/bash

# Путь к файлу со списком белых IP-адресов (1 строка - 1 IP)
WHITE_IP_FILE="whitelist.txt"

# Порт, который нужно защитить
PORT=8545

# Функция для подтверждения действия
confirm() {
    local prompt="$1"
    read -p "$prompt [y/n]: " choice
    if [[ -z "$choice" || "$choice" == "y" ]]; then
        return 0  # Выполнить действие
    else
        return 1  # Пропустить действие
    fi
}

# Проверяем наличие файла
if [ ! -f "$WHITE_IP_FILE" ]; then
    echo "Файл $WHITE_IP_FILE не найден!"
    exit 1
fi

# Очистка всех правил в таблице INPUT
echo "Очищаю текущие правила..."
sudo iptables -F INPUT

# Разрешение доступа для каждого IP из белого списка
echo "Добавляю правила для белого списка IP..."
while IFS= read -r ip; do
    if [[ ! -z "$ip" && ! "$ip" =~ ^# ]]; then
        echo "Разрешаю доступ для IP: $ip"
        sudo iptables -A INPUT -p tcp --dport $PORT -s "$ip" -j ACCEPT
    fi
done < "$WHITE_IP_FILE"

# Запрет доступа для всех остальных
echo "Запрещаю доступ для всех остальных..."
sudo iptables -A INPUT -p tcp --dport $PORT -j DROP

# Запрос на вывод текущих правил
if confirm "Вы хотите увидеть текущие правила для цепочки INPUT?"; then
    echo "Текущие правила в цепочке INPUT:"
    sudo iptables -L INPUT -v -n
fi

# Сохранение правил
echo "Сохраняю текущие правила iptables..."
sudo iptables-save > /etc/iptables/rules.v4

echo "Настройка завершена."
