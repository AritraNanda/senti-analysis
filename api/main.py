from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from datetime import datetime
import httpx
import os
import time
from typing import List
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv
import logging

load_dotenv()

# Configure logging
logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))
logger = logging.getLogger(__name__)

MONGODB_URL = os.getenv("MONGODB_URL", "mongodb://db:27017")
DATABASE_NAME = os.getenv("DATABASE_NAME", "sentiment")
ML_MODEL_URL = os.getenv("ML_MODEL_URL", "http://ml-model:8001/analyze")

# MongoDB client with SSL handling for Atlas
if "mongodb+srv" in MONGODB_URL:
    # For MongoDB Atlas, add SSL parameters
    client = AsyncIOMotorClient(MONGODB_URL, tls=True, tlsAllowInvalidCertificates=True)
else:
    # For local MongoDB
    client = AsyncIOMotorClient(MONGODB_URL)

database = client[DATABASE_NAME]
collection = database["sentiment_requests"]

# Metrics tracking
request_count = 0
error_count = 0
total_response_time = 0.0

class AnalyzeRequest(BaseModel):
    text: str

class AnalyzeResponse(BaseModel):
    label: str
    confidence: float

class HistoryItem(BaseModel):
    text: str
    label: str
    confidence: float
    timestamp: datetime

class HealthResponse(BaseModel):
    status: str
    database: str
    ml_service: str
    uptime: str

class MetricsResponse(BaseModel):
    total_requests: int
    error_count: int
    average_response_time: float

app = FastAPI(title="Sentiment Analysis API Service", version="1.0.0")

# Application startup time
startup_time = time.time()

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint for Kubernetes probes"""
    global startup_time
    
    # Check database connection
    try:
        await database.list_collection_names()
        db_status = "healthy"
    except Exception as e:
        logger.error(f"Database health check failed: {e}")
        db_status = "unhealthy"
    
    # Check ML service connection
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            ml_response = await client.get(f"{ML_MODEL_URL.replace('/analyze', '/health')}")
            ml_status = "healthy" if ml_response.status_code == 200 else "unhealthy"
    except Exception as e:
        logger.error(f"ML service health check failed: {e}")
        ml_status = "unhealthy"
    
    uptime = time.time() - startup_time
    
    # Return unhealthy if any dependency is down
    overall_status = "healthy" if db_status == "healthy" and ml_status == "healthy" else "unhealthy"
    
    return HealthResponse(
        status=overall_status,
        database=db_status,
        ml_service=ml_status,
        uptime=f"{uptime:.2f}s"
    )

@app.get("/metrics", response_model=MetricsResponse)
async def get_metrics():
    """Metrics endpoint for Prometheus scraping"""
    global request_count, error_count, total_response_time
    
    avg_response_time = total_response_time / request_count if request_count > 0 else 0
    
    return MetricsResponse(
        total_requests=request_count,
        error_count=error_count,
        average_response_time=avg_response_time
    )

@app.post("/analyze", response_model=AnalyzeResponse)
async def analyze(request: AnalyzeRequest):
    """Analyze sentiment of input text"""
    global request_count, error_count, total_response_time
    
    start_time = time.time()
    request_count += 1
    
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            try:
                ml_response = await client.post(ML_MODEL_URL, json={"text": request.text})
                ml_response.raise_for_status()
                data = ml_response.json()
            except Exception as e:
                error_count += 1
                logger.error(f"ML Model Service error: {e}")
                raise HTTPException(status_code=502, detail=f"ML Model Service error: {e}")

        # Log to MongoDB
        sentiment_doc = {
            "text": request.text,
            "label": data["label"],
            "confidence": data["confidence"],
            "timestamp": datetime.utcnow(),
            "response_time": time.time() - start_time
        }
        
        try:
            await collection.insert_one(sentiment_doc)
        except Exception as e:
            logger.warning(f"Failed to log to database: {e}")
            # Don't fail the request if logging fails
        
        response_time = time.time() - start_time
        total_response_time += response_time
        
        logger.info(f"Processed sentiment analysis in {response_time:.3f}s: {data['label']}")
        
        return AnalyzeResponse(label=data["label"], confidence=data["confidence"])
        
    except HTTPException:
        raise
    except Exception as e:
        error_count += 1
        logger.error(f"Unexpected error: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {e}")

@app.get("/history", response_model=List[HistoryItem])
async def get_history(limit: int = 50):
    """Get recent sentiment analysis history"""
    try:
        cursor = collection.find({}, {"_id": 0}).sort("timestamp", -1).limit(limit)
        history = await cursor.to_list(length=limit)
        return history
    except Exception as e:
        logger.error(f"Failed to retrieve history: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve history")

# Startup event
@app.on_event("startup")
async def startup_event():
    logger.info("API Service starting up...")
    logger.info(f"MongoDB URL: {MONGODB_URL}")
    logger.info(f"ML Model URL: {ML_MODEL_URL}")

# Shutdown event
@app.on_event("shutdown")
async def shutdown_event():
    logger.info("API Service shutting down...")
    client.close()
