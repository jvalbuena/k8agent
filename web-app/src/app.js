const express = require('express');
const promClient = require('prom-client');

// Create a Registry to register the metrics
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

// Create custom metrics
const httpRequestCounter = new promClient.Counter({
    name: 'http_requests_total',
    help: 'Total number of HTTP requests',
    labelNames: ['method', 'path', 'status']
});

const httpRequestDuration = new promClient.Histogram({
    name: 'http_request_duration_seconds',
    help: 'Duration of HTTP requests in seconds',
    labelNames: ['method', 'path', 'status'],
    buckets: [0.01, 0.05, 0.1, 0.5, 1, 2, 5]
});

// Register the custom metrics
register.registerMetric(httpRequestCounter);
register.registerMetric(httpRequestDuration);

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware to measure request duration
app.use((req, res, next) => {
    const start = Date.now();
    
    res.on('finish', () => {
        const duration = (Date.now() - start) / 1000;
        httpRequestCounter.inc({
            method: req.method,
            path: req.path,
            status: res.statusCode
        });
        
        httpRequestDuration.observe(
            {
                method: req.method,
                path: req.path,
                status: res.statusCode
            },
            duration
        );
    });
    
    next();
});

// Root endpoint
app.get('/', (req, res) => {
    res.send('Hello from Kubernetes Monitoring Demo!');
});

// Health check endpoint
app.get('/health', (req, res) => {
    res.status(200).send('OK');
});

// Metrics endpoint for Prometheus to scrape
app.get('/metrics', async (req, res) => {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
});

// Simulated endpoints with different response times
app.get('/fast', (req, res) => {
    res.send('This is a fast response!');
});

app.get('/slow', (req, res) => {
    setTimeout(() => {
        res.send('This was a slow response...');
    }, 1000);
});

app.get('/random-error', (req, res) => {
    if (Math.random() > 0.7) {
        res.status(500).send('Random error occurred!');
    } else {
        res.send('No error this time!');
    }
});

app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
    console.log(`Metrics available at http://localhost:${PORT}/metrics`);
});
