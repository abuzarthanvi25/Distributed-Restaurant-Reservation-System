// page specific behaviour
console.log('[webapp.assets.js.pages.restaurant]: Hello restaurants page behaviour')

function updateSocketStatus(socketStatusText, status){
    if (typeof socketStatusText !== 'string' || typeof status !== "boolean") return null;
    const socketStatusSpan = document.getElementById('socket-status');
    socketStatusSpan.innerText = socketStatusText;
    socketStatusSpan.classList.toggle('socket-connected', status);
}

const socket = new WebSocket("ws://localhost:8080/ws/events");

socket.onopen = () => {
    updateSocketStatus('Connected', true);
    console.log("[socket client in restaurants.js]: Connected");
    socket.send("Hello GatherSeat");
};

socket.onmessage = (event) => {
    console.log("[socket client in restaurants.js]: Server:", event.data);
};

socket.onerror = (error) => {
    updateSocketStatus('Failed to connect', false);
    console.error("[socket client in restaurants.js]: WebSocket error:", error);
};

socket.onclose = () => {
    updateSocketStatus('Disconnected', false);
    console.log("[socket client in restaurants.js]: Disconnected");
};