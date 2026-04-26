package com.example.arenashooter.websocket;

import org.springframework.stereotype.Component;
import org.springframework.lang.NonNull;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.core.type.TypeReference;
import org.springframework.web.socket.*;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class GameWebSocketHandler extends TextWebSocketHandler {

    static class Player {
        public int id;
        public double x = 200;
        public double y = 200;
        public int hp = 100;
        public WebSocketSession session;
    }

    private final Map<WebSocketSession, Player> players = new ConcurrentHashMap<>();
    private final ObjectMapper mapper = new ObjectMapper();
    private int nextId = 1;

    @Override
    public void afterConnectionEstablished(@NonNull WebSocketSession session) throws Exception {
        Player p = new Player();
        p.id = nextId++;
        p.session = session;
        players.put(session, p);
        System.out.println("Player " + p.id + " joined");
    }

    @Override
    protected void handleTextMessage(@NonNull WebSocketSession session, @NonNull TextMessage message) throws Exception {
        Player p = players.get(session);
        if (p == null)
            return;

        Map<String, Object> data = mapper.readValue(message.getPayload(), new TypeReference<Map<String, Object>>() {
        });

        if ("MOVE".equals(data.get("type"))) {
            Object xVal = data.get("x");
            Object yVal = data.get("y");
            if (xVal instanceof Number) {
                p.x = ((Number) xVal).doubleValue();
            }
            if (yVal instanceof Number) {
                p.y = ((Number) yVal).doubleValue();
            }
        }

        if ("SHOOT".equals(data.get("type"))) {
            // damage first other player
            players.values().stream()
                    .filter(o -> o != p)
                    .findFirst()
                    .ifPresent(t -> t.hp -= 10);
        }
    }

    @Override
    public void afterConnectionClosed(@NonNull WebSocketSession session, @NonNull CloseStatus status) throws Exception {
        Player p = players.remove(session);
        if (p != null) {
            System.out.println("Player " + p.id + " disconnected");
        }
    }

    @Override
    public void handleTransportError(@NonNull WebSocketSession session, @NonNull Throwable exception) throws Exception {
        System.err.println("WebSocket transport error: " + exception.getMessage());
    }

    public void tick() throws Exception {
        Map<String, Object> state = new HashMap<>();
        state.put("type", "STATE");

        List<Map<String, Object>> list = new ArrayList<>();
        for (Player p : players.values()) {
            Map<String, Object> m = new HashMap<>();
            m.put("id", p.id);
            m.put("x", p.x);
            m.put("y", p.y);
            m.put("hp", p.hp);
            list.add(m);
        }

        state.put("players", list);

        String json = mapper.writeValueAsString(state);
        if (json != null) {
            for (Player p : players.values()) {
                if (p.session != null && p.session.isOpen()) {
                    p.session.sendMessage(new TextMessage(json));
                }
            }
        }
    }
}
