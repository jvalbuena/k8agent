#!/bin/bash

# cleanup-k8s-metrics-forwarding.sh
# This script stops the port forwarding processes started by setup-k8s-metrics-for-docker.sh

# Define colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Cleaning up Kubernetes metrics port forwarding...${NC}"

if [ -f /tmp/k8s-metrics-pids.txt ]; then
    PIDS=$(cat /tmp/k8s-metrics-pids.txt)
    echo -e "Stopping processes with PIDs: ${RED}$PIDS${NC}"
    kill $PIDS 2>/dev/null
    rm /tmp/k8s-metrics-pids.txt
    echo -e "${GREEN}Port forwarding stopped.${NC}"
else
    echo -e "${RED}No PID file found at /tmp/k8s-metrics-pids.txt${NC}"
    echo -e "Attempting to find and kill kubectl port-forward and proxy processes..."
    
    PROXY_PIDS=$(ps aux | grep "kubectl proxy" | grep -v grep | awk '{print $2}')
    if [ ! -z "$PROXY_PIDS" ]; then
        echo -e "Killing kubectl proxy processes: ${RED}$PROXY_PIDS${NC}"
        kill $PROXY_PIDS 2>/dev/null
    fi
    
    FORWARD_PIDS=$(ps aux | grep "kubectl port-forward" | grep -v grep | awk '{print $2}')
    if [ ! -z "$FORWARD_PIDS" ]; then
        echo -e "Killing kubectl port-forward processes: ${RED}$FORWARD_PIDS${NC}"
        kill $FORWARD_PIDS 2>/dev/null
    fi
fi

echo -e "${GREEN}Cleanup complete.${NC}"
