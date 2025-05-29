#!/bin/bash

# Test script to generate traffic to the web application
# Usage: ./generate_traffic.sh [duration_in_seconds] [requests_per_second]

DURATION=${1:-300}  # Default: 5 minutes
RPS=${2:-5}         # Default: 5 requests per second
ENDPOINT="http://localhost:3000"
ENDPOINTS=("/" "/api" "/metrics")

echo "Generating traffic to $ENDPOINT for $DURATION seconds at $RPS requests per second"
echo "Press Ctrl+C to stop"

start_time=$(date +%s)
end_time=$((start_time + DURATION))

count=0
while [ $(date +%s) -lt $end_time ]; do
  for i in $(seq 1 $RPS); do
    # Select a random endpoint
    rand_index=$((RANDOM % ${#ENDPOINTS[@]}))
    selected_endpoint=${ENDPOINTS[$rand_index]}
    
    # Send request
    curl -s "${ENDPOINT}${selected_endpoint}" > /dev/null &
    
    count=$((count + 1))
    if [ $((count % 50)) -eq 0 ]; then
      echo "Sent $count requests..."
    fi
  done
  
  # Sleep for approximately 1 second
  sleep 1
done

echo "Traffic generation complete. Sent $count requests."
