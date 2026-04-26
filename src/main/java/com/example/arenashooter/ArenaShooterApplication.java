package com.example.arenashooter;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class ArenaShooterApplication {

	public static void main(String[] args) {
		SpringApplication.run(ArenaShooterApplication.class, args);
	}
}
