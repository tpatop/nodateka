#!/bin/bash

# Функция для сохранения переменной в .bashrc
save_to_bashrc() {
    local var_name="$1"
    local var_value="$2"
    
    echo "export $var_name=\"$var_value\"" >> ~/.bashrc
    echo "$var_name сохранён в .bashrc"
}

# Проверка и запрос HYPERLANE_PRIVATE_KEY
if [ -z "$HYPERLANE_PRIVATE_KEY" ]; then
    echo "Переменная HYPERLANE_PRIVATE_KEY не установлена."
    read -p "Введите значение для HYPERLANE_PRIVATE_KEY: " input_key
    if [ -z "$input_key" ]; then
        echo "Ошибка: HYPERLANE_PRIVATE_KEY не может быть пустым."
        exit 1
    fi
    export HYPERLANE_PRIVATE_KEY="$input_key"
    save_to_bashrc "HYPERLANE_PRIVATE_KEY" "$input_key"
else
    echo "HYPERLANE_PRIVATE_KEY загружен из окружения."
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
echo "HYPERLANE_PRIVATE_KEY=$HYPERLANE_PRIVATE_KEY"
echo "HYPERLANE_VALIDATOR_NAME=$HYPERLANE_VALIDATOR_NAME"

# Список доступных сетей
NETWORKS=(
    abstracttestnet alephzeroevmmainnet alephzeroevmtestnet alfajores ancient8 apechain arbitrum arbitrumnova arbitrumsepolia
    arcadiatestnet2 artelatestnet arthera artheratestnet astar astarzkevm auroratestnet avalanche b3 base basesepolia
    berabartio bitlayer blast blastsepolia bob boba bobabnb bobabnbtestnet bsc bsctestnet bsquared camptestnet canto
    cantotestnet carbon celo cheesechain chilizmainnet citreatestnet clique confluxespace connextsepolia coredao cosmoshub
    cronos cronoszkevm cyber deepbrainchaintestnet degenchain deprecatedalephzeroevm deprecatedchiliz deprecatedflow
    deprecatedimmutablezkevm deprecatedmetall2 deprecatedpolynomial deprecatedrari deprecatedrootstock deprecatedsuperposition
    dodotestnet dogechain duckchain ebi eclipsemainnet eclipsetestnet ecotestnet endurance ethereum euphoriatestnet everclear
    fantom fhenixtestnet filecoin flame flare flowmainnet forma formtestnet fractalconfluence fraxtal fraxtaltestnet fuji funki
    fusemainnet galadrieldevnet gnosis gravity ham harmony harmonytestnet heneztestnet holesky humanitytestnet
    hyperliquidevmtestnet immutablezkevmmainnet inevm injective inksepolia kaia kalychain kava kinto koitestnet kroma linea
    lisk lisksepolia lukso luksotestnet lumia lumiaprism mantapacific mantapacifictestnet mantle mantlesepolia merlin metal
    metall2testnet metertestnet metis mevmdevnet mint mintsepoliatest mode modetestnet molten moonbase moonbeam moonriver
    morph nautilus neoxt4 neutron odysseytestnet oortmainnet opbnb opbnbtestnet optimism optimismsepolia orderly osmosis
    piccadilly plumetestnet polygon polygonamoy polygonzkevm polynomialfi prom proofofplay pulsechain rarichain
    reactivekopli real redstone ronin rootstockmainnet rootstocktestnet saakuru sanko scroll scrollsepolia sei sepolia
    shibarium sketchpad smartbch snaxchain solanadevnet solanamainnet solanatestnet soneiumtestnet sonictestnet sophonsepolia
    storyodysseytestnet storytestnet stride stridetestnet suavetoliman superpositionmainnet superpositiontestnet superseed
    superseedtestnet swell taiko taikohekla tangle tangletestnet tenet treasuretopaz u2utestnet unichain unichaintestnet
    vana viction wanchaintestnet worldchain xai xlayer zeronetwork zetachain zircuit zksync zksyncsepolia zoramainnet
    zoratestnet
)

echo "Выберите сеть из списка:"
select TARGET_CHAIN in "${NETWORKS[@]}"; do
    if [[ -n "$TARGET_CHAIN" ]]; then
        echo "Вы выбрали сеть: $TARGET_CHAIN"
        break
    else
        echo "Неверный выбор. Попробуйте снова."
    fi
done

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
    --validator.key "$HYPERLANE_PRIVATE_KEY" \
    --chains."$TARGET_CHAIN".signer.key "$HYPERLANE_PRIVATE_KEY" \
    --chains."$TARGET_CHAIN".customRpcUrls "$RPC_URLS"

echo "Docker container $DOCKER_NAME started on port $HOST_PORT"
