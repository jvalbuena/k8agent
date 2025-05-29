#!/bin/bash

# K8Agent Load Testing Script
# Performs comprehensive load testing with detailed metrics collection and analysis
# Usage: ./load-test.sh [duration] [rps] [endpoint]

set -e

# Configuration
DURATION=${1:-120}  # Default: 2 minutes
RPS=${2:-5}         # Default: 5 requests per second
ENDPOINT=${3:-"http://localhost:3000"}
RESULTS_DIR="load-test-results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_FILE="$RESULTS_DIR/load_test_$TIMESTAMP.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test endpoints
ENDPOINTS=(
    "/"
    "/api"
    "/metrics"
    "/health"
)

echo -e "${BLUE}🚀 K8Agent Load Testing Suite${NC}"
echo "=================================="
echo "Duration: ${DURATION}s"
echo "Rate: ${RPS} RPS"
echo "Target: ${ENDPOINT}"
echo "Results: ${RESULTS_FILE}"
echo ""

# Create results directory
mkdir -p "$RESULTS_DIR"

# Function to check if endpoint is accessible
check_endpoint() {
    local url=$1
    echo -e "${YELLOW}🔍 Checking endpoint accessibility...${NC}"
    
    if curl -sf "$url/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Endpoint is accessible${NC}"
        return 0
    else
        echo -e "${RED}❌ Endpoint is not accessible. Please start the application first.${NC}"
        echo "   Run: ./start-monitoring.sh"
        exit 1
    fi
}

# Function to get baseline metrics
get_baseline_metrics() {
    echo -e "${YELLOW}📊 Collecting baseline metrics...${NC}"
    
    # Get current Prometheus metrics
    local baseline_cpu=$(curl -s "$ENDPOINT/metrics" | grep "process_cpu_user_seconds_total" | tail -1 | awk '{print $2}' || echo "0")
    local baseline_memory=$(curl -s "$ENDPOINT/metrics" | grep "process_resident_memory_bytes" | tail -1 | awk '{print $2}' || echo "0")
    local baseline_requests=$(curl -s "$ENDPOINT/metrics" | grep "http_requests_total" | tail -1 | awk '{print $2}' || echo "0")
    
    echo "{\"cpu\": $baseline_cpu, \"memory\": $baseline_memory, \"requests\": $baseline_requests}"
}

# Function to perform load test
run_load_test() {
    local duration=$1
    local rps=$2
    
    echo -e "${YELLOW}⚡ Starting load test...${NC}"
    echo "Target: $ENDPOINT"
    echo "Duration: ${duration}s"
    echo "Rate: ${rps} RPS"
    echo ""
    
    local start_time=$(date +%s)
    local end_time=$((start_time + duration))
    local total_requests=0
    local successful_requests=0
    local failed_requests=0
    local total_response_time=0
    local min_response_time=9999
    local max_response_time=0
    
    # Arrays to store response times for percentile calculation
    local response_times=()
    
    echo -e "${BLUE}Progress:${NC}"
    
    while [ $(date +%s) -lt $end_time ]; do
        for i in $(seq 1 $rps); do
            # Select random endpoint
            local rand_index=$((RANDOM % ${#ENDPOINTS[@]}))
            local selected_endpoint=${ENDPOINTS[$rand_index]}
            local full_url="${ENDPOINT}${selected_endpoint}"
            
            # Measure response time (using microseconds for better precision on macOS)
            local start_request=$(python3 -c "import time; print(int(time.time() * 1000))" 2>/dev/null || date +%s000)
            local http_code=$(curl -o /dev/null -s -w "%{http_code}" "$full_url" 2>/dev/null || echo "000")
            local end_request=$(python3 -c "import time; print(int(time.time() * 1000))" 2>/dev/null || date +%s000)
            local response_time=$((end_request - start_request))
            
            total_requests=$((total_requests + 1))
            
            if [ "$http_code" = "200" ]; then
                successful_requests=$((successful_requests + 1))
                total_response_time=$((total_response_time + response_time))
                response_times+=($response_time)
                
                # Update min/max response times
                if [ $response_time -lt $min_response_time ]; then
                    min_response_time=$response_time
                fi
                if [ $response_time -gt $max_response_time ]; then
                    max_response_time=$response_time
                fi
            else
                failed_requests=$((failed_requests + 1))
            fi
            
            # Progress indicator
            if [ $((total_requests % 100)) -eq 0 ]; then
                local elapsed=$(($(date +%s) - start_time))
                local remaining=$((duration - elapsed))
                printf "\r${BLUE}Requests: %d | Success: %d | Failed: %d | Remaining: %ds${NC}" \
                    $total_requests $successful_requests $failed_requests $remaining
            fi
        done
        
        # Sleep for approximately 1 second
        sleep 1
    done
    
    echo -e "\n${GREEN}✅ Load test completed!${NC}"
    echo ""
    
    # Calculate statistics
    local avg_response_time=0
    if [ $successful_requests -gt 0 ]; then
        avg_response_time=$((total_response_time / successful_requests))
    fi
    
    local success_rate=0
    if [ $total_requests -gt 0 ]; then
        success_rate=$(echo "scale=2; $successful_requests * 100 / $total_requests" | bc -l 2>/dev/null || echo "0")
    fi
    
    # Calculate percentiles (simplified)
    local p95_response_time=$max_response_time
    local p99_response_time=$max_response_time
    
    if [ ${#response_times[@]} -gt 0 ]; then
        # Sort response times
        IFS=$'\n' sorted_times=($(sort -n <<<"${response_times[*]}"))
        local count=${#sorted_times[@]}
        
        # Calculate 95th percentile
        local p95_index=$(echo "scale=0; $count * 0.95" | bc -l 2>/dev/null || echo "$count")
        p95_index=${p95_index%.*}  # Remove decimal part
        if [ $p95_index -ge $count ]; then
            p95_index=$((count - 1))
        fi
        p95_response_time=${sorted_times[$p95_index]}
        
        # Calculate 99th percentile
        local p99_index=$(echo "scale=0; $count * 0.99" | bc -l 2>/dev/null || echo "$count")
        p99_index=${p99_index%.*}  # Remove decimal part
        if [ $p99_index -ge $count ]; then
            p99_index=$((count - 1))
        fi
        p99_response_time=${sorted_times[$p99_index]}
    fi
    
    # Create results JSON
    cat > "$RESULTS_FILE" << EOF
{
  "test_config": {
    "duration": $duration,
    "target_rps": $rps,
    "endpoint": "$ENDPOINT",
    "timestamp": "$TIMESTAMP"
  },
  "results": {
    "total_requests": $total_requests,
    "successful_requests": $successful_requests,
    "failed_requests": $failed_requests,
    "success_rate": $success_rate,
    "avg_response_time_ms": $avg_response_time,
    "min_response_time_ms": $min_response_time,
    "max_response_time_ms": $max_response_time,
    "p95_response_time_ms": $p95_response_time,
    "p99_response_time_ms": $p99_response_time,
    "actual_rps": $(echo "scale=2; $total_requests / $duration" | bc -l 2>/dev/null || echo "0")
  }
}
EOF
    
    # Display results
    echo -e "${GREEN}📊 Test Results${NC}"
    echo "===================="
    echo "Total Requests: $total_requests"
    echo "Successful: $successful_requests"
    echo "Failed: $failed_requests"
    echo "Success Rate: ${success_rate}%"
    echo "Average Response Time: ${avg_response_time}ms"
    echo "Min Response Time: ${min_response_time}ms"
    echo "Max Response Time: ${max_response_time}ms"
    echo "95th Percentile: ${p95_response_time}ms"
    echo "99th Percentile: ${p99_response_time}ms"
    echo "Actual RPS: $(echo "scale=2; $total_requests / $duration" | bc -l 2>/dev/null || echo "N/A")"
    echo ""
    echo "Results saved to: $RESULTS_FILE"
}

# Function to get post-test metrics
get_post_test_metrics() {
    echo -e "${YELLOW}📈 Collecting post-test metrics...${NC}"
    
    # Wait a moment for metrics to stabilize
    sleep 2
    
    local post_cpu=$(curl -s "$ENDPOINT/metrics" | grep "process_cpu_user_seconds_total" | tail -1 | awk '{print $2}' || echo "0")
    local post_memory=$(curl -s "$ENDPOINT/metrics" | grep "process_resident_memory_bytes" | tail -1 | awk '{print $2}' || echo "0")
    local post_requests=$(curl -s "$ENDPOINT/metrics" | grep "http_requests_total" | tail -1 | awk '{print $2}' || echo "0")
    
    echo "{\"cpu\": $post_cpu, \"memory\": $post_memory, \"requests\": $post_requests}"
}

# Function to check application health after test
check_post_test_health() {
    echo -e "${YELLOW}🏥 Checking application health...${NC}"
    
    if curl -sf "$ENDPOINT/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Application is healthy after load test${NC}"
    else
        echo -e "${RED}⚠️  Application health check failed${NC}"
        echo "   The application may need attention"
    fi
}

# Function to generate summary report
generate_summary() {
    echo ""
    echo -e "${BLUE}📋 Load Test Summary${NC}"
    echo "======================"
    echo "Test completed at: $(date)"
    echo "Results file: $RESULTS_FILE"
    echo ""
    echo "Next steps:"
    echo "1. Review detailed results in the JSON file"
    echo "2. Check Grafana dashboards for visual metrics"
    echo "3. Monitor Prometheus for any alerts"
    echo ""
    echo "Grafana: http://localhost:3001"
    echo "Prometheus: http://localhost:9090"
}

# Main execution
main() {
    check_endpoint "$ENDPOINT"
    
    local baseline_metrics=$(get_baseline_metrics)
    
    run_load_test "$DURATION" "$RPS"
    
    local post_test_metrics=$(get_post_test_metrics)
    
    check_post_test_health
    
    generate_summary
    
    echo -e "${GREEN}🎉 Load testing completed successfully!${NC}"
}

# Run main function
main "$@"
