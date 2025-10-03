# =============================================================================
# MONITORING AND OBSERVABILITY STACK
# =============================================================================
# Comprehensive monitoring setup with Prometheus, Grafana, and CloudWatch

# Create monitoring namespace
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      name = "monitoring"
    }
  }
  depends_on = [module.eks]
}

# =============================================================================
# PROMETHEUS STACK
# =============================================================================
# Prometheus and Grafana for monitoring using kube-prometheus-stack

resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  version    = "55.5.0"

  create_namespace = false  # We create it above

  values = [
    yamlencode({
      # Prometheus configuration
      prometheus = {
        prometheusSpec = {
          retention = "15d"
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "gp2"
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "20Gi"
                  }
                }
              }
            }
          }
          # Service monitor selector
          serviceMonitorSelectorNilUsesHelmValues = false
          serviceMonitorSelector = {}
          podMonitorSelectorNilUsesHelmValues = false
          podMonitorSelector = {}
          ruleSelectorNilUsesHelmValues = false
          ruleSelector = {}
        }
        service = {
          type = "ClusterIP"
        }
      }
      
      # Grafana configuration
      grafana = {
        adminPassword = "admin123"
        service = {
          type = "ClusterIP"
        }
        persistence = {
          enabled = true
          size    = "10Gi"
          storageClassName = "gp2"
        }
        # Default dashboards
        defaultDashboardsEnabled = true
        # Additional dashboards
        dashboardProviders = {
          "dashboardproviders.yaml" = {
            apiVersion = 1
            providers = [
              {
                name = "default"
                orgId = 1
                folder = ""
                type = "file"
                disableDeletion = false
                editable = true
                options = {
                  path = "/var/lib/grafana/dashboards/default"
                }
              }
            ]
          }
        }
        dashboards = {
          default = {
            # Kubernetes cluster monitoring dashboard
            kubernetes-cluster = {
              gnetId = 7249
              revision = 1
              datasource = "Prometheus"
            }
            # Node exporter dashboard
            node-exporter = {
              gnetId = 1860
              revision = 27
              datasource = "Prometheus"
            }
            # Application dashboard
            spring-boot = {
              gnetId = 12900
              revision = 1
              datasource = "Prometheus"
            }
          }
        }
      }
      
      # Alertmanager configuration
      alertmanager = {
        alertmanagerSpec = {
          storage = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "gp2"
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "5Gi"
                  }
                }
              }
            }
          }
        }
        service = {
          type = "ClusterIP"
        }
      }
      
      # Node exporter
      nodeExporter = {
        enabled = true
      }
      
      # Kube state metrics
      kubeStateMetrics = {
        enabled = true
      }
    })
  ]

  depends_on = [
    module.eks,
    kubernetes_namespace.monitoring
  ]
}

# =============================================================================
# APPLICATION SERVICE MONITOR
# =============================================================================
# ServiceMonitor for Spring Boot application metrics
# This will be applied after cluster deployment via post-deployment script

# Note: ServiceMonitor will be created by post-deployment script
# See: k8s/monitoring-resources.yaml

# =============================================================================
# GRAFANA INGRESS (Optional)
# =============================================================================
# Ingress for Grafana dashboard access
# This will be applied after cluster deployment via post-deployment script

# Note: Grafana ingress will be created by post-deployment script
# See: k8s/monitoring-resources.yaml

# =============================================================================
# CLOUDWATCH CONTAINER INSIGHTS
# =============================================================================
# AWS native monitoring for EKS

resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name = module.eks.cluster_name
  addon_name   = "amazon-cloudwatch-observability"
  
  depends_on = [module.eks]
}

# =============================================================================
# CLOUDWATCH ALARMS
# =============================================================================
# CloudWatch alarms for critical metrics

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EKS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors EKS CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = module.eks.cluster_name
  }
}

resource "aws_cloudwatch_metric_alarm" "high_memory" {
  alarm_name          = "${var.project_name}-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/EKS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors EKS memory utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = module.eks.cluster_name
  }
}

# SNS Topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"

  tags = {
    Name = "${var.project_name}-alerts"
  }
}

resource "aws_sns_topic_subscription" "email_alerts" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "admin@example.com"  # Change this to your email
}

# =============================================================================
# CLOUDWATCH DASHBOARD
# =============================================================================
# Application Performance Monitoring Dashboard

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix],
            [".", "TargetResponseTime", ".", "."],
            [".", "HTTPCode_Target_2XX_Count", ".", "."],
            [".", "HTTPCode_Target_4XX_Count", ".", "."],
            [".", "HTTPCode_Target_5XX_Count", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Application Load Balancer Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.main.id],
            [".", "DatabaseConnections", ".", "."],
            [".", "FreeableMemory", ".", "."],
            [".", "ReadLatency", ".", "."],
            [".", "WriteLatency", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "RDS Database Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/EKS", "cluster_failed_request_count", "ClusterName", module.eks.cluster_name],
            [".", "cluster_node_count", ".", "."],
            [".", "cluster_pod_count", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "EKS Cluster Metrics"
          period  = 300
        }
      }
    ]
  })
}
