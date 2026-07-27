package com.example.demoapi

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class HelloControllerTest {

    @Test
    fun `hello returns expected payload`() {
        val r = HelloController().hello()
        assertEquals("hello", r.message)
        assertEquals("demo-api", r.app)
        assertEquals("0.2.0", r.version)
    }
}
