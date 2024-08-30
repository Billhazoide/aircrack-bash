#!/bin/bash

WORDLIST_FILE="wordlist.txt"

# Função para encontrar a interface de rede Wi-Fi
find_wifi_interface() {
    local wifi_interface=$(iw dev | grep Interface | awk '{print $2}')
    if [ -z "$wifi_interface" ]; then
        echo "Nenhuma interface Wi-Fi encontrada."
sleep 5
        exit 1
    fi
    echo "$wifi_interface"
}

# Detecta a interface Wi-Fi
INTERFACE=$(find_wifi_interface)
MONITOR_INTERFACE="${INTERFACE}mon"

echo "Interface Wi-Fi detectada: $INTERFACE"
echo "Interface em modo monitor: $MONITOR_INTERFACE"
echo "Iniciando monitoramento..."

sleep 5
# Verifica se o aircrack-ng está instalado
if ! command -v aircrack-ng &> /dev/null; then
    echo "aircrack-ng não está instalado. Instale o aircrack-ng e tente novamente."
sleep 5
    exit 1
fi

# Verifica se o airmon-ng está instalado
if ! command -v airmon-ng &> /dev/null; then
    echo "airmon-ng não está instalado. Instale o aircrack-ng e tente novamente."
sleep 5
    exit 1
fi

# Verifica se o airodump-ng está instalado
if ! command -v airodump-ng &> /dev/null; then
    echo "airodump-ng não está instalado. Instale o aircrack-ng e tente novamente."
sleep 5
    exit 1
fi

# Coloca a interface em modo monitor
echo "Colocando a interface '$INTERFACE' em modo monitor..."
sleep 5
sudo airmon-ng start "$INTERFACE"

# Verifica se a interface foi criada corretamente
if [ ! -d "/sys/class/net/$MONITOR_INTERFACE" ]; then
    echo "A interface '$MONITOR_INTERFACE' não foi criada. Verifique se o adaptador é compatível."
sleep 5
    exit 1
fi

# Função para capturar pacotes de uma rede específica
capture_network() {
    local network_name="$1"
    local sanitized_name=$(echo "$network_name" | tr -d '[:space:]')   # Remove espaços para criar nomes válidos de diretórios e arquivos
    local output_dir="captures/$sanitized_name"
    local capture_file="$output_dir/capture.cap"

    echo "Criando pasta para a rede '$network_name' em '$output_dir'..."
    mkdir -p "$output_dir"

    echo "Capturando pacotes da rede '$network_name'..."
    sleep 5
    sudo timeout "$CAPTURE_DURATION" airodump-ng "$MONITOR_INTERFACE" --write "$capture_file" --output-format cap --bssid "$network_name"
    
    # Verifica se a captura foi bem-sucedida
    if [ $? -eq 0 ]; then
        echo "Captura da rede '$network_name' concluída. Arquivo salvo em '$capture_file'."
    else
        echo "Erro ao capturar pacotes da rede '$network_name'."
    fi
}

# Loop para capturar redes
echo "Iniciando o scan de redes Wi-Fi..."
sleep 5
sudo airodump-ng "$MONITOR_INTERFACE" -w /tmp/networks --output-format csv &

# Espera X segundos para garantir que o airodump-ng tenha tempo suficiente para coletar dados
read -p "Digite o tempo de captura em segundos:" CAPTURE_DURATION

sleep $CAPTURE_DURATION

# Para o airodump-ng após a coleta inicial
sudo pkill -f airodump-ng

# Processa os arquivos CSV gerados pelo airodump-ng
if [ -f /tmp/networks-01.csv ]; then
    echo "Processando redes encontradas..."
    sleep 5
    grep -v '^#' /tmp/networks-01.csv | while IFS=',' read -r _ _ _ _ _ _ _ _ _ _ _ _ network_name _; do
        if [ ! -z "$network_name" ] && [ "$network_name" != "SSID" ]; then
            capture_network "$network_name"
        fi
    done
else
    echo "Arquivo CSV não encontrado. Verifique se o airodump-ng coletou dados."
    sleep 5
    exit 1
fi

# Limpeza: Para o modo monitor e restaura a interface para o modo gerenciado
echo "Restaurando a interface para o modo gerenciado..."
sudo airmon-ng stop "$MONITOR_INTERFACE"
sudo service network-manager restart

echo "Processo concluído."
