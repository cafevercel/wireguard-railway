#!/bin/bash

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Iniciando configuración de WireGuard...${NC}"

# Crear directorio de configuración si no existe
mkdir -p /config/wg_confs
mkdir -p /config/peer_confs

# Función para obtener IP pública
get_public_ip() {
    # Intentar varios servicios para obtener IP pública
    PUBLIC_IP=$(curl -s --connect-timeout 5 ifconfig.me || \
               curl -s --connect-timeout 5 ipinfo.io/ip || \
               curl -s --connect-timeout 5 icanhazip.com || \
               echo "auto")
    echo $PUBLIC_IP
}

# Función para generar configuración del servidor
generate_server_config() {
    echo -e "${YELLOW}📝 Generando configuración del servidor...${NC}"
    
    # Generar clave privada del servidor si no existe
    if [ ! -f /config/server_private.key ]; then
        wg genkey > /config/server_private.key
        chmod 600 /config/server_private.key
    fi
    
    # Generar clave pública del servidor
    cat /config/server_private.key | wg pubkey > /config/server_public.key
    
    SERVER_PRIVATE_KEY=$(cat /config/server_private.key)
    SERVER_PUBLIC_KEY=$(cat /config/server_public.key)
    
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
}

# Función para generar configuración de clientes
generate_client_configs() {
    echo -e "${YELLOW}👥 Generando configuraciones de clientes...${NC}"
    
    SERVER_PUBLIC_KEY=$(cat /config/server_public.key)
    PUBLIC_IP=$(get_public_ip)
    
    for i in $(seq 1 ${PEERS}); do
        CLIENT_NAME="peer${i}"
        CLIENT_IP="${INTERNAL_SUBNET%.*}.$((i + 1))"
        
        # Generar claves del cliente si no existen
        if [ ! -f /config/peer_confs/${CLIENT_NAME}_private.key ]; then
            wg genkey > /config/peer_confs/${CLIENT_NAME}_private.key
            chmod 600 /config/peer_confs/${CLIENT_NAME}_private.key
        fi
        
        # Generar clave pública del cliente
        cat /config/peer_confs/${CLIENT_NAME}_private.key | wg pubkey > /config/peer_confs/${CLIENT_NAME}_public.key
        
        CLIENT_PRIVATE_KEY=$(cat /config/peer_confs/${CLIENT_NAME}_private.key)
        CLIENT_PUBLIC_KEY=$(cat /config/peer_confs/${CLIENT_NAME}_public.key)
        
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
}

# Función para mostrar configuraciones
show_configs() {
    echo -e "\n${GREEN}📋 CONFIGURACIONES GENERADAS:${NC}\n"
    
    for i in $(seq 1 ${PEERS}); do
        CLIENT_NAME="peer${i}"
        
        echo -e "${YELLOW}🔧 Configuración para ${CLIENT_NAME}:${NC}"
        echo "----------------------------------------"
        cat /config/peer_confs/${CLIENT_NAME}.conf
        echo "----------------------------------------"
        
        echo -e "\n${YELLOW}📱 Código QR para ${CLIENT_NAME}:${NC}"
        cat /config/peer_confs/${CLIENT_NAME}_qr.txt
        echo -e "\n"
    done
    
    echo -e "${GREEN}💾 Archivos guardados en /config/peer_confs/${NC}"
    echo -e "${GREEN}📁 Configuración del servidor en /config/wg_confs/wg0.conf${NC}"
}

# Función principal
main() {
    echo -e "${GREEN}🔧 Configurando WireGuard con los siguientes parámetros:${NC}"
    echo -e "   Peers: ${PEERS}"
    echo -e "   Puerto: ${SERVERPORT}"
    echo -e "   DNS: ${PEERDNS}"
    echo -e "   Subred: ${INTERNAL_SUBNET}"
    echo -e "   IPs permitidas: ${ALLOWEDIPS}"
    echo ""
    
    # Generar configuraciones
    generate_server_config
    generate_client_configs
    show_configs
    
    echo -e "${GREEN}🚀 Iniciando WireGuard...${NC}"
    
    # Iniciar WireGuard
    exec /init
}

# Ejecutar función principal
main
