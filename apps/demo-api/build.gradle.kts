plugins {
    kotlin("jvm") version "2.2.0"
    kotlin("plugin.spring") version "2.2.0"
    id("org.springframework.boot") version "4.0.0"
    id("io.spring.dependency-management") version "1.1.7"
}

group = "com.example"
version = "0.2.0"

java {
    toolchain { languageVersion.set(JavaLanguageVersion.of(21)) }
}

repositories { mavenCentral() }

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation("com.fasterxml.jackson.module:jackson-module-kotlin")
    testImplementation("org.springframework.boot:spring-boot-starter-test")
}

// bootJar만 산출 (plain jar 비활성화 → COPY build/libs/*.jar 안전)
tasks.named<Jar>("jar") { enabled = false }

kotlin {
    compilerOptions { freeCompilerArgs.add("-Xjsr305=strict") }
}
