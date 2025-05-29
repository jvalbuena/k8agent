#!/bin/bash

# start-k8s-monitoring.sh - Complete script to start monitoring with Kubernetes metrics
# This script:
# 1. Sets up port forwarding for Kubernetes metrics
# 2. Starts the monitoring stack with Kubernetes metrics enabled
# 3. Cleans up everything when terminated

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

WORKSPACE_DIR="/Users/julian/Documents/k8agent/web-app"

# Function to clean up before exit
cleanup() {
  echo -e "\n${YELLOW}Cleaning up...${NC}"
  
  # Run the cleanup script for port-forwarding
  $WORKSPACE_DIR/cleanup-k8s-metrics-forwarding.sh
  
  echo -e "${GREEN}Cleanup complete.${NC}"
  echo -e "${YELLOW}Note: The monitoring containers (Prometheus, Grafana, web-app) are still running.${NC}"
  echo -e "${YELLOW}To stop them, run:${NC}"
  echo -e "docker stop prometheus grafana web-app"
}

# Set trap for clean exit
trap cleanup EXIT INT TERM

echo -e "${GREEN}Setting up Kubernetes metrics monitoring${NC}"

# 1. Start port forwarding
echo -e "${YELLOW}Setting up port forwarding for Kubernetes metrics...${NC}"

# Start kubectl proxy in the background to access the Kubernetes API
echo -e "Starting kubectl proxy on port 8001..."
kubectl proxy --port=8001 &
PROXY_PID=$!
echo "Proxy running with PID: $PROXY_PID"

# Port forward to kube-state-metrics
echo -e "Setting up port-forward to kube-state-metrics on port 8080..."
kubectl port-forward -n monitoring svc/prometheus-kube-state-metrics 8080:8080 &
KSM_PID=$!
echo "Port forward running with PID: $KSM_PID"

# Save PIDs for cleanup
echo "$PROXY_PID $KSM_PID" > /tmp/k8s-metrics-pids.txt

# Wait for port-forwarding to be established
echo -e "${YELLOW}Waiting for port-forwards to be established...${NC}"
sleep 5

# Check if the forwards are working
if curl -s http://localhost:8001/api/v1/nodes/docker-desktop/proxy/metrics/cadvisor | head -n 5 > /dev/null; then
  echo -e "${GREEN}cAdvisor metrics accessible ✓${NC}"
else
  echo -e "${RED}Failed to access cAdvisor metrics!${NC}"
  echo -e "Will continue anyway, but Kubernetes node metrics might not be available."
fi

if curl -s http://localhost:8080/metrics | head -n 5 > /dev/null; then
  echo -e "${GREEN}kube-state-metrics accessible ✓${NC}"
else
  echo -e "${RED}Failed to access kube-state-metrics!${NC}"
  echo -e "Will continue anyway, but Kubernetes state metrics might not be available."
fi

# 2. Start the monitoring stack with k8s metrics enabled
echo -e "\n${YELLOW}Starting the monitoring stack with Kubernetes metrics enabled...${NC}"

# Check if containers are already running and stop them
for container in prometheus grafana; do
  if docker ps -q -f name="$container" | grep -q .; then
    echo -e "Stopping existing $container container..."
    docker stop $container > /dev/null
    docker rm $container > /dev/null
  fi
done

# Start the monitoring stack with k8s metrics enabled
$WORKSPACE_DIR/start-monitoring.sh --k8s-metrics

echo -e "\n${GREEN}Kubernetes metrics monitoring is now active!${NC}"
echo -e "${YELLOW}Keep this terminal open while collecting metrics.${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop port forwarding.${NC}"
echo -e "${GREEN}Web App: http://localhost:3000${NC}"
echo -e "${GREEN}Prometheus: http://localhost:9090${NC}"
echo -e "${GREEN}Grafana: http://localhost:3001 (admin/admin)${NC}"
echo -e "${GREEN}Kubernetes Metrics Dashboard: http://localhost:3001/d/kubernetes-metrics/kubernetes-metrics${NC}"

# Keep running until terminated
wait $PROXY_PID $KSM_PID
