#!/bin/bash

# Script de prueba para LCD ILI9486
# Para ejecutar desde /home/ramsi/AppResiclaje

echo "🔍 Probando LCD ILI9486..."

# Verificar driver
echo "1. Verificando driver fb_ili9486:"
lsmod | grep fb_ili9486 && echo "✅ Driver cargado" || echo "❌ Driver no encontrado"

# Verificar framebuffers
echo "2. Verificando framebuffers:"
ls -l /dev/fb* 2>/dev/null && echo "✅ Framebuffers disponibles" || echo "❌ No hay framebuffers"

# Verificar resolución del LCD
echo "3. Configuración del LCD (/dev/fb1):"
if [ -c /dev/fb1 ]; then
    fbset -fb /dev/fb1
    echo "✅ LCD configurado"
else
    echo "❌ /dev/fb1 no disponible"
fi

# Verificar X11
echo "4. Verificando X11:"
DISPLAY=:0 xset q >/dev/null 2>&1 && echo "✅ X11 funcionando" || echo "❌ X11 no disponible"

# Verificar servidor web
echo "5. Verificando servidor web:"
curl -s -o /dev/null -w "%{http_code}" http://localhost:5000 | grep -q 200 && echo "✅ Servidor web OK" || echo "❌ Servidor web no responde"

# Probar navegador en LCD
echo "6. Probando navegador en LCD:"
if command -v midori &> /dev/null; then
    echo "📱 Midori disponible - iniciando prueba..."
    DISPLAY=:0 midori -e Fullscreen -a http://localhost:5000 &
    BROWSER_PID=$!
    sleep 5
    if kill -0 $BROWSER_PID 2>/dev/null; then
        echo "✅ Midori funcionando en LCD (PID: $BROWSER_PID)"
        echo "   Deberías ver la aplicación en tu LCD ahora"
        echo "   Presiona Ctrl+C para cerrar la prueba"
        wait $BROWSER_PID
    else
        echo "❌ Midori se cerró inmediatamente"
    fi
else
    echo "❌ Midori no instalado"
fi

echo "🏁 Prueba completada"
