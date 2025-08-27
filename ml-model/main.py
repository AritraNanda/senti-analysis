from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from transformers import pipeline
import os
from contextlib import asynccontextmanager

class AnalyzeRequest(BaseModel):
    text: str

class AnalyzeResponse(BaseModel):
    label: str
    confidence: float

# Global variable to store the model
sentiment_pipeline = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Load model at startup
    global sentiment_pipeline
    sentiment_pipeline = pipeline("sentiment-analysis", model="distilbert-base-uncased-finetuned-sst-2-english")
    yield
    # Cleanup on shutdown (if needed)

app = FastAPI(title="ML Model Service", lifespan=lifespan)

@app.post("/analyze", response_model=AnalyzeResponse)
def analyze(request: AnalyzeRequest):
    try:
        result = sentiment_pipeline(request.text)[0]
        label = result["label"].capitalize()
        confidence = float(result["score"])
        return AnalyzeResponse(label=label, confidence=confidence)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Model error: {e}")
