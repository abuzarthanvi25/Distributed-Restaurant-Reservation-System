
/**
 * GatherSeat - WebSocket Event Client
 *
 * Responsibilities:
 * - Manage WebSocket connection lifecycle
 * - Track connection status
 * - Reconnect after unexpected disconnections
 * - Parse incoming server messages
 * - Dispatch events to registered handlers
 *
 * Backend endpoint: /ws/events
 *
 * NOTE:
 * autoConnect is false until the Java WebSocket endpoint
 * has been implemented.
 */

const GSEvents = (() => {

    // =========================================
    // 1. Configuration
    // =========================================

    const CONFIG = {
        endpoint: "/ws/events",
        autoConnect: false,
        reconnectDelay: 1000,
        maxReconnectDelay: 30000
    };

    // =========================================
    // 2. Internal state
    // =========================================

    let socket = null;
    let state = "disconnected";
    let reconnectAttempts = 0;
    let reconnectTimer = null;
    let shouldReconnect = false;

    const listeners = new Map();

    // =========================================
    // 3. Connection status
    // =========================================

    function updateStatus(newState) {
        state = newState;

        const statusElement = document.getElementById("conn");

        if (!statusElement) return;

        const labels = {
            connecting: "Connecting...",
            connected: "Connected",
            disconnected: "Disconnected",
            error: "Connection error",
            reconnecting: "Reconnecting..."
        };

        statusElement.textContent =
            labels[newState] || "Not connected";

        statusElement.dataset.state = newState;
    }

    // =========================================
    // 4. WebSocket URL
    // =========================================

    function getWebSocketURL() {
        const contextPath =
            document.body.dataset.ctx || "";

        const protocol =
            window.location.protocol === "https:"
                ? "wss:"
                : "ws:";

        return `${protocol}//${window.location.host}`
            + `${contextPath}${CONFIG.endpoint}`;
    }

    // =========================================
    // 5. Connect
    // =========================================

    function connect() {

        if (
            socket &&
            (socket.readyState === WebSocket.OPEN ||
                socket.readyState === WebSocket.CONNECTING)
        ) {
            return;
        }

        clearTimeout(reconnectTimer);
        shouldReconnect = true;

        updateStatus(
            reconnectAttempts > 0
                ? "reconnecting"
                : "connecting"
        );

        try {
            socket = new WebSocket(getWebSocketURL());

            socket.onopen = handleOpen;
            socket.onmessage = handleMessage;
            socket.onclose = handleClose;
            socket.onerror = handleError;

        } catch (error) {
            console.error(
                "[GatherSeat] WebSocket connection failed:",
                error
            );

            socket = null;
            updateStatus("error");
            scheduleReconnect();
        }
    }

    // =========================================
    // 6. Connection handlers
    // =========================================

    function handleOpen() {
        console.info("[GatherSeat] WebSocket connected");

        reconnectAttempts = 0;
        updateStatus("connected");
    }

    function handleMessage(event) {
        let message;

        try {
            message = JSON.parse(event.data);
        } catch (error) {
            console.error(
                "[GatherSeat] Invalid WebSocket message:",
                error
            );
            return;
        }

        if (!message || typeof message.type !== "string") {
            console.warn(
                "[GatherSeat] Unknown message format:",
                message
            );
            return;
        }

        dispatch(message.type, message);
    }

    function handleClose(event) {
        console.info(
            "[GatherSeat] WebSocket disconnected:",
            event.code
        );

        socket = null;
        updateStatus("disconnected");

        if (shouldReconnect) {
            scheduleReconnect();
        }
    }

    function handleError(error) {
        console.error(
            "[GatherSeat] WebSocket error:",
            error
        );

        updateStatus("error");
    }

    // =========================================
    // 7. Reconnection
    // =========================================

    function scheduleReconnect() {
        if (!shouldReconnect || reconnectTimer) return;

        const delay = Math.min(
            CONFIG.reconnectDelay *
            Math.pow(2, reconnectAttempts),
            CONFIG.maxReconnectDelay
        );

        reconnectAttempts++;

        console.info(
            `[GatherSeat] Reconnecting in ${delay}ms`
        );

        reconnectTimer = setTimeout(() => {
            reconnectTimer = null;
            connect();
        }, delay);
    }

    // =========================================
    // 8. Event subscription
    // =========================================

    function on(eventType, callback) {
        if (!listeners.has(eventType)) {
            listeners.set(eventType, new Set());
        }

        listeners.get(eventType).add(callback);
    }

    function off(eventType, callback) {
        listeners.get(eventType)?.delete(callback);
    }

    function dispatch(eventType, message) {
        const handlers = listeners.get(eventType);

        if (!handlers) return;

        handlers.forEach(callback => {
            try {
                callback(message);
            } catch (error) {
                console.error(
                    `[GatherSeat] Error handling ${eventType}:`,
                    error
                );
            }
        });
    }

    // =========================================
    // 9. Disconnect
    // =========================================

    function disconnect() {
        shouldReconnect = false;

        clearTimeout(reconnectTimer);
        reconnectTimer = null;

        if (socket) {
            const currentSocket = socket;
            socket = null;
            currentSocket.close(1000, "Client disconnected");
        }

        reconnectAttempts = 0;
        updateStatus("disconnected");
    }

    // =========================================
    // 10. Public interface
    // =========================================

    function getState() {
        return state;
    }

    if (CONFIG.autoConnect) {
        connect();
    }

    return {
        connect,
        disconnect,
        on,
        off,
        getState
    };

})();