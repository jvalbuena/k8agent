# K8Agent - Kubernetes Monitoring and Load Testing

A comprehensive Kubernetes monitoring setup with Prometheus, Grafana, and automated load testing capabilities.

## Features

- **Web Application**: Node.js Express app with Prometheus metrics
- **Monitoring Stack**: Prometheus for metrics collection, Grafana for visualization
- **Load Testing**: Automated load testing with detailed performance metrics
- **Kubernetes Integration**: Complete K8s manifests for deployment
- **Health Monitoring**: Automated health checks and alerting

## Prerequisites

Before running this project, ensure you have the following dependencies installed:

- **Docker**: Container runtime
- **Node.js**: Version 18 or higher
- **kubectl**: Kubernetes command-line tool
- **curl**: For API testing
- **jq**: JSON processor for parsing responses
- **bash**: Shell environment (macOS/Linux)

## Initial Setup

1. **Check Dependencies**:
   ```bash
   ./check-dependencies.sh
   ```

2. **Install Node.js Dependencies**:
   ```bash
   cd web-app
   npm install
   ```

3. **Start Monitoring Stack**:
   ```bash
   cd web-app
   ./start-monitoring.sh
   ```

4. **Verify Setup**:
   ```bash
   ./health-check.sh
   ```

## Usage

### Starting the Application

1. **Start all services**:
   ```bash
   cd web-app
   ./start-monitoring.sh
   ```

2. **Access the services**:
   - Web Application: http://localhost:3000
   - Prometheus: http://localhost:9090
   - Grafana: http://localhost:3001 (admin/admin)

### Running Load Tests

```bash
cd web-app
./load-test.sh
```

### Monitoring

- View metrics in Grafana dashboards
- Check Prometheus targets at http://localhost:9090/targets
- Application metrics available at http://localhost:3000/metrics

## Project Structure

```
k8agent/
├── web-app/
│   ├── src/
│   │   └── app.js              # Main Node.js application
│   ├── k8s/
│   │   ├── app-deployment.yaml # Kubernetes deployment
│   │   ├── prometheus.yml      # Prometheus configuration
│   │   └── grafana/           # Grafana dashboards
│   ├── package.json           # Node.js dependencies
│   ├── start-monitoring.sh    # Start monitoring stack
│   ├── stop-monitoring.sh     # Stop monitoring stack
│   ├── load-test.sh          # Load testing script
│   └── health-check.sh       # Health check script
├── check-dependencies.sh     # Dependency checker
└── README.md                 # This file
```

## Troubleshooting

### Common Issues

1. **Port conflicts**: Ensure ports 3000, 9090, and 3001 are available
2. **Docker not running**: Start Docker Desktop or Docker daemon
3. **Node.js version**: Requires Node.js 18 or higher
4. **Permission issues**: Ensure scripts are executable (`chmod +x *.sh`)

### Health Checks

- Check if all containers are running: `docker ps`
- Test application endpoint: `curl http://localhost:3000/health`
- Verify Prometheus targets: Visit http://localhost:9090/targets

### Container Issues

If containers fail to start:
1. Check Docker logs: `docker logs <container_name>`
2. Verify port availability: `lsof -i :3000,9090,3001`
3. Restart monitoring stack: `./stop-monitoring.sh && ./start-monitoring.sh`

## Development

### Adding New Metrics

1. Add metric collection in `src/app.js`
2. Update Prometheus configuration if needed
3. Create or update Grafana dashboards

### Kubernetes Deployment

Deploy to Kubernetes cluster:
```bash
kubectl apply -f k8s/
```

## Security Notes

⚠️ **Development Environment Only**
- Default Grafana credentials (`admin/admin`) are for local development only
- For production deployments, change default passwords and use environment variables
- All exposed credentials are development defaults, not production secrets

## Performance

- **Average Response Time**: ~2.5ms
- **Throughput**: Tested up to 5 RPS sustained
- **Memory Usage**: ~50MB base footprint
- **CPU Usage**: <1% under normal load
