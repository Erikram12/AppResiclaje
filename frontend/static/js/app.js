/**
 * Aplicación Web de Reciclaje Inteligente
 * Cliente JavaScript con WebSocket para comunicación en tiempo real
 */

class ReciclajeApp {
    constructor() {
        this.socket = null;
        this.isConnected = false;
        this.currentState = 'searching';
        this.detectionTimeout = null;
        this.modalTimeout = null;
        this.nfcActive = false;

        // Referencias DOM
        this.elements = {
            // Status indicators
            cameraStatus: document.getElementById('camera-status'),
            nfcStatus: document.getElementById('nfc-status'),
            mqttStatus: document.getElementById('mqtt-status'),

            // Camera
            cameraFeed: document.getElementById('camera-feed'),
            fpsDisplay: document.getElementById('fps-display'),
            detectionInfo: document.getElementById('detection-info'),
            materialName: document.getElementById('material-name'),
            progressFill: document.getElementById('progress-fill'),
            progressText: document.getElementById('progress-text'),


            // Modals
            materialModal: document.getElementById('material-modal'),
            successModal: document.getElementById('success-modal'),
            errorModal: document.getElementById('error-modal'),

            // Modal content
            modalMaterialIcon: document.getElementById('modal-material-icon'),
            modalMaterialName: document.getElementById('modal-material-name'),
            userName: document.getElementById('user-name'),
            pointsEarned: document.getElementById('points-earned'),
            pointsTotal: document.getElementById('points-total'),
            errorMessage: document.getElementById('error-message'),

            // Loading
            loadingOverlay: document.getElementById('loading-overlay')
        };

        // Configuración de materiales
        this.materialConfig = {
            plastico: {
                name: 'Plástico',
                icon: 'fas fa-bottle-water',
                color: '#2196F3',
                points: 20
            },
            aluminio: {
                name: 'Aluminio',
                icon: 'fas fa-can-food',
                color: '#9E9E9E',
                points: 30
            }
        };

        this.init();
    }

    /**
     * Inicializar aplicación
     */
    init() {
        console.log('🚀 Iniciando aplicación de reciclaje...');
        this.showLoading();
        this.initSocket();
        this.bindEvents();
        this.startHeartbeat();
    }

    /**
     * Inicializar conexión WebSocket
     */
    initSocket() {
        try {
            this.socket = io({
                transports: ['websocket', 'polling'],
                timeout: 5000,
                reconnection: true,
                reconnectionDelay: 1000,
                reconnectionAttempts: 5
            });

            this.bindSocketEvents();
            console.log('🔌 Conectando WebSocket...');

        } catch (error) {
            console.error('❌ Error inicializando WebSocket:', error);
            this.showError('Error de conexión', 'No se pudo conectar al servidor');
        }
    }

    /**
     * Vincular eventos WebSocket
     */
    bindSocketEvents() {
        // Conexión establecida
        this.socket.on('connect', () => {
            console.log('✅ WebSocket conectado');
            this.isConnected = true;
            this.hideLoading();
            this.updateConnectionStatus();
        });

        // Desconexión
        this.socket.on('disconnect', (reason) => {
            console.log('❌ WebSocket desconectado:', reason);
            this.isConnected = false;
            this.updateConnectionStatus();
            this.showLoading();
        });

        // Error de conexión
        this.socket.on('connect_error', (error) => {
            console.error('❌ Error de conexión WebSocket:', error);
            this.showError('Error de Conexión', 'No se pudo conectar al servidor');
        });

        // Estado inicial
        this.socket.on('initial_state', (data) => {
            console.log('📊 Estado inicial recibido:', data);
            this.updateAppState(data.app_state);
            this.hideLoading();
        });

        // Frame de cámara
        this.socket.on('camera_frame', (data) => {
            this.updateCameraFrame(data);
        });

        // Material detectado
        this.socket.on('material_detectado', (data) => {
            console.log('🔍 Material detectado:', data);
            this.showMaterialDetected(data.material);
        });

        // Esperando NFC
        this.socket.on('waiting_nfc', (data) => {
            console.log('💳 Esperando NFC para:', data.material);
            // El modal ya debería estar abierto
        });

        // Material procesado exitosamente
        this.socket.on('material_procesado', (data) => {
            console.log('✅ Material procesado:', data);
            this.showProcessingSuccess(data);
        });

        // Error NFC
        this.socket.on('nfc_error', (data) => {
            console.log('❌ Error NFC:', data);
            this.showError('Error NFC', data.message);
        });


        // Estado MQTT
        this.socket.on('mqtt_status', (data) => {
            console.log('📡 Estado MQTT:', data);
            this.updateMqttStatus(data.connected);
        });

        // Reset del sistema
        this.socket.on('system_reset', () => {
            console.log('🔄 Sistema reseteado');
            this.closeAllModals();
        });

        // Actualización de estado
        this.socket.on('status_update', (data) => {
            this.updateAppState(data);
            this.nfcActive = data.nfc_active || false;
        });

        // ========== EVENTOS VINCULACIÓN NFC ==========

        // Resultado de búsqueda de usuario por PIN
        this.socket.on('user_found_by_pin', (data) => {
            console.log('👤 Usuario encontrado por PIN:', data);

            // Restaurar botón
            const button = document.querySelector('#nfc-step-1 .btn-primary');
            if (button) {
                button.innerHTML = '<i class="fas fa-search"></i> Buscar Usuario';
                button.disabled = false;
            }

            if (data.success) {
                showUserFound(data.user);
            } else {
                showNfcError(data.message || 'Usuario no encontrado');
            }
        });

        // Estado de lectura NFC para vinculación
        this.socket.on('nfc_link_status', (data) => {
            console.log('📡 Estado vinculación NFC:', data);

            if (data.status === 'reading') {
                updateNfcStatus('Leyendo llavero NFC...', 'reading');
            } else if (data.status === 'waiting') {
                updateNfcStatus('Esperando llavero NFC...', 'waiting');
            }
        });

        // Éxito en vinculación NFC
        this.socket.on('nfc_link_success', (data) => {
            console.log('🎉 Vinculación NFC exitosa:', data);
            showNfcLinkSuccess(data);
        });

        // Error en vinculación NFC
        this.socket.on('nfc_link_error', (data) => {
            console.error('❌ Error vinculación NFC:', data);
            handleNfcLinkError(data);
        });
    }

    /**
     * Vincular eventos DOM
     */
    bindEvents() {
        // Cerrar modales al hacer clic fuera
        document.addEventListener('click', (e) => {
            if (e.target.classList.contains('modal')) {
                this.closeModal(e.target.id);
            }
        });

        // Tecla ESC para cerrar modales
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                this.closeAllModals();
            }
        });

        // Botones de cerrar modal
        document.querySelectorAll('.btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const modal = e.target.closest('.modal');
                if (modal) {
                    this.closeModal(modal.id);
                }
            });
        });
    }

    /**
     * Actualizar frame de cámara
     */
    updateCameraFrame(data) {
        if (this.elements.cameraFeed && data.frame) {
            this.elements.cameraFeed.src = data.frame;
        }

        if (this.elements.fpsDisplay) {
            this.elements.fpsDisplay.textContent = `${data.fps} FPS`;
        }

        // Actualizar información de detección
        if (data.deteccion_activa) {
            this.showDetectionProgress(data.deteccion_activa, data.progreso);
        } else {
            this.hideDetectionProgress();
        }

        // Actualizar estado de cámara
        this.updateCameraStatus(true);
    }

    /**
     * Mostrar progreso de detección
     */
    showDetectionProgress(material, progress) {
        if (!this.elements.detectionInfo) return;

        const config = this.materialConfig[material];
        if (!config) return;

        this.elements.detectionInfo.style.display = 'block';

        if (this.elements.materialName) {
            this.elements.materialName.textContent = config.name;
            this.elements.materialName.style.color = config.color;
        }

        if (this.elements.progressFill) {
            this.elements.progressFill.style.width = `${progress * 100}%`;
            this.elements.progressFill.style.background = `linear-gradient(90deg, ${config.color}, #4CAF50)`;
        }

        if (this.elements.progressText) {
            this.elements.progressText.textContent = `${Math.round(progress * 100)}%`;
        }
    }

    /**
     * Ocultar progreso de detección
     */
    hideDetectionProgress() {
        if (this.elements.detectionInfo) {
            this.elements.detectionInfo.style.display = 'none';
        }
    }

    /**
     * Mostrar modal de material detectado
     */
    showMaterialDetected(material) {
        const config = this.materialConfig[material];
        if (!config) return;

        // Actualizar contenido del modal
        if (this.elements.modalMaterialName) {
            this.elements.modalMaterialName.textContent = config.name;
        }

        if (this.elements.modalMaterialIcon) {
            this.elements.modalMaterialIcon.innerHTML = `<i class="${config.icon}"></i>`;
            this.elements.modalMaterialIcon.style.background =
                `linear-gradient(45deg, ${config.color}, #4CAF50)`;
        }

        // Mostrar modal
        this.showModal('material-modal');

    }

    /**
     * Mostrar éxito de procesamiento
     */
    showProcessingSuccess(data) {
        // Cerrar modal anterior
        this.closeModal('material-modal');

        // Actualizar contenido del modal de éxito
        if (this.elements.userName) {
            this.elements.userName.textContent = data.usuario.nombre;
        }

        if (this.elements.pointsEarned) {
            this.elements.pointsEarned.textContent = data.puntos;
        }

        if (this.elements.pointsTotal) {
            this.elements.pointsTotal.textContent = `${data.usuario.puntos_nuevos} puntos`;
        }

        // Mostrar modal de éxito
        this.showModal('success-modal');


        // Auto-cerrar después de 5 segundos
        this.modalTimeout = setTimeout(() => {
            this.closeModal('success-modal');
        }, 5000);

    }

    /**
     * Mostrar modal
     */
    showModal(modalId) {
        const modal = document.getElementById(modalId);
        if (modal) {
            modal.classList.add('show');
            document.body.style.overflow = 'hidden';
        }
    }

    /**
     * Cerrar modal
     */
    closeModal(modalId) {
        const modal = document.getElementById(modalId);
        if (modal) {
            modal.classList.remove('show');
            document.body.style.overflow = '';
        }

        // Limpiar timeout si existe
        if (this.modalTimeout) {
            clearTimeout(this.modalTimeout);
            this.modalTimeout = null;
        }
    }

    /**
     * Cerrar todos los modales
     */
    closeAllModals() {
        document.querySelectorAll('.modal').forEach(modal => {
            modal.classList.remove('show');
        });
        document.body.style.overflow = '';

        if (this.modalTimeout) {
            clearTimeout(this.modalTimeout);
            this.modalTimeout = null;
        }
    }

    /**
     * Mostrar error
     */
    showError(title, message) {
        if (this.elements.errorMessage) {
            this.elements.errorMessage.textContent = message;
        }

        const errorModal = document.getElementById('error-modal');
        if (errorModal) {
            const titleElement = errorModal.querySelector('.modal-header h2');
            if (titleElement) {
                titleElement.textContent = title;
            }
        }

        this.showModal('error-modal');
    }

    /**
     * Actualizar estado de la aplicación
     */
    updateAppState(state) {
        if (!state) return;


        // Actualizar estados de conexión
        this.updateCameraStatus(state.camera_active);
        this.updateNfcStatus(state.nfc_active);
        this.updateMqttStatus(state.mqtt_connected);

    }


    /**
     * Actualizar estados de conexión
     */
    updateConnectionStatus() {
        // Actualizar indicador general basado en WebSocket
        document.querySelectorAll('.status-item').forEach(item => {
            if (this.isConnected) {
                item.classList.add('active');
            } else {
                item.classList.remove('active');
            }
        });
    }

    updateCameraStatus(active) {
        if (this.elements.cameraStatus) {
            if (active) {
                this.elements.cameraStatus.classList.add('active');
            } else {
                this.elements.cameraStatus.classList.remove('active');
            }
        }
    }

    updateNfcStatus(active) {
        if (this.elements.nfcStatus) {
            if (active) {
                this.elements.nfcStatus.classList.add('active');
            } else {
                this.elements.nfcStatus.classList.remove('active');
            }
        }
    }

    updateMqttStatus(connected) {
        if (this.elements.mqttStatus) {
            if (connected) {
                this.elements.mqttStatus.classList.add('active');
            } else {
                this.elements.mqttStatus.classList.remove('active');
            }
        }
    }

    /**
     * Mostrar loading
     */
    showLoading() {
        if (this.elements.loadingOverlay) {
            this.elements.loadingOverlay.classList.remove('hidden');
        }
    }

    /**
     * Ocultar loading
     */
    hideLoading() {
        if (this.elements.loadingOverlay) {
            this.elements.loadingOverlay.classList.add('hidden');
        }
    }

    /**
     * Animar número
     */
    animateNumber(element, targetValue) {
        if (!element) return;

        const currentValue = parseInt(element.textContent) || 0;
        const increment = Math.ceil((targetValue - currentValue) / 20);

        if (increment === 0) return;

        const timer = setInterval(() => {
            const current = parseInt(element.textContent) || 0;
            const next = current + increment;

            if ((increment > 0 && next >= targetValue) || (increment < 0 && next <= targetValue)) {
                element.textContent = targetValue;
                clearInterval(timer);
            } else {
                element.textContent = next;
            }
        }, 50);
    }

    /**
     * Heartbeat para mantener conexión
     */
    startHeartbeat() {
        setInterval(() => {
            if (this.socket && this.isConnected) {
                this.socket.emit('request_status');
            }
        }, 30000); // Cada 30 segundos
    }

    /**
     * Solicitar reset del sistema
     */
    resetSystem() {
        if (this.socket && this.isConnected) {
            fetch('/api/reset', { method: 'POST' })
                .then(response => response.json())
                .then(data => {
                    console.log('🔄 Sistema reseteado:', data);
                })
                .catch(error => {
                    console.error('❌ Error reseteando sistema:', error);
                });
        }
    }
}

// Función global para cerrar modales (usada en HTML)
window.closeModal = function(modalId) {
    if (window.app) {
        window.app.closeModal(modalId);
    }
};

// ========== FUNCIONES VINCULACIÓN NFC ==========

let nfcLinkState = {
    currentStep: 1,
    foundUser: null,
    isReading: false
};

/**
 * Abrir modal de vinculación NFC
 */
window.openNfcLinkModal = function() {
    console.log('🔗 Abriendo modal de vinculación NFC');

    // Reset state
    nfcLinkState = {
        currentStep: 1,
        foundUser: null,
        isReading: false
    };

    // Mostrar modal y paso 1
    const modal = document.getElementById('nfc-link-modal');
    modal.style.display = 'flex';
    modal.classList.add('show');
    showNfcStep(1);

    // Focus en input PIN
    setTimeout(() => {
        document.getElementById('user-pin').focus();
    }, 300);
};

/**
 * Cerrar modal de vinculación NFC
 */
window.closeNfcLinkModal = function() {
    console.log('🔗 Cerrando modal de vinculación NFC');

    // Cancelar lectura NFC si está activa
    if (nfcLinkState.isReading) {
        cancelNfcReading();
    }

    // Ocultar modal
    const modal = document.getElementById('nfc-link-modal');
    modal.classList.remove('show');
    setTimeout(() => {
        modal.style.display = 'none';
    }, 300);

    // Reset form
    document.getElementById('user-pin').value = '';
    hideNfcError();

    // Reset state
    nfcLinkState = {
        currentStep: 1,
        foundUser: null,
        isReading: false
    };
};

/**
 * Mostrar paso específico del modal
 */
function showNfcStep(stepNumber) {
    // Ocultar todos los pasos
    for (let i = 1; i <= 4; i++) {
        const step = document.getElementById(`nfc-step-${i}`);
        if (step) {
            step.style.display = 'none';
        }
    }

    // Mostrar paso actual
    const currentStep = document.getElementById(`nfc-step-${stepNumber}`);
    if (currentStep) {
        currentStep.style.display = 'block';
        nfcLinkState.currentStep = stepNumber;
    }
}

/**
 * Validar PIN y buscar usuario
 */
window.validatePin = function() {
    const pinInput = document.getElementById('user-pin');
    const pin = pinInput.value.trim();

    console.log('🔍 Validando PIN:', pin);

    // Validar formato PIN
    if (!/^\d{6}$/.test(pin)) {
        showNfcError('El PIN debe tener exactamente 6 dígitos');
        return;
    }

    // Mostrar loading
    const button = event.target;
    const originalText = button.innerHTML;
    button.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Buscando...';
    button.disabled = true;

    // Buscar usuario por PIN
    if (window.app && window.app.socket) {
        window.app.socket.emit('search_user_by_pin', { pin: pin });

        // Timeout para la búsqueda
        setTimeout(() => {
            button.innerHTML = originalText;
            button.disabled = false;
        }, 10000);
    } else {
        showNfcError('No hay conexión con el servidor');
        button.innerHTML = originalText;
        button.disabled = false;
    }
};

/**
 * Mostrar error en modal NFC
 */
function showNfcError(message) {
    const errorDiv = document.getElementById('pin-error');
    const errorSpan = errorDiv.querySelector('span');

    errorSpan.textContent = message;
    errorDiv.style.display = 'flex';

    // Auto-hide después de 5 segundos
    setTimeout(() => {
        hideNfcError();
    }, 5000);
}

/**
 * Ocultar error en modal NFC
 */
function hideNfcError() {
    const errorDiv = document.getElementById('pin-error');
    errorDiv.style.display = 'none';
}

/**
 * Mostrar usuario encontrado
 */
function showUserFound(userData) {
    console.log('✅ Usuario encontrado:', userData);

    nfcLinkState.foundUser = userData;

    // Actualizar UI con datos del usuario
    document.getElementById('found-user-name').textContent = userData.usuario_nombre || 'Usuario';
    document.getElementById('found-user-email').textContent = userData.usuario_email || 'Sin email';

    // Mostrar paso 2
    showNfcStep(2);
}

/**
 * Iniciar lectura NFC
 */
window.startNfcReading = function() {
    console.log('📡 Iniciando lectura NFC');

    if (!nfcLinkState.foundUser) {
        showNfcError('No hay usuario seleccionado');
        return;
    }

    // Mostrar paso 3
    showNfcStep(3);
    nfcLinkState.isReading = true;

    // Verificar si hay lector físico conectado
    const hasPhysicalReader = window.app && window.app.nfcActive;

    if (hasPhysicalReader) {
        updateNfcStatus('Esperando llavero NFC...', 'waiting');
        document.getElementById('nfc-instruction').textContent = 'Mantén el llavero cerca del lector NFC';
        document.getElementById('nfc-simulation-notice').style.display = 'none';
    } else {
        updateNfcStatus('Lector NFC no disponible', 'error');
        document.getElementById('nfc-instruction').textContent = 'Conecta un lector NFC para continuar';
        document.getElementById('nfc-simulation-notice').style.display = 'flex';

        // Mostrar error después de 2 segundos
        setTimeout(() => {
            handleNfcLinkError({
                message: 'No hay lector NFC conectado. Conecta un lector e inténtalo de nuevo.'
            });
        }, 2000);

        return; // No continuar sin lector
    }

    // Solicitar activación del lector NFC
    if (window.app && window.app.socket) {
        window.app.socket.emit('start_nfc_linking', {
            userId: nfcLinkState.foundUser.id,
            userName: nfcLinkState.foundUser.usuario_nombre
        });
    }

    // Timeout para lectura NFC (60 segundos)
    setTimeout(() => {
        if (nfcLinkState.isReading) {
            cancelNfcReading();
            showNfcError('Tiempo de espera agotado. Inténtalo de nuevo.');
        }
    }, 60000);
};

/**
 * Cancelar lectura NFC
 */
window.cancelNfcReading = function() {
    console.log('❌ Cancelando lectura NFC');

    nfcLinkState.isReading = false;

    // Notificar al servidor
    if (window.app && window.app.socket) {
        window.app.socket.emit('cancel_nfc_linking');
    }

    // Volver al paso 2
    showNfcStep(2);
};

/**
 * Actualizar estado de lectura NFC
 */
function updateNfcStatus(message, status) {
    const statusDiv = document.getElementById('nfc-status');
    const icon = statusDiv.querySelector('i');

    // Actualizar mensaje
    statusDiv.innerHTML = `<i class="fas fa-spinner fa-spin"></i> ${message}`;

    // Actualizar icono según estado
    if (status === 'waiting') {
        statusDiv.innerHTML = `<i class="fas fa-spinner fa-spin"></i> ${message}`;
    } else if (status === 'reading') {
        statusDiv.innerHTML = `<i class="fas fa-wifi"></i> ${message}`;
    } else if (status === 'success') {
        statusDiv.innerHTML = `<i class="fas fa-check-circle"></i> ${message}`;
    } else if (status === 'error') {
        statusDiv.innerHTML = `<i class="fas fa-exclamation-triangle"></i> ${message}`;
    }
}

/**
 * Mostrar éxito de vinculación
 */
function showNfcLinkSuccess(data) {
    console.log('🎉 Vinculación NFC exitosa:', data);

    nfcLinkState.isReading = false;

    // Actualizar UI con datos de éxito
    document.getElementById('linked-user-name').textContent = data.userName || 'Usuario';
    document.getElementById('linked-nfc-uid').textContent = data.nfcUid || 'XXXXXXXXXXXX';

    // Mostrar paso 4 (éxito)
    showNfcStep(4);
}

/**
 * Manejar error de vinculación NFC
 */
function handleNfcLinkError(error) {
    console.error('❌ Error en vinculación NFC:', error);

    nfcLinkState.isReading = false;
    updateNfcStatus(error.message || 'Error en la vinculación', 'error');

    // Volver al paso 2 después de 3 segundos
    setTimeout(() => {
        showNfcStep(2);
    }, 3000);
}

// Agregar event listener para Enter en input PIN
document.addEventListener('DOMContentLoaded', () => {
    const pinInput = document.getElementById('user-pin');
    if (pinInput) {
        pinInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                validatePin();
            }
        });
    }
});

// Inicializar aplicación cuando el DOM esté listo
document.addEventListener('DOMContentLoaded', () => {
    console.log('🌟 DOM cargado, inicializando aplicación...');
    window.app = new ReciclajeApp();
});

// Manejar errores globales
window.addEventListener('error', (event) => {
    console.error('❌ Error global:', event.error);
    if (window.app) {
        window.app.showError('Error de Aplicación', 'Ha ocurrido un error inesperado');
    }
});

// Manejar errores de promesas no capturadas
window.addEventListener('unhandledrejection', (event) => {
    console.error('❌ Promesa rechazada:', event.reason);
    if (window.app) {
        window.app.showError('Error de Conexión', 'Error en comunicación con el servidor');
    }
});
