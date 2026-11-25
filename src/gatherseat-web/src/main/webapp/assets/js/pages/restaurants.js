// page specific behaviour
console.log('[webapp.assets.js.pages.restaurant]: Hello restaurants page behaviour')

const socket = new WebSocket("ws://localhost:8080/ws/events");

socket.onopen = () => {
    console.log("[socket client in restaurants.js]: Connected");
    socket.send("Hello GatherSeat");
};

socket.onmessage = (event) => {
    console.log("[socket client in restaurants.js]: Server:", event.data);
};

socket.onerror = (error) => {
    console.error("[socket client in restaurants.js]: WebSocket error:", error);
};

socket.onclose = () => {
    console.log("[socket client in restaurants.js]: Disconnected");
};