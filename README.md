# 🌱 Aplicación de Reciclaje Inteligente

Una aplicación web moderna para Raspberry Pi que utiliza inteligencia artificial para detectar materiales reciclables, con interfaz web en tiempo real y autoarranque automático.

## 🚀 Características

### ✨ Funcionalidades Principales
- **Detección IA**: Reconocimiento de materiales (plástico, aluminio) usando YOLO
- **Interfaz Web Moderna**: Frontend responsive con WebSocket en tiempo real
- **Sistema NFC**: Identificación de usuarios mediante tarjetas NFC
- **Comunicación MQTT**: Integración con sensores IoT
- **Base de Datos Firebase**: Almacenamiento en tiempo real de usuarios y estadísticas
- **Autoarranque**: Inicio automático al encender la Raspberry Pi
- **Modo Kiosk**: Navegador Chromium en pantalla completa

### 🏗️ Arquitectura Simplificada
```
┌─────────────────┐    WebSocket    ┌─────────────────┐
│   Frontend Web  │◄──────────────►│  Backend Flask  │
│   (Chromium)    │                 │   (Python)      │
└─────────────────┘                 └─────────────────┘
         │                                   │
         │ Autoarranque                      ▼
         │                          ┌─────────────────┐
         └─────────────────────────►│   Hardware      │
                                    │ Cámara + NFC    │
                                    └─────────────────┘
```

## 📋 Requisitos

### Hardware
- **Raspberry Pi 4** (recomendado) o Raspberry Pi 3B+
- **Cámara USB** o Raspberry Pi Camera Module
- **Lector NFC** compatible con PC/SC ACR122U.
- **Pantalla** (HDMI, táctil opcional)
- **Tarjeta microSD** de al menos 32GB (Clase 10)

### Software
- **Raspberry Pi OS Lite** (sin interfaz gráfica)
- **Conexión a Internet** para descargas e instalación

## 🛠️ Instalación Ultra-Simplificada

### 1️⃣ Preparar Archivos en Raspberry Pi

```bash
# Copiar todos los archivos del proyecto a la Raspberry Pi
# Conectar por SSH a la Raspberry Pi
ssh ramsi@IP_RASPBERRY
cd /home/ramsi/AppResiclaje
```

### 3️⃣ Archivos Opcionales

```bash
# Copiar modelo YOLO
cp tu_modelo.onnx /home/ramsi/AppResiclaje/modelo/best.onnx

# Copiar credenciales Firebase
cp firebase-credentials.json /home/ramsi/AppResiclaje/config/resiclaje-39011-firebase-adminsdk-fbsvc-433ec62b6c.json
```

### 4️⃣ Reiniciar y Listo

```bash
sudo reboot
```
### Acceso Web

- **En la Raspberry Pi**: Se abre automáticamente en Chromium
- **Desde otro dispositivo**: http://IP_RASPBERRY:5000

## 🏗️ Estructura Final del Proyecto

```
AppResiclaje/
├── backend/                   # Servidor Flask + WebSocket
│   └── app.py                 # Aplicación principal
├── frontend/                  # Interfaz web moderna
│   ├── templates/
│   │   └── index.html        # Página principal (simplificada)
│   └── static/
│       ├── css/style.css     # Estilos (solo cámara + navbar)
│       └── js/app.js         # Cliente WebSocket
├── config/                   # Configuración
│   ├── app_config.py        # Configuración Python
│   └── environment.env      # Variables de entorno
├── modelo/                  # Modelo YOLO
├── requirements.txt         # Dependencias Python
└── README.md               # Esta documentación
```

## 🔧 Configuración Personalizada

### Editar Configuración

```bash

# Configuraciones importantes:
MQTT_BROKER=tu-broker.com
MQTT_USER=tu-usuario  
MQTT_PASSWORD=tu-password
FIREBASE_DATABASE_URL=https://tu-proyecto.firebaseio.com
CAMERA_INDEX=0  # Cambiar si tienes múltiples cámaras
```

### Verificar Hardware

```bash
# Verificar cámara
ls /dev/video*
v4l2-ctl --list-devices

# Verificar NFC
pcsc_scan
opensc-tool --list-readers

# Verificar temperatura
vcgencmd measure_temp
```


```bash
# Actualizar sistema
sudo apt update && sudo apt upgrade -y

# Actualizar dependencias de la aplicación
./manage.sh update

# Reiniciar después de actualizaciones importantes
sudo reboot
```

## 🎯 Funcionalidades de la Interfaz

### Interfaz Simplificada
- **Navbar superior**: Indicadores de estado (Cámara, NFC, MQTT)
- **Feed de cámara**: Video en vivo con overlays de detección
- **Modales emergentes**: Para material detectado, éxito y errores
- **Responsive**: Se adapta a cualquier tamaño de pantalla

### Flujo de Uso
1. **Detección**: Coloca objeto frente a la cámara
2. **Reconocimiento**: Sistema detecta material (5 segundos)
3. **NFC**: Acerca tarjeta NFC al lector
4. **Confirmación**: Modal de éxito con puntos ganados
5. **Repetir**: Sistema listo para siguiente detección

**¡Hecho con ❤️ para un mundo más sostenible! 🌍♻️**