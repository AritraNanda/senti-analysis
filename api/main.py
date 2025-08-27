from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from datetime import datetime
import httpx
import os
from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@db:5432/sentiment")
ML_MODEL_URL = os.getenv("ML_MODEL_URL", "http://ml-model:8001/analyze")

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

class SentimentRequest(Base):
    __tablename__ = "sentiment_requests"
    id = Column(Integer, primary_key=True, index=True)
    text = Column(String, nullable=False)
    label = Column(String, nullable=False)
    confidence = Column(Float, nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow)

Base.metadata.create_all(bind=engine)

class AnalyzeRequest(BaseModel):
    text: str

class AnalyzeResponse(BaseModel):
    label: str
    confidence: float

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

    # Log to DB
    db = SessionLocal()
    sentiment = SentimentRequest(
        text=request.text,
        label=data["label"],
        confidence=data["confidence"],
        timestamp=datetime.utcnow()
    )
    db.add(sentiment)
    db.commit()
    db.close()

    return AnalyzeResponse(label=data["label"], confidence=data["confidence"])
