#!/bin/bash

# Start-monitoring.sh - Script to start the complete monitoring setup
# Usage: ./start-monitoring.sh [--k8s-metrics]

# Default values
USE_K8S_METRICS=false

# Process command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --k8s-metrics)
      USE_K8S_METRICS=true
      shift # past argument
      ;;
    *)
      # Unknown option
      echo "Unknown option: $1"
      echo "Usage: $0 [--k8s-metrics]"
      exit 1
      ;;
  esac
done

# Variables
WORKSPACE_DIR="/Users/julian/Documents/k8agent/web-app"
PROMETHEUS_CONFIG="$WORKSPACE_DIR/k8s/prometheus.yml"
PROMETHEUS_CONFIG_DOCKER="$WORKSPACE_DIR/k8s/prometheus-docker.yml"
PROMETHEUS_RULES="$WORKSPACE_DIR/k8s/prometheus-rules.yml"
GRAFANA_DATASOURCE="$WORKSPACE_DIR/k8s/grafana-datasource.yml"
GRAFANA_DASHBOARD_PROVIDER="$WORKSPACE_DIR/k8s/grafana-dashboard-provider.yml"
GRAFANA_DASHBOARD="$WORKSPACE_DIR/k8s/web-app-dashboard.json"
K8S_DASHBOARD="$WORKSPACE_DIR/k8s/kubernetes-metrics-dashboard.json"

# Function to check if container exists and is running
container_running() {
  local name="$1"
  if docker ps -q -f name="^$name$" | grep -q .; then
    echo "$name is already running"
    return 0
  else
    return 1
  fi
}

echo "Starting monitoring setup..."

# Create monitoring network if it doesn't exist
if ! docker network inspect monitoring &>/dev/null; then
  echo "Creating monitoring network..."
  docker network create monitoring
else
  echo "Monitoring network already exists"
fi

# Start web-app if not already running
if ! container_running "web-app"; then
  echo "Starting web-app container..."
  docker run -d --name web-app --network monitoring -p 3000:3000 web-app:latest
  
  # Connect to monitoring network if needed
  if ! docker network inspect monitoring | grep -q "web-app"; then
    echo "Connecting web-app to monitoring network..."
    docker network connect monitoring web-app
  fi
fi

# Start Prometheus if not already running
if ! container_running "prometheus"; then
  echo "Starting Prometheus container..."
  
  # Choose which config to use based on k8s metrics setting
  if [ "$USE_K8S_METRICS" = true ]; then
    echo "Using Kubernetes metrics configuration..."
    CONFIG_TO_USE="$PROMETHEUS_CONFIG_DOCKER"
    EXTRA_ARGS="--add-host=host.docker.internal:host-gateway"
    
    # Check if port-forwarding is set up
    if ! curl -s http://localhost:8080/metrics >/dev/null 2>&1; then
      echo "Warning: kube-state-metrics port forwarding is not active."
      echo "Run './setup-k8s-metrics-for-docker.sh' in a separate terminal first."
      read -p "Continue anyway? (y/n): " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborting."
        exit 1
      fi
    fi
  else
    echo "Using standard configuration..."
    CONFIG_TO_USE="$PROMETHEUS_CONFIG"
    EXTRA_ARGS=""
  fi
  
  docker run -d --name prometheus --network monitoring -p 9090:9090 \
    -v "$CONFIG_TO_USE:/etc/prometheus/prometheus.yml" \
    -v "$PROMETHEUS_RULES:/etc/prometheus/rules.yml" \
    $EXTRA_ARGS \
    prom/prometheus:latest
fi

# Start Grafana if not already running
if ! container_running "grafana"; then
  echo "Starting Grafana container..."
  
  # Create dashboard mounts
  DASHBOARD_MOUNTS="-v \"$GRAFANA_DASHBOARD:/var/lib/grafana/dashboards/web-app-dashboard.json\""
  
  # Add K8s dashboard if using K8s metrics
  if [ "$USE_K8S_METRICS" = true ]; then
    DASHBOARD_MOUNTS="$DASHBOARD_MOUNTS -v \"$K8S_DASHBOARD:/var/lib/grafana/dashboards/kubernetes-metrics-dashboard.json\""
  fi
  
  # Use eval to handle the variable with quotes properly
  eval docker run -d --name grafana --network monitoring -p 3001:3000 \
    -v "$GRAFANA_DATASOURCE:/etc/grafana/provisioning/datasources/datasource.yml" \
    -v "$GRAFANA_DASHBOARD_PROVIDER:/etc/grafana/provisioning/dashboards/provider.yml" \
    $DASHBOARD_MOUNTS \
    grafana/grafana:latest
fi

echo "Monitoring setup complete!"
echo "Web App: http://localhost:3000"
echo "Web App Metrics: http://localhost:3000/metrics"
echo "Prometheus: http://localhost:9090"
echo "Grafana: http://localhost:3001 (admin/admin)"

if [ "$USE_K8S_METRICS" = true ]; then
  echo ""
  echo "Kubernetes metrics collection is enabled."
  echo "Make sure to run './setup-k8s-metrics-for-docker.sh' in a separate terminal"
  echo "if you haven't done so already."
  echo ""
  echo "In Grafana, you should see an additional 'Kubernetes Metrics' dashboard."
fi
