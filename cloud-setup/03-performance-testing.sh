#!/bin/bash

# Performance Testing Suite for Sentiment Analyzer Private Cloud
# Phase 5A: Load Testing and Performance Metrics Collection

echo "=== Performance Testing Suite ==="

# 1. Install load testing tools
echo "Installing load testing tools..."
sudo apt install -y apache2-utils wrk

# Install K6 for advanced load testing
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt update
sudo apt install -y k6

# 2. Create test data
cat > test_data.json << 'EOF'
[
  {"text": "I love this amazing product! It's fantastic!"},
  {"text": "This is terrible, I hate it completely."},
  {"text": "The weather is okay today, nothing special."},
  {"text": "Absolutely wonderful experience, highly recommend!"},
  {"text": "Worst service ever, completely disappointed."},
  {"text": "It's fine, meets basic expectations."},
  {"text": "Outstanding quality and excellent customer service!"},
  {"text": "Poor quality, waste of money and time."},
  {"text": "Average product, could be better or worse."},
  {"text": "Incredible innovation, this will change everything!"}
]
EOF

# 3. Basic load test with Apache Bench
echo "=== Running Basic Load Test with Apache Bench ==="
ab -n 1000 -c 10 -T application/json -p test_payload.json http://api.sentiment-analyzer.local/analyze

# 4. Advanced load test with wrk
echo "=== Running Advanced Load Test with wrk ==="
wrk -t12 -c400 -d30s --script=load_test.lua http://api.sentiment-analyzer.local/analyze

# 5. Stress test with K6
echo "=== Running Stress Test with K6 ==="
k6 run stress_test.js

echo "=== Performance Testing Complete ==="
echo "Check Grafana dashboard for detailed metrics"
echo "Access: kubectl port-forward -n monitoring svc/grafana-service 3000:3000"
