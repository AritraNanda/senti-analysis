from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from datetime import datetime
import httpx
import os
from typing import List
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv

load_dotenv()

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

app = FastAPI(title="Sentiment Analysis API Service")

@app.post("/analyze", response_model=AnalyzeResponse)
async def analyze(request: AnalyzeRequest):
    async with httpx.AsyncClient() as client:
        try:
            ml_response = await client.post(ML_MODEL_URL, json={"text": request.text})
            ml_response.raise_for_status()
            data = ml_response.json()
        except Exception as e:
            raise HTTPException(status_code=502, detail=f"ML Model Service error: {e}")

    # Log to MongoDB
    sentiment_doc = {
        "text": request.text,
        "label": data["label"],
        "confidence": data["confidence"],
        "timestamp": datetime.utcnow()
    }
    await collection.insert_one(sentiment_doc)

    return AnalyzeResponse(label=data["label"], confidence=data["confidence"])

@app.get("/history", response_model=List[HistoryItem])
async def get_history(limit: int = 50):
    """Get recent sentiment analysis history"""
    cursor = collection.find({}, {"_id": 0}).sort("timestamp", -1).limit(limit)
    history = await cursor.to_list(length=limit)
    return history
