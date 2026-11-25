
package it.unipi.dsmt.gatherseatweb.websocket;

import jakarta.websocket.OnClose;
import jakarta.websocket.OnError;
import jakarta.websocket.OnMessage;
import jakarta.websocket.OnOpen;
import jakarta.websocket.Session;
import jakarta.websocket.server.ServerEndpoint;

import java.io.IOException;
import java.time.Instant;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

@ServerEndpoint("/ws/events")
public class EventEndpoint {

    private static final Set<Session> CLIENTS =
            ConcurrentHashMap.newKeySet();

    @OnOpen
    public void onOpen(Session session) {

        CLIENTS.add(session);

        System.out.println(
                "[gatherseat.websocket]: WebSocket connected: " + session.getId()
        );

        sendMessage(session, "Connected to GatherSeat events");
    }

    @OnMessage
    public void onMessage(String message, Session session) {

        System.out.println(
                "[gatherseat.websocket]: Received from " + session.getId() + ": " + message
        );

        sendMessage(session, "Server received: " + message);
    }

    @OnClose
    public void onClose(Session session) {

        CLIENTS.remove(session);

        System.out.println(
                "[gatherseat.websocket]: WebSocket disconnected: " + session.getId()
        );
    }

    @OnError
    public void onError(Session session, Throwable error) {

        System.err.println(
                "WebSocket error for session "
                        + session.getId() + ": "
                        + error.getMessage()
        );

        CLIENTS.remove(session);
    }

    private void sendMessage(Session session, String message) {

        if (session.isOpen()) {
            session.getAsyncRemote().sendText(message);
        }
    }

    public static void broadcast(String message) {

        for (Session client : CLIENTS) {

            if (client.isOpen()) {
                client.getAsyncRemote().sendText(message);
            } else {
                CLIENTS.remove(client);
            }
        }
    }

    public static int getConnectedClientsCount() {
        return CLIENTS.size();
    }
}
