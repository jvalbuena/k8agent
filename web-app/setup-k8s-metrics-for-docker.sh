#!/bin/bash

# setup-k8s-metrics-for-docker.sh
# This script sets up port forwarding from Kubernetes metrics endpoints to localhost,
# making them accessible to Docker containers using host.docker.internal

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting up Kubernetes metrics for Prometheus in Docker${NC}"

# Start kubectl proxy in the background to access the Kubernetes API
echo -e "${YELLOW}Starting kubectl proxy on port 8001...${NC}"
kubectl proxy --port=8001 &
PROXY_PID=$!
echo "Proxy running with PID: $PROXY_PID"

# Port forward to kube-state-metrics
echo -e "${YELLOW}Setting up port-forward to kube-state-metrics on port 8080...${NC}"
kubectl port-forward -n monitoring svc/prometheus-kube-state-metrics 8080:8080 &
KSM_PID=$!
echo "Port forward running with PID: $KSM_PID"

echo -e "${GREEN}Setup complete! Kubernetes metrics should now be accessible to Prometheus.${NC}"
echo -e "Run the following to stop the forwarding:"
echo -e "${RED}kill $PROXY_PID $KSM_PID${NC}"

# Write PIDs to a file for easy cleanup later
echo "$PROXY_PID $KSM_PID" > /tmp/k8s-metrics-pids.txt
echo -e "${YELLOW}PIDs saved to /tmp/k8s-metrics-pids.txt${NC}"

echo -e "${GREEN}Waiting for port-forwards to be established...${NC}"
sleep 5

# Check if the forwards are working
if curl -s http://localhost:8001/api/v1/nodes/docker-desktop/proxy/metrics/cadvisor | head -n 5 > /dev/null; then
  echo -e "${GREEN}cAdvisor metrics accessible ✓${NC}"
else
  echo -e "${RED}Failed to access cAdvisor metrics!${NC}"
fi

if curl -s http://localhost:8080/metrics | head -n 5 > /dev/null; then
  echo -e "${GREEN}kube-state-metrics accessible ✓${NC}"
else
  echo -e "${RED}Failed to access kube-state-metrics!${NC}"
fi

echo -e "${GREEN}Use the following command to update your Prometheus container:${NC}"
echo -e "docker stop prometheus && docker rm prometheus && \\"
echo -e "docker run -d --name prometheus --network monitoring -p 9090:9090 \\"
echo -e "  -v \"/Users/julian/Documents/k8agent/web-app/k8s/prometheus-docker.yml:/etc/prometheus/prometheus.yml\" \\"
echo -e "  -v \"/Users/julian/Documents/k8agent/web-app/k8s/prometheus-rules.yml:/etc/prometheus/rules.yml\" \\"
echo -e "  --add-host=host.docker.internal:host-gateway \\"
echo -e "  prom/prometheus:latest"

echo -e "\n${YELLOW}Keep this terminal open while collecting metrics.${NC}"
wait
