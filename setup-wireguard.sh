#!/bin/bash

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Iniciando configuración de WireGuard...${NC}"

# Crear directorios necesarios
mkdir -p /config/wg_confs
mkdir -p /config/peer_confs
mkdir -p /config/keys

# Verificar si ya existe configuración
if [ -f /config/wg_confs/wg0.conf ] && [ -f /config/keys/server_private.key ]; then
    echo -e "${YELLOW}📋 Configuración existente encontrada, reutilizando...${NC}"
    
    # Mostrar configuraciones existentes
    show_existing_configs
    
    echo -e "${GREEN}🚀 Iniciando WireGuard con configuración existente...${NC}"
    exec /init
else
    echo -e "${YELLOW}🆕 Primera ejecución, generando nuevas configuraciones...${NC}"
    generate_new_configs
fi

# Función para mostrar configuraciones existentes
show_existing_configs() {
    echo -e "\n${GREEN}📋 CONFIGURACIONES EXISTENTES:${NC}\n"
    
    for conf_file in /config/peer_confs/peer*.conf; do
        if [ -f "$conf_file" ]; then
            client_name=$(basename "$conf_file" .conf)
            echo -e "${YELLOW}🔧 Configuración para ${client_name}:${NC}"
            echo "----------------------------------------"
            cat "$conf_file"
            echo "----------------------------------------"
            
            # Mostrar QR si existe
            qr_file="/config/peer_confs/${client_name}_qr.txt"
            if [ -f "$qr_file" ]; then
                echo -e "\n${YELLOW}📱 Código QR para ${client_name}:${NC}"
                cat "$qr_file"
            fi
            echo -e "\n"
        fi
    done
}

# Función para generar nuevas configuraciones
generate_new_configs() {
    # Función para obtener IP pública
    get_public_ip() {
        PUBLIC_IP=$(curl -s --connect-timeout 5 ifconfig.me || \
                   curl -s --connect-timeout 5 ipinfo.io/ip || \
                   curl -s --connect-timeout 5 icanhazip.com || \
                   echo "auto")
        echo $PUBLIC_IP
    }

    echo -e "${YELLOW}📝 Generando configuración del servidor...${NC}"
    
    # Generar clave privada del servidor
    wg genkey > /config/keys/server_private.key
    chmod 600 /config/keys/server_private.key
    
    # Generar clave pública del servidor
    cat /config/keys/server_private.key | wg pubkey > /config/keys/server_public.key
    
    SERVER_PRIVATE_KEY=$(cat /config/keys/server_private.key)
    SERVER_PUBLIC_KEY=$(cat /config/keys/server_public.key)
    
    # Obtener IP pública
    PUBLIC_IP=$(get_public_ip)
    
    echo -e "${GREEN}🔑 Clave pública del servidor: ${SERVER_PUBLIC_KEY}${NC}"
    echo -e "${GREEN}🌐 IP pública detectada: ${PUBLIC_IP}${NC}"
    
    # Crear configuración del servidor
    cat > /config/wg_confs/wg0.conf << EOF
[Interface]
Address = ${INTERNAL_SUBNET%.*}.1/24
SaveConfig = false
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth+ -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth+ -j MASQUERADE
ListenPort = ${SERVERPORT}
PrivateKey = ${SERVER_PRIVATE_KEY}

EOF

    # Generar configuraciones de clientes
    echo -e "${YELLOW}👥 Generando configuraciones de clientes...${NC}"
    
    for i in $(seq 1 ${PEERS}); do
        CLIENT_NAME="peer${i}"
        CLIENT_IP="${INTERNAL_SUBNET%.*}.$((i + 1))"
        
        # Generar claves del cliente
        wg genkey > /config/keys/${CLIENT_NAME}_private.key
        chmod 600 /config/keys/${CLIENT_NAME}_private.key
        
        # Generar clave pública del cliente
        cat /config/keys/${CLIENT_NAME}_private.key | wg pubkey > /config/keys/${CLIENT_NAME}_public.key
        
        CLIENT_PRIVATE_KEY=$(cat /config/keys/${CLIENT_NAME}_private.key)
        CLIENT_PUBLIC_KEY=$(cat /config/keys/${CLIENT_NAME}_public.key)
        
        # Agregar peer al servidor
        cat >> /config/wg_confs/wg0.conf << EOF
[Peer]
PublicKey = ${CLIENT_PUBLIC_KEY}
AllowedIPs = ${CLIENT_IP}/32

EOF
        
        # Crear configuración del cliente
        cat > /config/peer_confs/${CLIENT_NAME}.conf << EOF
[Interface]
PrivateKey = ${CLIENT_PRIVATE_KEY}
Address = ${CLIENT_IP}/32
DNS = ${PEERDNS}

[Peer]
PublicKey = ${SERVER_PUBLIC_KEY}
Endpoint = ${PUBLIC_IP}:${SERVERPORT}
AllowedIPs = ${ALLOWEDIPS}
PersistentKeepalive = 25
EOF
        
        # Generar código QR
        qrencode -t ansiutf8 < /config/peer_confs/${CLIENT_NAME}.conf > /config/peer_confs/${CLIENT_NAME}_qr.txt
        
        echo -e "${GREEN}✅ Cliente ${CLIENT_NAME} configurado (IP: ${CLIENT_IP})${NC}"
    done
    
    # Mostrar configuraciones generadas
    show_existing_configs
    
    echo -e "${GREEN}🚀 Iniciando WireGuard...${NC}"
    exec /init
}

# Función principal
echo -e "${GREEN}🔧 Configurando WireGuard con los siguientes parámetros:${NC}"
echo -e "   Peers: ${PEERS}"
echo -e "   Puerto: ${SERVERPORT}"
echo -e "   DNS: ${PEERDNS}"
echo -e "   Subred: ${INTERNAL_SUBNET}"
echo -e "   IPs permitidas: ${ALLOWEDIPS}"
echo ""
