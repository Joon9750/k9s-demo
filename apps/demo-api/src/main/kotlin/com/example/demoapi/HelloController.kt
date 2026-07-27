package com.example.demoapi

import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

data class HelloResponse(val message: String, val app: String, val version: String)

@RestController
@RequestMapping("/api")
class HelloController {
    @GetMapping("/hello")
    fun hello(): HelloResponse {
        // ConfigMap → env GREETING (없으면 기본 "hello")
        val greeting = System.getenv("GREETING") ?: "hello"
        return HelloResponse(message = greeting, app = "demo-api", version = "0.2.0")
    }
}
