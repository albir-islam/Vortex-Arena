package com.example.arenashooter.controller;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.arenashooter.dto.LoginRequest;
import com.example.arenashooter.dto.PlayerProfileDto;
import com.example.arenashooter.service.AuthService;

@RestController
@RequestMapping("/auth")
public class AuthController {
    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/login")
    public PlayerProfileDto login(@RequestBody LoginRequest request) {
        return authService.login(request);
    }

    @PostMapping("/register")
    public PlayerProfileDto register(@RequestBody LoginRequest request) {
        // Reuse login logic for "create if not exists" as per original implementation
        // Or strictly separate. For now, matching "Login or Create" behavior.
        return authService.login(request);
    }
}
