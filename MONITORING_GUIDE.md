# 📊 Monitoring Guide: Prometheus & Grafana

This guide explains how to use the comprehensive monitoring stack deployed with your 3-tier application.

## 🏗️ Monitoring Architecture

```
Application → Prometheus → Grafana
     ↓            ↓          ↓
  Metrics    Storage    Visualization
```

### Components Deployed:
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **AlertManager**: Alert handling and notifications
- **Node Exporter**: System metrics
- **Kube State Metrics**: Kubernetes cluster metrics
- **CloudWatch**: AWS native monitoring

## 🚀 Quick Access

### 1. Access Grafana Dashboard
```bash
# Port forward to Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Open browser to: http://localhost:3000
# Username: admin
# Password: admin123
```

### 2. Access Prometheus
```bash
# Port forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Open browser to: http://localhost:9090
```

### 3. Access AlertManager
```bash
# Port forward to AlertManager
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093

# Open browser to: http://localhost:9093
```

## 📈 Available Dashboards

### Pre-installed Grafana Dashboards:
1. **Kubernetes Cluster Overview** (ID: 7249)
   - Cluster resource usage
   - Node performance
   - Pod status and health

2. **Node Exporter Dashboard** (ID: 1860)
   - System metrics (CPU, Memory, Disk, Network)
   - Hardware monitoring
   - OS-level statistics

3. **Spring Boot Dashboard** (ID: 12900)
   - Application-specific metrics
   - JVM performance
   - HTTP request metrics

### Custom Application Metrics:
- **HTTP Requests**: Total requests, response times
- **Database Operations**: Connection pool, query performance
- **JVM Metrics**: Memory usage, garbage collection
- **Custom Business Metrics**: User actions, feature usage

## 🔍 Key Metrics to Monitor

### Application Health:
```promql
# HTTP request rate
rate(http_requests_total[5m])

# Response time percentiles
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Error rate
rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])
```

### Infrastructure Health:
```promql
# CPU usage
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk usage
100 - ((node_filesystem_avail_bytes * 100) / node_filesystem_size_bytes)
```

### Kubernetes Metrics:
```promql
# Pod restart count
increase(kube_pod_container_status_restarts_total[1h])

# Pod CPU usage
rate(container_cpu_usage_seconds_total[5m])

# Pod memory usage
container_memory_usage_bytes / container_spec_memory_limit_bytes * 100
```

## 🚨 Alerting

### Pre-configured Alerts:
- **High CPU Usage**: >80% for 5 minutes
- **High Memory Usage**: >80% for 5 minutes
- **Pod Restart**: Pod restarted more than 3 times in 1 hour
- **Database Connection Issues**: Connection failures
- **High Error Rate**: >5% error rate for 5 minutes

### Alert Destinations:
- **Email**: admin@example.com (configure in SNS)
- **Slack**: Configure webhook in AlertManager
- **PagerDuty**: Configure integration key

## 📊 Creating Custom Dashboards

### 1. Import Dashboard from Grafana.com:
1. Go to Grafana → "+" → Import
2. Enter dashboard ID (e.g., 7249 for Kubernetes)
3. Select Prometheus as data source
4. Click Import

### 2. Create Custom Dashboard:
1. Go to Grafana → "+" → Dashboard
2. Add Panel → Select visualization type
3. Write PromQL query
4. Configure display options
5. Save dashboard

### Example Custom Panel:
```json
{
  "title": "Application Response Time",
  "type": "graph",
  "targets": [
    {
      "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job=\"webapp-3tier\"}[5m]))",
      "legendFormat": "95th percentile"
    }
  ]
}
```

## 🔧 Troubleshooting

### Common Issues:

#### 1. Grafana Not Accessible
```bash
# Check Grafana pod status
kubectl get pods -n monitoring | grep grafana

# Check Grafana logs
kubectl logs -n monitoring deployment/prometheus-grafana

# Restart Grafana
kubectl rollout restart deployment/prometheus-grafana -n monitoring
```

#### 2. Prometheus Not Scraping Metrics
```bash
# Check ServiceMonitor
kubectl get servicemonitor -n monitoring

# Check Prometheus targets
# Go to Prometheus UI → Status → Targets

# Check application metrics endpoint
kubectl port-forward -n webapp svc/webapp-service 8080:80
curl http://localhost:8080/actuator/prometheus
```

#### 3. No Application Metrics
```bash
# Verify metrics endpoint is exposed
kubectl describe svc webapp-service -n webapp

# Check if ServiceMonitor is created
kubectl get servicemonitor webapp-service-monitor -n monitoring

# Verify Prometheus configuration
kubectl get prometheus -n monitoring -o yaml
```

## 📚 Advanced Configuration

### Custom Metrics in Application:
```java
// Add to your Spring Boot controller
@Autowired
private Counter httpRequestsCounter;

@GetMapping("/api/users")
public ResponseEntity<?> getUsers() {
    httpRequestsCounter.increment();
    // Your logic here
}
```

### Custom AlertManager Rules:
```yaml
groups:
- name: webapp.rules
  rules:
  - alert: HighErrorRate
    expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "High error rate detected"
```

## 🎯 Best Practices

### 1. Dashboard Organization:
- Create folders for different teams/services
- Use consistent naming conventions
- Add descriptions to panels
- Set appropriate time ranges

### 2. Alert Management:
- Avoid alert fatigue with proper thresholds
- Use alert grouping and routing
- Implement escalation policies
- Regular alert review and tuning

### 3. Metric Collection:
- Monitor what matters to your business
- Use appropriate metric types (counter, gauge, histogram)
- Add meaningful labels
- Avoid high cardinality metrics

### 4. Performance:
- Set appropriate retention periods
- Use recording rules for complex queries
- Monitor Prometheus resource usage
- Regular cleanup of unused metrics

## 📞 Support

For monitoring issues:
1. Check this guide first
2. Review Prometheus/Grafana logs
3. Verify network connectivity
4. Check resource limits and quotas

## 🔗 Useful Links

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [PromQL Tutorial](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Dashboard Gallery](https://grafana.com/grafana/dashboards/)
