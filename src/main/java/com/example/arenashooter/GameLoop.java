package com.example.arenashooter;

import com.example.arenashooter.websocket.GameWebSocketHandler;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class GameLoop {

    private final GameWebSocketHandler handler;

    public GameLoop(GameWebSocketHandler handler) {
        this.handler = handler;
    }

    @Scheduled(fixedRate = 50)
    public void tick() {
        try {
            handler.tick();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
