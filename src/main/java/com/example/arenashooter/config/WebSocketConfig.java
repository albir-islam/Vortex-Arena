package com.example.arenashooter.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.lang.NonNull;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;

import com.example.arenashooter.websocket.GameWebSocketHandler;
import com.example.arenashooter.multiplayer.handler.MultiplayerWebSocketHandler;

@Configuration
@EnableWebSocket
public class WebSocketConfig implements WebSocketConfigurer {

    private final GameWebSocketHandler handler;
    private final MultiplayerWebSocketHandler multiplayerHandler;

    public WebSocketConfig(GameWebSocketHandler handler, MultiplayerWebSocketHandler multiplayerHandler) {
        this.handler = handler;
        this.multiplayerHandler = multiplayerHandler;
    }

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        // Legacy single-player WebSocket endpoint
        registry.addHandler(handler, "/ws/game")
                .setAllowedOrigins("*");
        
        // New multiplayer WebSocket endpoint
        registry.addHandler(multiplayerHandler, "/ws/multiplayer")
                .setAllowedOrigins("*");
    }
}
