# Web Application Monitoring Setup

This document outlines the setup of the monitoring infrastructure for our web application using Docker, Prometheus, and Grafana, including optional Kubernetes metrics collection.

## Components

1. **Web Application**
   - A Node.js Express application with Prometheus metrics integration
   - Exposes metrics at `/metrics` endpoint
   - Custom metrics: `http_requests_total` and `http_request_duration_seconds`
   - Accessible at http://localhost:3000

2. **Prometheus**
   - Time series database for storing and querying metrics
   - Scrapes metrics from the web application every 15 seconds
   - Configured with alerting rules for high request rate and response time
   - Can be configured to scrape Kubernetes metrics
   - Accessible at http://localhost:9090

3. **Grafana**
   - Visualization platform for metrics
   - Pre-configured dashboards for web application and Kubernetes metrics

4. **Kubernetes Metrics Collection** (Optional)
   - Uses kube-state-metrics to expose cluster-level statistics
   - Uses metrics-server and cAdvisor to collect container and node metrics
   - Provides CPU, memory, and resource utilization metrics for pods and containers
   - Connected to Prometheus as a data source
   - Accessible at http://localhost:3001
   - Default login: admin/admin

## Directory Structure

```
web-app/
├── Dockerfile                        # Docker configuration for the web application
├── generate_traffic.sh               # Script to generate test traffic
├── start-monitoring.sh               # Script to start the basic monitoring setup
├── setup-k8s-metrics-for-docker.sh   # Script to set up Kubernetes metrics collection
├── cleanup-k8s-metrics-forwarding.sh # Script to clean up Kubernetes metrics port-forwarding
├── start-k8s-monitoring.sh           # All-in-one script to start monitoring with Kubernetes metrics
├── monitor-control.sh                # Comprehensive script to manage the monitoring infrastructure
├── MONITORING.md                     # This documentation file
├── package.json                      # Node.js dependencies
├── k8s/
│   ├── app.yaml                      # Original Kubernetes manifests for app deployment
│   ├── grafana-dashboard-provider.yml # Grafana dashboard provider configuration
│   ├── grafana-datasource.yml        # Grafana Prometheus datasource configuration
│   ├── grafana-values.yaml           # Original Grafana Helm chart values
│   ├── kubernetes-metrics-dashboard.json # Kubernetes metrics Grafana dashboard
│   ├── prometheus-docker.yml         # Prometheus configuration for Docker with Kubernetes metrics
│   ├── prometheus-rules.yml          # Prometheus alerting rules
│   ├── prometheus-values.yaml        # Original Prometheus Helm chart values
│   ├── prometheus.yml                # Standard Prometheus configuration
│   ├── web-app-dashboard.json        # Web application Grafana dashboard
│   ├── web-app-deployment.yaml       # Kubernetes deployment manifest
│   └── web-app-service.yaml          # Kubernetes service manifest
└── src/
    └── app.js                        # Web application source code
```

## Docker Setup

The monitoring setup uses Docker containers and a dedicated Docker network:

```bash
# Create monitoring network
docker network create monitoring

# Run the web application
docker run -d --name web-app --network monitoring -p 3000:3000 web-app:latest

# Run Prometheus
docker run -d --name prometheus --network monitoring -p 9090:9090 \
  -v /path/to/prometheus.yml:/etc/prometheus/prometheus.yml \
  -v /path/to/prometheus-rules.yml:/etc/prometheus/rules.yml \
  prom/prometheus:latest

# Run Grafana
docker run -d --name grafana --network monitoring -p 3001:3000 \
  -v /path/to/grafana-datasource.yml:/etc/grafana/provisioning/datasources/datasource.yml \
  -v /path/to/grafana-dashboard-provider.yml:/etc/grafana/provisioning/dashboards/provider.yml \
  -v /path/to/web-app-dashboard.json:/var/lib/grafana/dashboards/web-app-dashboard.json \
  grafana/grafana:latest
```

## Testing

Use the generate_traffic.sh script to test the monitoring setup:

```bash
./generate_traffic.sh [duration_in_seconds] [requests_per_second]
```

For example:
```bash
./generate_traffic.sh 60 10  # Generate traffic for 60 seconds at 10 requests per second
```

## Kubernetes Metrics Collection

The monitoring setup includes support for collecting and visualizing Kubernetes metrics:

### Setup Options

1. **Basic Monitoring** (Web App Only):
   ```bash
   ./start-monitoring.sh
   ```

2. **Kubernetes Metrics Monitoring**:
   ```bash
   # Method 1: Two-step process
   ./setup-k8s-metrics-for-docker.sh  # Run this in a separate terminal
   ./start-monitoring.sh --k8s-metrics
   
   # Method 2: All-in-one script
   ./start-k8s-monitoring.sh  # Handles all setup steps
   ```

3. **Cleanup Kubernetes Port-forwarding**:
   ```bash
   ./cleanup-k8s-metrics-forwarding.sh
   ```

### All-in-One Monitoring Control Script

For convenience, an all-in-one monitoring control script is available that provides a unified interface to manage the entire monitoring stack:

```bash
# Usage
./monitor-control.sh [command]

# Available commands:
./monitor-control.sh start       # Start basic monitoring
./monitor-control.sh start-k8s   # Start monitoring with Kubernetes metrics
./monitor-control.sh stop        # Stop all monitoring containers
./monitor-control.sh restart     # Restart all monitoring containers
./monitor-control.sh status      # Check status of monitoring components
./monitor-control.sh test 60 10  # Generate test traffic (60s at 10 requests/sec)
./monitor-control.sh logs        # Show logs from all monitoring components
./monitor-control.sh logs grafana # Show logs from a specific component
```

### Available Kubernetes Metrics

The Kubernetes metrics collection includes:

- **Container Metrics**: CPU usage, memory usage, network traffic
- **Pod Metrics**: Health status, restart counts, resource utilization
- **Node Metrics**: CPU, memory, disk usage, and capacity
- **Workload Metrics**: Deployment status, replica counts, etc.

### Kubernetes Dashboard

A pre-configured Kubernetes metrics dashboard is available in Grafana that shows:
- Container CPU and memory usage
- Resource requests vs capacity
- Running pods by namespace
- Top pods by resource consumption

## Alerting

Prometheus is configured with the following alerting rules:

1. **HighRequestRate**: Triggers when the request rate exceeds 5 requests per second for 1 minute
2. **HighResponseTime**: Triggers when the 95th percentile response time exceeds 0.1 seconds for 1 minute

To view alerts, go to the Prometheus UI at http://localhost:9090/alerts

## Future Improvements

1. Add more comprehensive alerting rules
2. Setup alert manager for notification delivery (email, Slack, etc.)
3. Add more detailed dashboards in Grafana
4. Implement log aggregation with tools like Loki
5. Implement distributed tracing with tools like Jaeger
