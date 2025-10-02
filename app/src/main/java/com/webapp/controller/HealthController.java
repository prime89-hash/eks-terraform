package com.webapp.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import javax.sql.DataSource;
import java.sql.Connection;
import java.util.HashMap;
import java.util.Map;
import java.util.List;
import java.util.ArrayList;

/**
 * REST Controller for the 3-Tier Web Application
 * 
 * This controller provides endpoints for:
 * 1. Health checks - Used by load balancers and monitoring systems
 * 2. User management - CRUD operations for user entities
 * 3. System information - Application metadata and status
 * 
 * The controller demonstrates the 3-tier architecture:
 * - Presentation Tier: REST API endpoints (this controller)
 * - Business Logic Tier: Service methods and validation
 * - Data Tier: Database connectivity and operations
 */
@RestController
@RequestMapping("/")
@CrossOrigin(origins = "*")  // Enable CORS for API Gateway integration
public class HealthController {

    @Autowired
    private DataSource dataSource;

    /**
     * Health Check Endpoint - GET /health
     * 
     * This endpoint is used by:
     * - Application Load Balancer for health checks
     * - Kubernetes liveness and readiness probes
     * - Monitoring systems (Prometheus, CloudWatch)
     * - API Gateway health monitoring
     * 
     * Returns comprehensive health information including:
     * - Application status
     * - Database connectivity
     * - System metadata
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> health() {
        Map<String, Object> status = new HashMap<>();
        
        // Basic application information
        status.put("status", "UP");
        status.put("service", "webapp-3tier");
        status.put("version", "1.0.0");
        status.put("timestamp", System.currentTimeMillis());
        status.put("tier", "Application Tier (Spring Boot on EKS Fargate)");
        
        // Environment information
        status.put("environment", System.getenv().getOrDefault("ENVIRONMENT", "development"));
        status.put("kubernetes_namespace", System.getenv().getOrDefault("KUBERNETES_NAMESPACE", "default"));
        status.put("pod_name", System.getenv().getOrDefault("HOSTNAME", "unknown"));
        
        // Database connectivity check (Data Tier validation)
        Map<String, Object> database = new HashMap<>();
        try (Connection connection = dataSource.getConnection()) {
            database.put("status", "UP");
            database.put("type", "PostgreSQL");
            database.put("url", connection.getMetaData().getURL());
            database.put("driver", connection.getMetaData().getDriverName());
            database.put("connection_valid", connection.isValid(5));
        } catch (Exception e) {
            database.put("status", "DOWN");
            database.put("error", e.getMessage());
            database.put("type", "PostgreSQL");
        }
        status.put("database", database);
        
        // System resources
        Runtime runtime = Runtime.getRuntime();
        Map<String, Object> system = new HashMap<>();
        system.put("processors", runtime.availableProcessors());
        system.put("memory_total_mb", runtime.totalMemory() / 1024 / 1024);
        system.put("memory_free_mb", runtime.freeMemory() / 1024 / 1024);
        system.put("memory_used_mb", (runtime.totalMemory() - runtime.freeMemory()) / 1024 / 1024);
        status.put("system", system);
        
        // Return appropriate HTTP status based on overall health
        boolean isHealthy = "UP".equals(((Map<String, Object>) status.get("database")).get("status"));
        
        return isHealthy ? 
            ResponseEntity.ok(status) : 
            ResponseEntity.status(503).body(status);  // Service Unavailable if DB is down
    }

    /**
     * Root Endpoint - GET /
     * 
     * Welcome endpoint that provides basic application information
     * This is often the first endpoint users hit when testing the application
     */
    @GetMapping("/")
    public ResponseEntity<Map<String, Object>> root() {
        Map<String, Object> response = new HashMap<>();
        response.put("message", "Welcome to 3-Tier Web Application on AWS EKS");
        response.put("architecture", "Presentation → Application → Data");
        response.put("presentation_tier", "API Gateway + Application Load Balancer");
        response.put("application_tier", "Spring Boot on EKS Fargate");
        response.put("data_tier", "RDS PostgreSQL with encryption");
        response.put("environment", System.getenv().getOrDefault("ENVIRONMENT", "development"));
        response.put("version", "1.0.0");
        response.put("documentation", "/health for health check, /api/users for user management");
        
        return ResponseEntity.ok(response);
    }

    /**
     * Get All Users - GET /api/users
     * 
     * This endpoint demonstrates the Business Logic Tier
     * In a real application, this would:
     * 1. Validate request parameters
     * 2. Apply business rules
     * 3. Query the database (Data Tier)
     * 4. Transform data for presentation
     * 
     * Currently returns mock data for demonstration
     */
    @GetMapping("/api/users")
    public ResponseEntity<Map<String, Object>> getUsers(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size) {
        
        Map<String, Object> response = new HashMap<>();
        
        // Mock user data (in real app, this would come from database)
        List<Map<String, Object>> users = new ArrayList<>();
        
        for (int i = 1; i <= 5; i++) {
            Map<String, Object> user = new HashMap<>();
            user.put("id", i);
            user.put("name", "User " + i);
            user.put("email", "user" + i + "@example.com");
            user.put("age", 25 + i);
            user.put("created_at", "2024-01-" + String.format("%02d", i) + "T10:00:00Z");
            users.add(user);
        }
        
        // Response metadata
        response.put("users", users);
        response.put("total", users.size());
        response.put("page", page);
        response.put("size", size);
        response.put("tier", "Business Logic Layer");
        response.put("data_source", "Mock Data (replace with database queries)");
        
        return ResponseEntity.ok(response);
    }

    /**
     * Create User - POST /api/users
     * 
     * Demonstrates POST request handling with request body validation
     * In production, this would:
     * 1. Validate input data
     * 2. Apply business rules (duplicate check, etc.)
     * 3. Save to database
     * 4. Return created user with generated ID
     */
    @PostMapping("/api/users")
    public ResponseEntity<Map<String, Object>> createUser(@RequestBody Map<String, Object> userData) {
        Map<String, Object> response = new HashMap<>();
        
        // Basic validation (in real app, use @Valid and DTOs)
        if (!userData.containsKey("name") || !userData.containsKey("email")) {
            response.put("error", "Missing required fields: name and email");
            response.put("status", "BAD_REQUEST");
            return ResponseEntity.badRequest().body(response);
        }
        
        // Mock user creation (in real app, save to database)
        Map<String, Object> createdUser = new HashMap<>();
        createdUser.put("id", System.currentTimeMillis() % 10000);  // Mock ID generation
        createdUser.put("name", userData.get("name"));
        createdUser.put("email", userData.get("email"));
        createdUser.put("age", userData.getOrDefault("age", 0));
        createdUser.put("created_at", java.time.Instant.now().toString());
        createdUser.put("status", "active");
        
        response.put("message", "User created successfully");
        response.put("user", createdUser);
        response.put("tier", "Business Logic Layer");
        response.put("operation", "CREATE");
        
        return ResponseEntity.status(201).body(response);  // HTTP 201 Created
    }

    /**
     * Get User by ID - GET /api/users/{id}
     * 
     * Demonstrates path parameter handling
     * Shows how to handle resource-specific requests
     */
    @GetMapping("/api/users/{id}")
    public ResponseEntity<Map<String, Object>> getUserById(@PathVariable Long id) {
        Map<String, Object> response = new HashMap<>();
        
        // Mock user lookup (in real app, query database by ID)
        if (id <= 0 || id > 1000) {
            response.put("error", "User not found");
            response.put("user_id", id);
            response.put("status", "NOT_FOUND");
            return ResponseEntity.notFound().build();
        }
        
        // Mock user data
        Map<String, Object> user = new HashMap<>();
        user.put("id", id);
        user.put("name", "User " + id);
        user.put("email", "user" + id + "@example.com");
        user.put("age", 25 + (id % 50));
        user.put("created_at", "2024-01-01T10:00:00Z");
        user.put("last_login", java.time.Instant.now().toString());
        user.put("status", "active");
        
        response.put("user", user);
        response.put("tier", "Business Logic Layer");
        response.put("operation", "READ");
        
        return ResponseEntity.ok(response);
    }

    /**
     * System Information - GET /api/system
     * 
     * Provides detailed system information for monitoring and debugging
     * Useful for operations teams and monitoring systems
     */
    @GetMapping("/api/system")
    public ResponseEntity<Map<String, Object>> getSystemInfo() {
        Map<String, Object> system = new HashMap<>();
        
        // Application information
        system.put("application_name", "webapp-3tier");
        system.put("version", "1.0.0");
        system.put("build_time", "2024-01-01T00:00:00Z");
        system.put("spring_boot_version", org.springframework.boot.SpringBootVersion.getVersion());
        
        // Runtime information
        Runtime runtime = Runtime.getRuntime();
        Map<String, Object> jvm = new HashMap<>();
        jvm.put("java_version", System.getProperty("java.version"));
        jvm.put("java_vendor", System.getProperty("java.vendor"));
        jvm.put("processors", runtime.availableProcessors());
        jvm.put("memory_total_mb", runtime.totalMemory() / 1024 / 1024);
        jvm.put("memory_free_mb", runtime.freeMemory() / 1024 / 1024);
        jvm.put("memory_max_mb", runtime.maxMemory() / 1024 / 1024);
        system.put("jvm", jvm);
        
        // Environment information
        Map<String, Object> environment = new HashMap<>();
        environment.put("environment", System.getenv().getOrDefault("ENVIRONMENT", "development"));
        environment.put("kubernetes_namespace", System.getenv().getOrDefault("KUBERNETES_NAMESPACE", "default"));
        environment.put("pod_name", System.getenv().getOrDefault("HOSTNAME", "unknown"));
        environment.put("node_name", System.getenv().getOrDefault("NODE_NAME", "unknown"));
        system.put("environment", environment);
        
        // Database information (without sensitive data)
        Map<String, Object> database = new HashMap<>();
        try (Connection connection = dataSource.getConnection()) {
            database.put("type", "PostgreSQL");
            database.put("driver_version", connection.getMetaData().getDriverVersion());
            database.put("database_product", connection.getMetaData().getDatabaseProductName());
            database.put("database_version", connection.getMetaData().getDatabaseProductVersion());
            database.put("connection_valid", connection.isValid(5));
        } catch (Exception e) {
            database.put("error", "Database connection failed");
            database.put("type", "PostgreSQL");
        }
        system.put("database", database);
        
        return ResponseEntity.ok(system);
    }

    /**
     * Metrics Endpoint - GET /api/metrics
     * 
     * Provides application-specific metrics for monitoring
     * This complements the /actuator/prometheus endpoint
     */
    @GetMapping("/api/metrics")
    public ResponseEntity<Map<String, Object>> getMetrics() {
        Map<String, Object> metrics = new HashMap<>();
        
        // Application metrics
        metrics.put("uptime_seconds", java.lang.management.ManagementFactory.getRuntimeMXBean().getUptime() / 1000);
        metrics.put("requests_total", 1000 + (System.currentTimeMillis() % 10000));  // Mock counter
        metrics.put("requests_per_second", 10 + (System.currentTimeMillis() % 50));  // Mock rate
        
        // JVM metrics
        Runtime runtime = Runtime.getRuntime();
        Map<String, Object> jvm = new HashMap<>();
        jvm.put("memory_used_bytes", runtime.totalMemory() - runtime.freeMemory());
        jvm.put("memory_total_bytes", runtime.totalMemory());
        jvm.put("memory_max_bytes", runtime.maxMemory());
        jvm.put("gc_collections", java.lang.management.ManagementFactory.getGarbageCollectorMXBeans().size());
        metrics.put("jvm", jvm);
        
        // Database metrics (mock)
        Map<String, Object> database = new HashMap<>();
        database.put("connections_active", 5);
        database.put("connections_max", 20);
        database.put("queries_total", 5000 + (System.currentTimeMillis() % 1000));
        database.put("query_duration_avg_ms", 50 + (System.currentTimeMillis() % 100));
        metrics.put("database", database);
        
        return ResponseEntity.ok(metrics);
    }
}
