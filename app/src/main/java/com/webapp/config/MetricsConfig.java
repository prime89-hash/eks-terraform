package com.webapp.config;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Metrics Configuration for Prometheus monitoring
 * 
 * This configuration sets up custom metrics that will be exposed
 * to Prometheus for monitoring application performance and behavior.
 */
@Configuration
public class MetricsConfig {

    /**
     * Counter for HTTP requests
     * Tracks the total number of HTTP requests received
     */
    @Bean
    public Counter httpRequestsCounter(MeterRegistry meterRegistry) {
        return Counter.builder("http_requests_total")
                .description("Total number of HTTP requests")
                .tag("application", "webapp-3tier")
                .register(meterRegistry);
    }

    /**
     * Counter for database operations
     * Tracks database connection attempts and operations
     */
    @Bean
    public Counter databaseOperationsCounter(MeterRegistry meterRegistry) {
        return Counter.builder("database_operations_total")
                .description("Total number of database operations")
                .tag("application", "webapp-3tier")
                .register(meterRegistry);
    }

    /**
     * Timer for request processing time
     * Measures how long requests take to process
     */
    @Bean
    public Timer requestProcessingTimer(MeterRegistry meterRegistry) {
        return Timer.builder("request_processing_duration_seconds")
                .description("Time taken to process requests")
                .tag("application", "webapp-3tier")
                .register(meterRegistry);
    }
}
