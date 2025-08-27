import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Custom metrics
export let errorRate = new Rate('errors');

// Test configuration for different scenarios
export let options = {
  stages: [
    // Ramp-up phase
    { duration: '2m', target: 10 },   // Ramp up to 10 users over 2 minutes
    { duration: '5m', target: 10 },   // Stay at 10 users for 5 minutes
    { duration: '2m', target: 50 },   // Ramp up to 50 users over 2 minutes
    { duration: '5m', target: 50 },   // Stay at 50 users for 5 minutes
    { duration: '2m', target: 100 },  // Ramp up to 100 users over 2 minutes
    { duration: '5m', target: 100 },  // Stay at 100 users for 5 minutes
    { duration: '10m', target: 200 }, // Stress test with 200 users for 10 minutes
    { duration: '5m', target: 0 },    // Ramp down to 0 users
  ],
  thresholds: {
    // Performance objectives for cloud AI service
    http_req_duration: ['p(90)<2000', 'p(95)<3000', 'p(99)<5000'], // Response time objectives
    http_req_failed: ['rate<0.1'],    // Error rate should be below 10%
    errors: ['rate<0.1'],             // Custom error rate
  },
};

// Test data for sentiment analysis
const testTexts = [
  "I absolutely love this product! It's amazing!",
  "This is the worst experience I've ever had.",
  "The service was okay, nothing special.",
  "Fantastic quality and great customer support!",
  "Terrible product, complete waste of money.",
  "It's fine, meets my basic requirements.",
  "Outstanding innovation, highly recommended!",
  "Poor quality control, very disappointed.",
  "Average performance, could be improved.",
  "Incredible breakthrough in AI technology!",
  "Hate everything about this service.",
  "Love the user interface and features.",
  "Neutral opinion, works as expected.",
  "Exceptional value for money spent.",
  "Buggy software, needs major fixes."
];

export default function () {
  // Select random test text
  const randomText = testTexts[Math.floor(Math.random() * testTexts.length)];
  
  // API endpoint
  const url = 'http://api.sentiment-analyzer.local/analyze';
  
  // Request payload
  const payload = JSON.stringify({
    text: randomText
  });
  
  // Request headers
  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
    timeout: '30s', // 30 second timeout for AI processing
  };
  
  // Make the request
  let response = http.post(url, payload, params);
  
  // Check response
  let checkRes = check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 5s': (r) => r.timings.duration < 5000,
    'has label': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.hasOwnProperty('label') && body.hasOwnProperty('confidence');
      } catch (e) {
        return false;
      }
    },
    'confidence is valid': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.confidence >= 0 && body.confidence <= 1;
      } catch (e) {
        return false;
      }
    }
  });
  
  // Record errors
  errorRate.add(!checkRes);
  
  // Log response for debugging (sample only)
  if (Math.random() < 0.01) { // Log 1% of responses
    console.log(`Response: ${response.status}, Duration: ${response.timings.duration}ms`);
    if (response.status === 200) {
      console.log(`Body: ${response.body}`);
    }
  }
  
  // Think time between requests (simulate real user behavior)
  sleep(Math.random() * 2 + 1); // Sleep 1-3 seconds
}

// Setup function - runs once before the test
export function setup() {
  console.log('Starting performance test for Sentiment Analyzer');
  console.log('Target: http://api.sentiment-analyzer.local/analyze');
  console.log('Test scenarios: Ramp up, Load test, Stress test');
  
  // Health check before starting
  let healthCheck = http.get('http://api.sentiment-analyzer.local/health');
  check(healthCheck, {
    'API is healthy': (r) => r.status === 200,
  });
  
  return { message: 'Test initialized successfully' };
}

// Teardown function - runs once after the test
export function teardown(data) {
  console.log('Performance test completed');
  console.log('Check Grafana dashboard for detailed metrics');
}
