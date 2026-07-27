package com.example.demoapi

import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

data class HelloResponse(val message: String, val app: String, val version: String)

@RestController
@RequestMapping("/api")
class HelloController {
    @GetMapping("/hello")
    fun hello(): HelloResponse =
        HelloResponse(message = "hello", app = "demo-api", version = "0.1.0")
}
