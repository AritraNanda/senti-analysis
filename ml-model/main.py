from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from transformers import pipeline
import os
import time
import logging
from contextlib import asynccontextmanager

# Configure logging
logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))
logger = logging.getLogger(__name__)

class AnalyzeRequest(BaseModel):
    text: str

class AnalyzeResponse(BaseModel):
    label: str
    confidence: float

class HealthResponse(BaseModel):
    status: str
    model_loaded: bool
    uptime: str

# Global variable to store the model
sentiment_pipeline = None
startup_time = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Load model at startup
    global sentiment_pipeline, startup_time
    
    logger.info("Loading sentiment analysis model...")
    startup_time = time.time()
    
    try:
        sentiment_pipeline = pipeline(
            "sentiment-analysis", 
            model="distilbert-base-uncased-finetuned-sst-2-english"
        )
        logger.info("Model loaded successfully")
    except Exception as e:
        logger.error(f"Failed to load model: {e}")
        raise e
    
    yield
    
    # Cleanup on shutdown (if needed)
    logger.info("ML Model service shutting down...")

app = FastAPI(title="ML Model Service", version="1.0.0", lifespan=lifespan)

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint for Kubernetes probes"""
    global sentiment_pipeline, startup_time
    
    model_loaded = sentiment_pipeline is not None
    uptime = time.time() - startup_time if startup_time else 0
    status = "healthy" if model_loaded else "unhealthy"
    
    return HealthResponse(
        status=status,
        model_loaded=model_loaded,
        uptime=f"{uptime:.2f}s"
    )

@app.post("/analyze", response_model=AnalyzeResponse)
def analyze(request: AnalyzeRequest):
    """Analyze sentiment of input text"""
    global sentiment_pipeline
    
    if sentiment_pipeline is None:
        logger.error("Model not loaded")
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    if not request.text or len(request.text.strip()) == 0:
        raise HTTPException(status_code=400, detail="Text cannot be empty")
    
    if len(request.text) > 5000:  # Limit text length for performance
        raise HTTPException(status_code=400, detail="Text too long (max 5000 characters)")
    
    try:
        start_time = time.time()
        result = sentiment_pipeline(request.text)[0]
        processing_time = time.time() - start_time
        
        label = result["label"].capitalize()
        confidence = float(result["score"])
        
        logger.info(f"Processed text in {processing_time:.3f}s: {label} ({confidence:.3f})")
        
        return AnalyzeResponse(label=label, confidence=confidence)
        
    except Exception as e:
        logger.error(f"Model error: {e}")
        raise HTTPException(status_code=500, detail=f"Model error: {e}")

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "ML Model Service",
        "version": "1.0.0",
        "model": "distilbert-base-uncased-finetuned-sst-2-english",
        "status": "running"
    }
