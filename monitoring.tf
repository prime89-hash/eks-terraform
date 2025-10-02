# Prometheus and Grafana for monitoring
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  version    = "51.2.0"

  create_namespace = true

  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          retention = "7d"
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "gp2"
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "10Gi"
                  }
                }
              }
            }
          }
        }
      }
      grafana = {
        adminPassword = "admin123"
        service = {
          type = "LoadBalancer"
        }
        persistence = {
          enabled = true
          size    = "5Gi"
        }
      }
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
      }
    })
  ]

  depends_on = [module.eks]
}

# CloudWatch Container Insights
resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name = module.eks.cluster_name
  addon_name   = "amazon-cloudwatch-observability"
  
  depends_on = [module.eks]
}

# X-Ray for distributed tracing
resource "helm_release" "aws_xray" {
  name       = "aws-xray"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-for-fluent-bit"
  namespace  = "amazon-cloudwatch"
  version    = "0.1.25"

  create_namespace = true

  set {
    name  = "cloudWatchLogs.enabled"
    value = "true"
  }

  set {
    name  = "cloudWatchLogs.region"
    value = var.aws_region
  }

  set {
    name  = "cloudWatchLogs.logGroupName"
    value = "/aws/containerinsights/${module.eks.cluster_name}/application"
  }

  depends_on = [module.eks]
}

# Service Monitor for application metrics
resource "kubernetes_manifest" "webapp_service_monitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "webapp-service-monitor"
      namespace = var.app_namespace
      labels = {
        app = "webapp-3tier"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app = "webapp-3tier"
        }
      }
      endpoints = [
        {
          port = "http"
          path = "/actuator/prometheus"
        }
      ]
    }
  }

  depends_on = [
    helm_release.prometheus,
    kubernetes_namespace.app
  ]
}

# CloudWatch Alarms
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
      }
    ]
  })
}
