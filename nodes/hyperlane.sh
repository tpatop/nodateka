#!/bin/bash

# Вывод логотипа
bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/name.sh)

# Функция для сохранения переменной в .bashrc
save_to_bashrc() {
    local var_name="$1"
    local var_value="$2"
    
    echo "export $var_name=\"$var_value\"" >> ~/.bashrc
    echo "$var_name сохранён в .bashrc"
}

# Группировка сетей по типу
declare -A NETWORK_TYPES
NETWORK_TYPES["EVM"]="abstracttestnet alephzeroevmmainnet alephzeroevmtestnet alfajores \
    ancient8 apechain arbitrum arbitrumnova arbitrumsepolia artelatestnet arthera artheratestnet \
    astar astarzkevm avalanche blast blastsepolia boba bobabnb bobabnbtestnet bsc bsctestnet \
    canto cantotestnet celo confluxespace cronos cronoszkevm dogechain duckchain eclipsemainnet \
    eclipsetestnet ethereum flare harmony harmonytestnet immutablezkevmmainnet kalychain kroma \
    linea lisk lukso mantle metal metis mode moonbeam moonriver optimism polygon polygonzkevm \
    scroll shibarium taiko treasuretopaz zoramainnet"
NETWORK_TYPES["SOLANA"]="solanadevnet solanamainnet solanatestnet"
NETWORK_TYPES["COSMOS"]="cosmoshub injective neutron osmosis sei stride"

# Выбор типа сети
echo "Выберите тип сети:"
select NETWORK_TYPE in "${!NETWORK_TYPES[@]}"; do
    if [[ -n "$NETWORK_TYPE" ]]; then
        echo "Вы выбрали тип сети: $NETWORK_TYPE"
        break
    else
        echo "Неверный выбор. Попробуйте снова."
    fi
done

# Получаем список сетей для выбранного типа
AVAILABLE_NETWORKS=(${NETWORK_TYPES["$NETWORK_TYPE"]})

# Выбор конкретной сети
echo "Выберите сеть из списка:"
select TARGET_CHAIN in "${AVAILABLE_NETWORKS[@]}"; do
    if [[ -n "$TARGET_CHAIN" ]]; then
        echo "Вы выбрали сеть: $TARGET_CHAIN"
        break
    else
        echo "Неверный выбор. Попробуйте снова."
    fi
done

# Загрузка переменных из .bashrc
source ~/.bashrc

# Проверка и запрос HYPERLANE_PRIVATE_KEY
KEY_VAR="HYPERLANE_PRIVATE_KEY_${NETWORK_TYPE}"
if [ -z "${!KEY_VAR}" ]; then
    echo "Переменная $KEY_VAR не установлена."
    read -p "Введите значение для $KEY_VAR: " input_key
    if [ -z "$input_key" ]; then
        echo "Ошибка: $KEY_VAR не может быть пустым."
        exit 1
    fi
    export $KEY_VAR="$input_key"
    save_to_bashrc "$KEY_VAR" "$input_key"
else
    echo "$KEY_VAR загружен из окружения."
fi

# Проверка и запрос HYPERLANE_VALIDATOR_NAME
if [ -z "$HYPERLANE_VALIDATOR_NAME" ]; then
    echo "Переменная HYPERLANE_VALIDATOR_NAME не установлена."
    read -p "Введите значение для HYPERLANE_VALIDATOR_NAME: " input_name
    if [ -z "$input_name" ]; then
        echo "Ошибка: HYPERLANE_VALIDATOR_NAME не может быть пустым."
        exit 1
    fi
    export HYPERLANE_VALIDATOR_NAME="$input_name"
    save_to_bashrc "HYPERLANE_VALIDATOR_NAME" "$input_name"
else
    echo "HYPERLANE_VALIDATOR_NAME загружен из окружения."
fi

# Применение изменений из .bashrc
source ~/.bashrc

echo "Все переменные окружения успешно загружены:"
echo "$KEY_VAR=${!KEY_VAR}"
echo "HYPERLANE_VALIDATOR_NAME=$HYPERLANE_VALIDATOR_NAME"


# Создание базовой директории
mkdir -p ~/hyperlane && cd ~/hyperlane

# Создание директории для базы данных и установка прав доступа
mkdir -p "$TARGET_CHAIN/hyperlane_db"
chmod -R 777 "$TARGET_CHAIN/hyperlane_db"

# URL к YAML-файлу
BASE_URL="https://raw.githubusercontent.com/hyperlane-xyz/hyperlane-registry/refs/heads/main/chains"
YAML_URL="${BASE_URL}/${TARGET_CHAIN}/metadata.yaml"
YAML_FILE="${TARGET_CHAIN}_metadata.yaml"

# Скачивание YAML-файла
echo "Загружаем YAML-файл с $YAML_URL..."
if ! curl -s -o "$YAML_FILE" "$YAML_URL"; then
    echo "Ошибка: не удалось скачать YAML-файл!"
    exit 1
fi
echo "YAML-файл успешно загружен: $YAML_FILE"

# Установка jq и yq, если их нет
if ! command -v jq &>/dev/null; then
    echo "jq is not installed. Installing..."
    sudo apt-get install -y jq
fi

if ! command -v yq &>/dev/null; then
    echo "yq is not installed. Installing..."
    pip install yq
fi

# Извлечение данных из YAML
RPC_URLS=$(yq '.rpcUrls' "$YAML_FILE" | jq -r 'if type == "array" then map(.http) | join(",") elif type == "object" then .[].http else "" end')

REORG_PERIOD=$(yq '.blocks.reorgPeriod' "$YAML_FILE")

if [ -z "$RPC_URLS" ] || [ -z "$REORG_PERIOD" ]; then
    echo "Failed to extract required fields from $YAML_FILE"
    exit 1
fi

rm "$YAML_FILE"

# Проверка и замена порта, если он занят
DEFAULT_PORT=9090
HOST_PORT=9091

while netstat -tuln | grep -q ":$HOST_PORT"; do
    echo "Port $HOST_PORT is occupied. Trying the next port..."
    HOST_PORT=$((HOST_PORT + 1))
done

echo "Using port $HOST_PORT"

# Подготовка Docker команды
DOCKER_IMAGE="gcr.io/abacus-labs-dev/hyperlane-agent:main"
DOCKER_NAME="hyperlane-$TARGET_CHAIN"

docker run -d -it \
    --name "$DOCKER_NAME" \
    --mount type=bind,source=$(pwd)/"$TARGET_CHAIN"/hyperlane_db,target=/hyperlane_db \
    -p "$HOST_PORT:$DEFAULT_PORT" \
    --restart always \
    "$DOCKER_IMAGE" \
    ./validator \
    --db /hyperlane_db \
    --originChainName "$TARGET_CHAIN" \
    --reorgPeriod "$REORG_PERIOD" \
    --validator.id "$HYPERLANE_VALIDATOR_NAME" \
    --checkpointSyncer.type localStorage \
    --checkpointSyncer.folder "$TARGET_CHAIN" \
    --checkpointSyncer.path /hyperlane_db/checkpoints \
    --validator.key "${!KEY_VAR}" \
    --chains."$TARGET_CHAIN".signer.key "${!KEY_VAR}" \
    --chains."$TARGET_CHAIN".customRpcUrls "$RPC_URLS"

echo "Docker container $DOCKER_NAME started on port $HOST_PORT"
