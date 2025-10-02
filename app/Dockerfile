# Multi-stage build for security and size optimization
FROM gradle:8.4-jdk17-alpine AS builder

WORKDIR /app
COPY build.gradle settings.gradle ./
COPY src ./src

# Build the application
RUN gradle build --no-daemon -x test

# Runtime stage
FROM openjdk:17-jdk-alpine

# Create non-root user for security
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# Install security updates
RUN apk update && apk upgrade && \
    apk add --no-cache curl && \
    rm -rf /var/cache/apk/*

WORKDIR /app

# Copy the built JAR from builder stage
COPY --from=builder /app/build/libs/webapp.jar ./webapp.jar

# Change ownership to non-root user
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Run the application
ENTRYPOINT ["java", "-jar", "-Djava.security.egd=file:/dev/./urandom", "webapp.jar"]
