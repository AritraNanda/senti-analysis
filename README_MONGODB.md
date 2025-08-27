# Sentiment Analyzer with MongoDB

This project has been updated to use MongoDB instead of PostgreSQL for data storage.

## Environment Variables

Create a `.env` file in the `api` folder with your MongoDB connection details:

```env
# For local MongoDB (using docker-compose)
MONGODB_URL=mongodb://admin:password@localhost:27017/sentiment?authSource=admin
DATABASE_NAME=sentiment
ML_MODEL_URL=http://localhost:8001/analyze

# For MongoDB Atlas (cloud)
# MONGODB_URL=mongodb+srv://<username>:<password>@<cluster>.mongodb.net/<database>?retryWrites=true&w=majority
# DATABASE_NAME=sentiment
# ML_MODEL_URL=http://localhost:8001/analyze
```

## Setup Instructions

### Option 1: Using Docker Compose (Recommended)

1. Make sure you have Docker and Docker Compose installed
2. Clone this repository
3. Navigate to the project directory
4. Run the application:

```bash
docker-compose up --build
```

This will start:
- MongoDB database on port 27017
- API service on port 8000
- ML model service on port 8001
- Prometheus on port 9090
- Grafana on port 3000

### Option 2: Using MongoDB Atlas (Cloud)

1. Create a MongoDB Atlas account at https://www.mongodb.com/atlas
2. Create a new cluster
3. Get your connection string from Atlas
4. Update the `MONGODB_URL` in your `.env` file with the Atlas connection string
5. Update the docker-compose.yml to remove the local MongoDB service

## API Endpoints

- `POST /analyze` - Analyze sentiment of text
- `GET /history?limit=50` - Get recent analysis history (optional limit parameter)

## MongoDB Collection Schema

The `sentiment_requests` collection stores documents with the following structure:

```json
{
  "_id": "ObjectId",
  "text": "string",
  "label": "string", 
  "confidence": "number",
  "timestamp": "datetime"
}
```

## Changes from PostgreSQL

- Replaced `psycopg2-binary` and `sqlalchemy` with `motor` and `pymongo`
- Updated database connection to use MongoDB async driver
- Changed from SQL tables to MongoDB collections
- Documents are stored with automatic `_id` generation
- Added optional history endpoint to retrieve stored analyses

## Frontend Integration

The frontend remains unchanged and will work seamlessly with the new MongoDB backend through the same API endpoints.
