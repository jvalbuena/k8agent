#!/bin/bash

# monitor-control.sh - Comprehensive script to manage the monitoring infrastructure
# Usage: ./monitor-control.sh [command]
#
# Commands:
#   start         - Start basic monitoring (web-app metrics only)
#   start-k8s     - Start monitoring with Kubernetes metrics
#   stop          - Stop all monitoring containers
#   restart       - Restart all monitoring containers
#   status        - Check status of monitoring components
#   test          - Generate test traffic to the web application
#   logs          - Show logs from monitoring components

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

WORKSPACE_DIR="/Users/julian/Documents/k8agent/web-app"

# Print usage information
usage() {
  echo -e "${BLUE}Monitoring Control Script${NC}"
  echo -e "Usage: $0 [command]"
  echo ""
  echo -e "Commands:"
  echo -e "  ${GREEN}start${NC}         Start basic monitoring (web-app metrics only)"
  echo -e "  ${GREEN}start-k8s${NC}     Start monitoring with Kubernetes metrics"
  echo -e "  ${GREEN}stop${NC}          Stop all monitoring containers"
  echo -e "  ${GREEN}restart${NC}       Restart all monitoring containers"
  echo -e "  ${GREEN}status${NC}        Check status of monitoring components"
  echo -e "  ${GREEN}test${NC} [duration] [rps] Generate test traffic (default: 60s at 10 rps)"
  echo -e "  ${GREEN}logs${NC} [component]   Show logs (prometheus, grafana, web-app, or all)"
  echo ""
}

# Check container status
check_status() {
  local name=$1
  local status=$(docker ps -a --format "{{.Names}}:{{.Status}}" | grep "^$name:" 2>/dev/null)
  
  if [ -z "$status" ]; then
    echo -e "$name: ${RED}Not found${NC}"
    return 1
  fi
  
  if echo "$status" | grep -q "Up "; then
    echo -e "$name: ${GREEN}Running${NC}"
    return 0
  else
    echo -e "$name: ${YELLOW}Stopped${NC}"
    return 2
  fi
}

# Check if all required containers are running
check_all_statuses() {
  echo -e "${BLUE}Checking monitoring components status:${NC}"
  
  local all_running=true
  
  for container in web-app prometheus grafana; do
    if ! check_status $container; then
      all_running=false
    fi
  done
  
  # Check port forwarding for Kubernetes metrics
  if [ -f /tmp/k8s-metrics-pids.txt ]; then
    PIDS=$(cat /tmp/k8s-metrics-pids.txt)
    for PID in $PIDS; do
      if ps -p $PID > /dev/null; then
        echo -e "Kubernetes metrics forwarding: ${GREEN}Active${NC} (PID: $PID)"
      else
        echo -e "Kubernetes metrics forwarding: ${YELLOW}Inactive${NC} (PID $PID not running)"
      fi
    done
  else
    echo -e "Kubernetes metrics forwarding: ${YELLOW}Inactive${NC}"
  fi
  
  # Check access to monitoring interfaces
  echo ""
  echo -e "${BLUE}Access URLs:${NC}"
  echo -e "Web Application: http://localhost:3000"
  echo -e "Prometheus: http://localhost:9090"
  echo -e "Grafana: http://localhost:3001 (admin/admin)"
  
  if $all_running; then
    return 0
  else
    return 1
  fi
}

# Start basic monitoring
start_basic() {
  echo -e "${BLUE}Starting basic monitoring...${NC}"
  $WORKSPACE_DIR/start-monitoring.sh
}

# Start monitoring with Kubernetes metrics
start_k8s() {
  echo -e "${BLUE}Starting monitoring with Kubernetes metrics...${NC}"
  $WORKSPACE_DIR/start-k8s-monitoring.sh
}

# Stop all monitoring containers
stop_monitoring() {
  echo -e "${BLUE}Stopping monitoring containers...${NC}"
  
  # Stop port forwarding first
  if [ -f $WORKSPACE_DIR/cleanup-k8s-metrics-forwarding.sh ]; then
    $WORKSPACE_DIR/cleanup-k8s-metrics-forwarding.sh
  fi
  
  # Stop containers
  for container in prometheus grafana web-app; do
    if docker ps -q -f name="$container" | grep -q .; then
      echo -e "Stopping $container..."
      docker stop $container > /dev/null
    else
      echo -e "$container is not running."
    fi
  done
  
  echo -e "${GREEN}All monitoring containers stopped.${NC}"
}

# Restart monitoring
restart_monitoring() {
  echo -e "${BLUE}Restarting monitoring...${NC}"
  stop_monitoring
  sleep 2
  start_basic
}

# Generate test traffic
generate_traffic() {
  local duration=$1
  local rps=$2
  
  if [ -z "$duration" ]; then
    duration=60
  fi
  
  if [ -z "$rps" ]; then
    rps=10
  fi
  
  echo -e "${BLUE}Generating test traffic for ${duration}s at ${rps} requests per second...${NC}"
  $WORKSPACE_DIR/generate_traffic.sh $duration $rps
}

# Show logs
show_logs() {
  local component=$1
  
  if [ -z "$component" ] || [ "$component" = "all" ]; then
    echo -e "${BLUE}Showing logs for all components (last 20 lines each)...${NC}"
    for c in web-app prometheus grafana; do
      echo -e "${YELLOW}=== $c logs ===${NC}"
      docker logs --tail 20 $c 2>/dev/null || echo -e "${RED}No logs found for $c${NC}"
      echo ""
    done
  else
    echo -e "${BLUE}Showing logs for $component...${NC}"
    docker logs --tail 50 $component 2>/dev/null || echo -e "${RED}No logs found for $component${NC}"
  fi
}

# Main execution
if [ $# -eq 0 ]; then
  usage
  exit 0
fi

command=$1
shift

case "$command" in
  start)
    start_basic
    ;;
  start-k8s)
    start_k8s
    ;;
  stop)
    stop_monitoring
    ;;
  restart)
    restart_monitoring
    ;;
  status)
    check_all_statuses
    ;;
  test)
    generate_traffic "$@"
    ;;
  logs)
    show_logs "$1"
    ;;
  *)
    echo -e "${RED}Unknown command: $command${NC}"
    usage
    exit 1
    ;;
esac
