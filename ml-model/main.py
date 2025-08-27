from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from transformers import pipeline
import os

class AnalyzeRequest(BaseModel):
    text: str

class AnalyzeResponse(BaseModel):
    label: str
    confidence: float

app = FastAPI(title="ML Model Service")

# Load model at startup
@app.on_event("startup")
def load_model():
    global sentiment_pipeline
    sentiment_pipeline = pipeline("sentiment-analysis", model="distilbert-base-uncased-finetuned-sst-2-english")

@app.post("/analyze", response_model=AnalyzeResponse)
def analyze(request: AnalyzeRequest):
    try:
        result = sentiment_pipeline(request.text)[0]
        label = result["label"].capitalize()
        confidence = float(result["score"])
        return AnalyzeResponse(label=label, confidence=confidence)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Model error: {e}")
