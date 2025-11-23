#!/bin/bash

# ============================================================================
# INSTALADOR COMPLETO - APLICACIÓN DE RECICLAJE INTELIGENTE
# Para Raspberry Pi sin interfaz gráfica
# ============================================================================

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Función para imprimir con colores
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC} $(printf "%-62s" "$1") ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════╝${NC}"
}

print_step() {
    echo -e "${CYAN}➤${NC} $1"
}

# Variables
APP_DIR="/home/ramsi/reciclaje-app"
SERVICE_NAME="reciclaje-app"
USER="ramsi"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Función para verificar si el comando fue exitoso
check_success() {
    if [ $? -eq 0 ]; then
        print_status "$1"
    else
        print_error "Error: $1"
        exit 1
    fi
}

# Función para crear spinner de carga
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

print_header "INSTALADOR DE RECICLAJE INTELIGENTE v2.0"
echo ""
print_info "Este script instalará una aplicación web completa de reciclaje"
print_info "con detección IA, NFC, MQTT y autoarranque en Raspberry Pi"
echo ""

# Verificar que estamos en Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
    print_warning "No se detectó Raspberry Pi. Continuando de todas formas..."
fi

# Verificar usuario ramsi
if [ "$(whoami)" != "ramsi" ] && [ ! -d "/home/ramsi" ]; then
    print_error "Este script debe ejecutarse como usuario 'ramsi'"
    exit 1
fi

print_header "PASO 1: VERIFICANDO Y CONFIGURANDO SISTEMA"

print_step "Verificando X11..."
if systemctl is-active --quiet lightdm && DISPLAY=:0 xset q >/dev/null 2>&1; then
    print_status "✅ X11 completamente instalado y funcionando"
elif systemctl list-unit-files | grep -q lightdm.service; then
    if systemctl is-active --quiet lightdm; then
        print_status "✅ X11 instalado y activo"
    else
        print_warning "X11 instalado pero no activo, habilitando..."
        sudo systemctl enable lightdm > /dev/null 2>&1
        sudo systemctl start lightdm > /dev/null 2>&1
        check_success "X11 habilitado"
    fi
else
    print_warning "X11 no instalado, instalando componentes mínimos..."
    sudo apt update > /dev/null 2>&1
    sudo apt install -y \
        xserver-xorg-core \
        xserver-xorg-input-all \
        xserver-xorg-video-fbdev \
        xinit \
        x11-xserver-utils \
        lightdm \
        openbox \
        > /dev/null 2>&1 &
    spinner $!
    check_success "X11 mínimo instalado"

    print_step "Habilitando X11..."
    sudo systemctl enable lightdm > /dev/null 2>&1
    sudo systemctl start lightdm > /dev/null 2>&1
    check_success "X11 habilitado y iniciado"
fi

print_step "Actualizando lista de paquetes..."
sudo apt update > /dev/null 2>&1 &
spinner $!
check_success "Lista de paquetes actualizada"

print_header "PASO 2: INSTALANDO NAVEGADORES Y DEPENDENCIAS WEB"

print_step "Instalando navegadores y herramientas para LCD..."
sudo apt install -y \
    midori \
    chromium-browser \
    unclutter \
    xdotool \
    fbset \
    fbi \
    > /dev/null 2>&1 &
spinner $!
check_success "Navegadores y herramientas LCD instaladas"

print_step "Verificando compatibilidad con LCD ILI9486..."
if lsmod | grep -q fb_ili9486; then
    print_status "Driver fb_ili9486 detectado correctamente"
    if [ -c /dev/fb1 ]; then
        print_status "Framebuffer /dev/fb1 disponible"
        # Configurar resolución del LCD
        fbset -fb /dev/fb1 -g 480 320 480 320 16 > /dev/null 2>&1
        print_status "LCD configurado a 480x320"
    else
        print_warning "Framebuffer /dev/fb1 no disponible"
    fi
else
    print_warning "Driver fb_ili9486 no detectado - verifica conexión LCD"
fi

print_header "PASO 3: INSTALANDO DEPENDENCIAS PYTHON Y SISTEMA"

print_step "Instalando Python y herramientas de desarrollo..."
sudo apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    cmake \
    git \
    curl \
    > /dev/null 2>&1 &
spinner $!
check_success "Python y herramientas instaladas"

print_step "Instalando dependencias de OpenCV..."
sudo apt install -y \
    libopencv-dev \
    python3-opencv \
    libatlas-base-dev \
    libjasper-dev \
    libqtgui4 \
    libqt4-test \
    libhdf5-dev \
    libhdf5-serial-dev \
    libjpeg-dev \
    libtiff5-dev \
    libpng-dev \
    libavcodec-dev \
    libavformat-dev \
    libswscale-dev \
    libv4l-dev \
    libxvidcore-dev \
    libx264-dev \
    > /dev/null 2>&1 &
spinner $!
check_success "Dependencias de OpenCV instaladas"

print_header "PASO 4: INSTALANDO DEPENDENCIAS NFC"

print_step "Instalando soporte para NFC/SmartCard..."
sudo apt install -y \
    pcscd \
    pcsc-tools \
    libpcsclite-dev \
    libpcsclite1 \
    > /dev/null 2>&1 &
spinner $!
check_success "Soporte NFC instalado"

print_step "Habilitando servicio PCSC..."
sudo systemctl enable pcscd > /dev/null 2>&1
sudo systemctl start pcscd > /dev/null 2>&1
check_success "Servicio PCSC habilitado"

print_header "PASO 5: CONFIGURANDO APLICACIÓN"

print_step "Creando directorio de aplicación..."
sudo mkdir -p "$APP_DIR"
sudo chown -R ramsi:ramsi "$APP_DIR"
check_success "Directorio de aplicación creado"

print_step "Copiando archivos de aplicación..."
# Detectar si estamos en el directorio AppResiclaje o en un subdirectorio
if [ -d "backend" ] && [ -d "frontend" ] && [ -f "requirements.txt" ]; then
    # Estamos en el directorio raíz del proyecto
    cp -r backend "$APP_DIR/"
    cp -r frontend "$APP_DIR/"
    cp -r config "$APP_DIR/"
    cp requirements.txt "$APP_DIR/"
elif [ -d "$SCRIPT_DIR/backend" ]; then
    # Estamos ejecutando desde un subdirectorio
    cp -r "$SCRIPT_DIR/backend" "$APP_DIR/"
    cp -r "$SCRIPT_DIR/frontend" "$APP_DIR/"
    cp -r "$SCRIPT_DIR/config" "$APP_DIR/"
    cp "$SCRIPT_DIR/requirements.txt" "$APP_DIR/"
else
    print_error "No se encontraron los archivos de la aplicación"
    print_info "Asegúrate de ejecutar este script desde el directorio AppResiclaje que contiene:"
    print_info "  - backend/"
    print_info "  - frontend/"
    print_info "  - config/"
    print_info "  - requirements.txt"
    exit 1
fi

# Crear directorio modelo si no existe
mkdir -p "$APP_DIR/modelo"

# Copiar modelo si existe (buscar en diferentes ubicaciones)
if [ -f "modelo/best.onnx" ]; then
    cp modelo/best.onnx "$APP_DIR/modelo/"
    print_status "Modelo YOLO copiado"
elif [ -f "$SCRIPT_DIR/modelo/best.onnx" ]; then
    cp "$SCRIPT_DIR/modelo/best.onnx" "$APP_DIR/modelo/"
    print_status "Modelo YOLO copiado"
else
    print_warning "Modelo YOLO no encontrado. Cópialo manualmente a $APP_DIR/modelo/best.onnx"
fi

# Copiar credenciales Firebase si existen (buscar en diferentes ubicaciones)
if [ -f "config/resiclaje-39011-firebase-adminsdk-fbsvc-433ec62b6c.json" ]; then
    cp config/resiclaje-39011-firebase-adminsdk-fbsvc-433ec62b6c.json "$APP_DIR/config/"
    print_status "Credenciales Firebase copiadas"
elif [ -f "$SCRIPT_DIR/config/resiclaje-39011-firebase-adminsdk-fbsvc-433ec62b6c.json" ]; then
    cp "$SCRIPT_DIR/config/resiclaje-39011-firebase-adminsdk-fbsvc-433ec62b6c.json" "$APP_DIR/config/"
    print_status "Credenciales Firebase copiadas"
else
    print_warning "Credenciales Firebase no encontradas. Cópialas manualmente a $APP_DIR/config/"
fi

check_success "Archivos de aplicación copiados"
else
    print_error "No se encontraron los archivos de la aplicación en $SCRIPT_DIR"
    print_info "Asegúrate de ejecutar este script desde el directorio que contiene:"
    print_info "  - backend/"
    print_info "  - frontend/"
    print_info "  - config/"
    print_info "  - requirements.txt"
    exit 1
fi

# Crear directorio de logs
mkdir -p "$APP_DIR/logs"
check_success "Directorio de logs creado"

print_header "PASO 6: CONFIGURANDO ENTORNO VIRTUAL PYTHON"

print_step "Creando entorno virtual Python..."
cd "$APP_DIR"
python3 -m venv venv > /dev/null 2>&1
check_success "Entorno virtual creado"

print_step "Instalando dependencias Python..."
source venv/bin/activate
pip install --upgrade pip > /dev/null 2>&1

# Instalar dependencias específicas para Raspberry Pi
print_step "Instalando OpenCV y dependencias principales..."
pip install opencv-python==4.8.1.78 > /dev/null 2>&1 &
spinner $!
check_success "OpenCV instalado"

print_step "Instalando Flask y WebSocket..."
pip install flask flask-socketio eventlet > /dev/null 2>&1 &
spinner $!
check_success "Flask y WebSocket instalados"

print_step "Instalando dependencias restantes..."
pip install -r requirements.txt > /dev/null 2>&1 &
spinner $!
check_success "Todas las dependencias Python instaladas"

# Verificar instalación crítica
print_step "Verificando instalaciones críticas..."
python -c "import cv2, flask, socketio; print('Dependencias críticas OK')" > /dev/null 2>&1
check_success "Verificación de dependencias completada"

print_header "PASO 7: CREANDO ARCHIVO DE CONFIGURACIÓN"

print_step "Creando archivo de configuración (.env)..."
cat > "$APP_DIR/.env" << 'EOF'
# Configuración de la Aplicación de Reciclaje Inteligente
# Generado automáticamente

# =============================================================================
# CONFIGURACIÓN GENERAL
# =============================================================================
FLASK_ENV=production
DEBUG=False
SECRET_KEY=reciclaje_inteligente_raspberry_pi_2024
HOST=0.0.0.0
PORT=5000

# =============================================================================
# CONFIGURACIÓN MQTT
# =============================================================================
MQTT_BROKER=2e139bb9a6c5438b89c85c91b8cbd53f.s1.eu.hivemq.cloud
MQTT_PORT=8883
MQTT_USER=ramsi
MQTT_PASSWORD=Erikram2025
MQTT_MATERIAL_TOPIC=material/detectado
MQTT_NIVEL_TOPIC=reciclaje/esp32-01/nivel
MQTT_USE_TLS=True

# =============================================================================
# CONFIGURACIÓN FIREBASE
# =============================================================================
FIREBASE_SERVICE_ACCOUNT=config/resiclaje-39011-firebase-adminsdk-fbsvc-433ec62b6c.json
FIREBASE_DATABASE_URL=https://resiclaje-39011-default-rtdb.firebaseio.com

# =============================================================================
# CONFIGURACIÓN CÁMARA
# =============================================================================
CAMERA_INDEX=0
CAMERA_WIDTH=640
CAMERA_HEIGHT=480
CAMERA_FPS=30

# =============================================================================
# CONFIGURACIÓN YOLO
# =============================================================================
YOLO_MODEL_PATH=modelo/best.onnx
YOLO_CONFIDENCE=0.5
YOLO_IMG_SIZE=320

# =============================================================================
# CONFIGURACIÓN DETECCIÓN
# =============================================================================
DETECTION_TIME_THRESHOLD=5.0
DETECTION_CLASSES=plastico,aluminio

# =============================================================================
# CONFIGURACIÓN NFC
# =============================================================================
NFC_ENABLED=True
NFC_TIMEOUT=0.5

# =============================================================================
# CONFIGURACIÓN PUNTOS
# =============================================================================
PUNTOS_PLASTICO=20
PUNTOS_ALUMINIO=30

# =============================================================================
# CONFIGURACIÓN WEBSOCKET
# =============================================================================
WEBSOCKET_ASYNC_MODE=threading
WEBSOCKET_CORS_ORIGINS=*

# =============================================================================
# CONFIGURACIÓN LOGGING
# =============================================================================
LOG_LEVEL=INFO
LOG_FILE=logs/app.log

# =============================================================================
# CONFIGURACIÓN AUTOARRANQUE (RASPBERRY PI)
# =============================================================================
AUTOSTART_ENABLED=True
CHROMIUM_KIOSK=True
CHROMIUM_URL=http://localhost:5000

# =============================================================================
# CONFIGURACIÓN RASPBERRY PI
# =============================================================================
RASPBERRY_PI=True
GPIO_ENABLED=False
EOF

check_success "Archivo de configuración creado"

print_header "PASO 8: CREANDO SCRIPTS DE INICIO"

print_step "Creando script de inicio de aplicación..."
cat > "$APP_DIR/start_app.sh" << 'EOF'
#!/bin/bash

# Script de inicio para Aplicación de Reciclaje Inteligente
APP_DIR="/home/ramsi/reciclaje-app"
LOG_FILE="$APP_DIR/logs/startup.log"

# Función de logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "🚀 Iniciando aplicación de reciclaje..."

# Cambiar al directorio de la aplicación
cd "$APP_DIR"

# Activar entorno virtual
source venv/bin/activate

# Cargar variables de entorno
if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Esperar a que la red esté disponible
log "⏳ Esperando conexión de red..."
for i in {1..30}; do
    if ping -c 1 8.8.8.8 &> /dev/null; then
        log "✅ Conexión de red disponible"
        break
    fi
    sleep 2
done

# Iniciar aplicación
log "🌐 Iniciando servidor web..."
python backend/app.py >> "$LOG_FILE" 2>&1 &
APP_PID=$!

# Guardar PID
echo $APP_PID > "$APP_DIR/app.pid"

log "✅ Servidor web iniciado (PID: $APP_PID)"
EOF

chmod +x "$APP_DIR/start_app.sh"
check_success "Script de inicio de aplicación creado"

print_step "Creando script de inicio de kiosk..."
cat > "$APP_DIR/start_kiosk.sh" << 'EOF'
#!/bin/bash

# Script para iniciar Chromium en modo kiosk
APP_DIR="/home/ramsi/reciclaje-app"
LOG_FILE="$APP_DIR/logs/kiosk.log"
URL="http://localhost:5000"

# Función de logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "🌐 Iniciando modo kiosk..."

# Configurar display
export DISPLAY=:0

# Esperar a que X11 esté listo
for i in {1..30}; do
    if xset q &>/dev/null; then
        log "✅ X11 disponible"
        break
    fi
    sleep 2
done

# Configurar pantalla
xset s off
xset -dpms
xset s noblank

# Ocultar cursor
unclutter -idle 0.5 -root &

# Esperar servidor web
log "⏳ Esperando servidor web..."
for i in {1..60}; do
    if curl -s "$URL" > /dev/null; then
        log "✅ Servidor web disponible"
        break
    fi
    sleep 2
done

# Configurar framebuffer para LCD ILI9486
export FRAMEBUFFER=/dev/fb1
if [ -c /dev/fb1 ]; then
    fbset -fb /dev/fb1 -g 480 320 480 320 16
    log "✅ LCD ILI9486 configurado (/dev/fb1)"
else
    log "❌ LCD framebuffer no disponible, usando display principal"
    export FRAMEBUFFER=/dev/fb0
fi

# Verificar que X11 esté funcionando
if ! xset q &>/dev/null; then
    log "⚠️ X11 no disponible, intentando iniciar..."
    # Intentar iniciar X11 mínimo
    if command -v startx &> /dev/null; then
        startx &
        sleep 5
    fi
fi

# Intentar con diferentes navegadores para LCD
log "🚀 Iniciando navegador para LCD ILI9486..."

# Opción 1: Midori (mejor para LCD pequeño)
if command -v midori &> /dev/null && xset q &>/dev/null; then
    log "📱 Usando Midori para LCD..."
    midori \
        -e Fullscreen \
        -e Navigationbar \
        -a "$URL" >> "$LOG_FILE" 2>&1 &

    BROWSER_PID=$!
    echo $BROWSER_PID > "$APP_DIR/browser.pid"
    log "✅ Midori iniciado (PID: $BROWSER_PID)"

# Opción 2: Chromium optimizado para LCD
elif command -v chromium-browser &> /dev/null && xset q &>/dev/null; then
    log "🌐 Usando Chromium para LCD..."
    chromium-browser \
        --kiosk \
        --start-fullscreen \
        --window-size=480,320 \
        --window-position=0,0 \
        --noerrdialogs \
        --disable-infobars \
        --no-first-run \
        --disable-session-crashed-bubble \
        --disable-restore-session-state \
        --disable-background-timer-throttling \
        --disable-backgrounding-occluded-windows \
        --disable-renderer-backgrounding \
        --disable-features=TranslateUI,VizDisplayCompositor \
        --no-sandbox \
        --disable-dev-shm-usage \
        --disable-gpu \
        --disable-software-rasterizer \
        --touch-events=enabled \
        --force-device-scale-factor=1.0 \
        --disable-pinch \
        "$URL" >> "$LOG_FILE" 2>&1 &

    BROWSER_PID=$!
    echo $BROWSER_PID > "$APP_DIR/browser.pid"
    log "✅ Chromium iniciado (PID: $BROWSER_PID)"

# Opción 3: Navegador de texto con framebuffer (fallback)
elif command -v links2 &> /dev/null; then
    log "📄 Usando Links2 como fallback..."
    links2 -g -mode 480x320x16 "$URL" >> "$LOG_FILE" 2>&1 &

    BROWSER_PID=$!
    echo $BROWSER_PID > "$APP_DIR/browser.pid"
    log "✅ Links2 iniciado (PID: $BROWSER_PID)"

else
    log "❌ No se encontró navegador compatible"
    log "💡 La aplicación web está disponible en: $URL"
    log "🌐 Accede desde otro dispositivo en la red"
    exit 1
fi

# Mantener el script corriendo
wait
EOF

chmod +x "$APP_DIR/start_kiosk.sh"
check_success "Script de inicio de kiosk creado"

print_header "PASO 9: CONFIGURANDO SERVICIOS SYSTEMD"

print_step "Creando servicio de aplicación..."
sudo tee /etc/systemd/system/reciclaje-app.service > /dev/null << EOF
[Unit]
Description=Aplicación de Reciclaje Inteligente - Backend
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
User=ramsi
Group=ramsi
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/start_app.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

check_success "Servicio de aplicación creado"

print_step "Creando servicio de kiosk..."
sudo tee /etc/systemd/system/reciclaje-kiosk.service > /dev/null << EOF
[Unit]
Description=Aplicación de Reciclaje Inteligente - Kiosk
After=graphical.target reciclaje-app.service
Wants=graphical.target
Requires=reciclaje-app.service

[Service]
Type=simple
User=ramsi
Group=ramsi
WorkingDirectory=$APP_DIR
Environment=DISPLAY=:0
Environment=HOME=/home/ramsi
ExecStartPre=/bin/sleep 15
ExecStart=$APP_DIR/start_kiosk.sh
Restart=always
RestartSec=10

[Install]
WantedBy=graphical.target
EOF

check_success "Servicio de kiosk creado"

print_step "Habilitando servicios..."
sudo systemctl daemon-reload
sudo systemctl enable reciclaje-app
sudo systemctl enable reciclaje-kiosk
check_success "Servicios habilitados"

print_header "PASO 10: CONFIGURANDO AUTOARRANQUE"

print_step "Configurando autologin..."
sudo systemctl set-default graphical.target

# Configurar autologin para lightdm
sudo mkdir -p /etc/lightdm/lightdm.conf.d
sudo tee /etc/lightdm/lightdm.conf.d/01-autologin.conf > /dev/null << EOF
[Seat:*]
autologin-user=ramsi
autologin-user-timeout=0
EOF

check_success "Autologin configurado"

print_step "Configurando inicio automático de aplicación..."
mkdir -p /home/ramsi/.config/autostart
cat > /home/ramsi/.config/autostart/reciclaje-kiosk.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Reciclaje Kiosk
Exec=/home/ramsi/reciclaje-app/start_kiosk.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

check_success "Inicio automático configurado"

print_header "PASO 11: OPTIMIZANDO RASPBERRY PI"

print_step "Configurando memoria GPU..."
if ! grep -q "gpu_mem=" /boot/config.txt; then
    echo "gpu_mem=128" | sudo tee -a /boot/config.txt > /dev/null
fi
check_success "Memoria GPU configurada"

print_step "Configurando LCD ILI9486..."
# Verificar que el driver fb_ili9486 esté cargado
if lsmod | grep -q fb_ili9486; then
    print_status "Driver fb_ili9486 ya está cargado"
else
    print_warning "Driver fb_ili9486 no detectado. Verifica la conexión del LCD."
fi

# Configurar X11 para usar el LCD como pantalla principal
sudo mkdir -p /etc/X11/xorg.conf.d
sudo tee /etc/X11/xorg.conf.d/99-fbdev-lcd.conf > /dev/null << 'XORG_EOF'
Section "Device"
    Identifier "LCD ILI9486"
    Driver "fbdev"
    Option "fbdev" "/dev/fb1"
    Option "ShadowFB" "off"
EndSection

Section "Monitor"
    Identifier "LCD Monitor"
    HorizSync 15.0-64.0
    VertRefresh 50.0-70.0
    Option "PreferredMode" "480x320"
EndSection

Section "Screen"
    Identifier "LCD Screen"
    Device "LCD ILI9486"
    Monitor "LCD Monitor"
    DefaultDepth 16
    SubSection "Display"
        Depth 16
        Modes "480x320"
        ViewPort 0 0
    EndSubSection
EndSection

Section "ServerLayout"
    Identifier "LCD Layout"
    Screen 0 "LCD Screen" 0 0
    Option "BlankTime" "0"
    Option "StandbyTime" "0"
    Option "SuspendTime" "0"
    Option "OffTime" "0"
EndSection
XORG_EOF

check_success "Configuración X11 para LCD ILI9486 creada"

print_step "Habilitando cámara..."
sudo raspi-config nonint do_camera 0 > /dev/null 2>&1
if ! grep -q "start_x=1" /boot/config.txt; then
    echo "start_x=1" | sudo tee -a /boot/config.txt > /dev/null
fi
check_success "Cámara habilitada"

print_step "Configurando watchdog..."
if ! grep -q "dtparam=watchdog=on" /boot/config.txt; then
    echo "dtparam=watchdog=on" | sudo tee -a /boot/config.txt > /dev/null
fi
check_success "Watchdog configurado"

print_header "PASO 12: CREANDO SCRIPTS DE GESTIÓN"

print_step "Creando script de gestión..."
cat > "$APP_DIR/manage.sh" << 'EOF'
#!/bin/bash

# Script de gestión para Aplicación de Reciclaje Inteligente

case "$1" in
    start)
        echo "🚀 Iniciando aplicación..."
        sudo systemctl start reciclaje-app
        sudo systemctl start reciclaje-kiosk
        ;;
    stop)
        echo "🛑 Deteniendo aplicación..."
        sudo systemctl stop reciclaje-kiosk
        sudo systemctl stop reciclaje-app
        ;;
    restart)
        echo "🔄 Reiniciando aplicación..."
        sudo systemctl restart reciclaje-app
        sudo systemctl restart reciclaje-kiosk
        ;;
    status)
        echo "📊 Estado de la aplicación:"
        sudo systemctl status reciclaje-app
        echo ""
        sudo systemctl status reciclaje-kiosk
        ;;
    logs)
        echo "📋 Logs de la aplicación:"
        sudo journalctl -u reciclaje-app -u reciclaje-kiosk -f
        ;;
    logs-app)
        echo "📋 Logs del backend:"
        sudo journalctl -u reciclaje-app -f
        ;;
    logs-kiosk)
        echo "📋 Logs del kiosk:"
        sudo journalctl -u reciclaje-kiosk -f
        ;;
    enable)
        echo "✅ Habilitando autoarranque..."
        sudo systemctl enable reciclaje-app
        sudo systemctl enable reciclaje-kiosk
        ;;
    disable)
        echo "❌ Deshabilitando autoarranque..."
        sudo systemctl disable reciclaje-app
        sudo systemctl disable reciclaje-kiosk
        ;;
    update)
        echo "📦 Actualizando dependencias..."
        cd /home/ramsi/reciclaje-app
        source venv/bin/activate
        pip install --upgrade -r requirements.txt
        ;;
    test-camera)
        echo "📷 Probando cámara..."
        ls /dev/video* 2>/dev/null || echo "No se encontraron dispositivos de video"
        ;;
    test-nfc)
        echo "💳 Probando NFC..."
        pcsc_scan
        ;;
    check-temp)
        echo "🌡️ Temperatura del CPU:"
        vcgencmd measure_temp
        ;;
    *)
        echo "Uso: $0 {start|stop|restart|status|logs|logs-app|logs-kiosk|enable|disable|update|test-camera|test-nfc|check-temp}"
        exit 1
        ;;
esac
EOF

chmod +x "$APP_DIR/manage.sh"
check_success "Script de gestión creado"

print_header "PASO 13: CONFIGURACIÓN FINAL"

print_step "Ajustando permisos..."
sudo chown -R ramsi:ramsi "$APP_DIR"
check_success "Permisos ajustados"

print_step "Configurando logrotate..."
sudo tee /etc/logrotate.d/reciclaje-app > /dev/null << EOF
$APP_DIR/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    copytruncate
    su ramsi ramsi
}
EOF

check_success "Rotación de logs configurada"

print_header "¡INSTALACIÓN COMPLETADA EXITOSAMENTE!"

echo ""
print_status "🎉 La aplicación de reciclaje inteligente ha sido instalada correctamente"
echo ""

print_info "📋 RESUMEN DE LA INSTALACIÓN:"
echo "  ✅ X11 y Chromium instalados"
echo "  ✅ Aplicación web configurada"
echo "  ✅ Servicios systemd creados"
echo "  ✅ Autoarranque configurado"
echo "  ✅ Scripts de gestión disponibles"
echo ""

print_info "🔧 COMANDOS ÚTILES:"
echo "  • Gestionar aplicación:    $APP_DIR/manage.sh {start|stop|restart|status}"
echo "  • Ver logs:                $APP_DIR/manage.sh logs"
echo "  • Probar cámara:           $APP_DIR/manage.sh test-camera"
echo "  • Probar NFC:              $APP_DIR/manage.sh test-nfc"
echo "  • Ver temperatura:         $APP_DIR/manage.sh check-temp"
echo ""

print_info "📁 ARCHIVOS IMPORTANTES:"
echo "  • Configuración:           $APP_DIR/.env"
echo "  • Logs:                    $APP_DIR/logs/"
echo "  • Modelo YOLO:             $APP_DIR/modelo/best.onnx"
echo "  • Credenciales Firebase:   $APP_DIR/config/"
echo ""

print_warning "⚠️  ANTES DE REINICIAR:"
if [ ! -f "$APP_DIR/modelo/best.onnx" ]; then
    echo "  1. Copia tu modelo YOLO a: $APP_DIR/modelo/best.onnx"
fi
if [ ! -f "$APP_DIR/config/resiclaje-39011-firebase-adminsdk-fbsvc-433ec62b6c.json" ]; then
    echo "  2. Copia las credenciales Firebase a: $APP_DIR/config/"
fi
echo "  3. Edita la configuración si es necesario: nano $APP_DIR/.env"
echo ""

print_info "🔄 PARA INICIAR LA APLICACIÓN:"
echo "  • Reiniciar ahora:         sudo reboot"
echo "  • O iniciar manualmente:   $APP_DIR/manage.sh start"
echo ""

print_info "🌐 ACCESO A LA APLICACIÓN:"
echo "  • Local (en la Pi):        http://localhost:5000"
echo "  • Desde red local:         http://$(hostname -I | awk '{print $1}'):5000"
echo ""

print_status "🎯 ¡Todo listo! La aplicación se iniciará automáticamente al reiniciar."

echo ""
read -p "¿Deseas reiniciar ahora para activar la aplicación? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "🔄 Reiniciando sistema..."
    sudo reboot
else
    print_info "👍 Puedes reiniciar manualmente cuando estés listo con: sudo reboot"
fi
