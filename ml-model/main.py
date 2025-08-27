from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from transformers import pipeline
import os
import time
import logging
from contextlib import asynccontextmanager
import re
from typing import Dict, List, Tuple
from statistics import mode, mean

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

# Global variables to store models
sentiment_models = {}
startup_time = None

def preprocess_text(text: str) -> str:
    """Clean and normalize text before analysis"""
    # Remove extra whitespace
    text = re.sub(r'\s+', ' ', text.strip())
    
    # Handle common negations better
    negations = {
        "don't": "do not",
        "doesn't": "does not", 
        "didn't": "did not",
        "won't": "will not",
        "wouldn't": "would not",
        "can't": "can not",
        "cannot": "can not",
        "isn't": "is not",
        "aren't": "are not",
        "wasn't": "was not",
        "weren't": "were not",
        "haven't": "have not",
        "hasn't": "has not",
        "hadn't": "had not",
        "shouldn't": "should not",
        "couldn't": "could not"
    }
    
    for contraction, expansion in negations.items():
        text = re.sub(rf"\b{contraction}\b", expansion, text, flags=re.IGNORECASE)
    
    # Remove excessive punctuation but keep some for context
    text = re.sub(r'[!]{2,}', '!', text)
    text = re.sub(r'[?]{2,}', '?', text)
    text = re.sub(r'[.]{2,}', '...', text)
    
    return text

def normalize_label(label: str) -> str:
    """Normalize different model label formats to consistent output"""
    label_lower = label.lower()
    
    # Map various positive labels
    if label_lower in ['positive', 'pos', 'label_2']:
        return "Positive"
    # Map various negative labels  
    elif label_lower in ['negative', 'neg', 'label_0']:
        return "Negative"
    # Map neutral labels
    elif label_lower in ['neutral', 'label_1']:
        return "Neutral"
    else:
        # Capitalize first letter as fallback
        return label.capitalize()

def ensemble_predict(text: str, models: Dict) -> Tuple[str, float]:
    """Use ensemble of models for better predictions"""
    predictions = []
    confidences = []
    
    for model_name, model in models.items():
        try:
            result = model(text)[0]
            normalized_label = normalize_label(result['label'])
            predictions.append(normalized_label)
            confidences.append(result['score'])
            
            logger.debug(f"{model_name}: {normalized_label} ({result['score']:.3f})")
        except Exception as e:
            logger.warning(f"Model {model_name} failed: {e}")
            continue
    
    if not predictions:
        raise Exception("All models failed to predict")
    
    # If we have multiple predictions, use voting with confidence weighting
    if len(predictions) > 1:
        # Weight predictions by confidence
        weighted_votes = {}
        for pred, conf in zip(predictions, confidences):
            if pred not in weighted_votes:
                weighted_votes[pred] = 0
            weighted_votes[pred] += conf
        
        # Get prediction with highest weighted vote
        final_prediction = max(weighted_votes.items(), key=lambda x: x[1])[0]
        
        # Calculate average confidence for the winning prediction
        winning_confidences = [conf for pred, conf in zip(predictions, confidences) if pred == final_prediction]
        final_confidence = mean(winning_confidences)
        
    else:
        # Single model prediction
        final_prediction = predictions[0]
        final_confidence = confidences[0]
    
    # Apply confidence boosting for unanimous decisions
    if len(set(predictions)) == 1:  # All models agree
        final_confidence = min(0.99, final_confidence * 1.1)  # Boost confidence slightly
    
    return final_prediction, final_confidence

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Load models at startup
    global sentiment_models, startup_time
    
    logger.info("Loading sentiment analysis models...")
    startup_time = time.time()
    
    # Define models to load (in order of preference)
    model_configs = [
        {
            "name": "roberta",
            "model": "cardiffnlp/twitter-roberta-base-sentiment-latest",
            "primary": True
        },
        {
            "name": "distilbert", 
            "model": "distilbert-base-uncased-finetuned-sst-2-english",
            "primary": False
        }
    ]
    
    # Try to load models, continue if some fail
    for config in model_configs:
        try:
            logger.info(f"Loading {config['name']} model...")
            sentiment_models[config['name']] = pipeline(
                "sentiment-analysis", 
                model=config['model']
            )
            logger.info(f"{config['name']} model loaded successfully")
        except Exception as e:
            logger.error(f"Failed to load {config['name']} model: {e}")
            if config['primary']:
                logger.warning("Primary model failed, service may have reduced performance")
    
    if not sentiment_models:
        logger.error("No models loaded successfully!")
        raise RuntimeError("Failed to load any sentiment analysis models")
    
    logger.info(f"Service ready with {len(sentiment_models)} model(s): {list(sentiment_models.keys())}")
    
    yield
    
    # Cleanup on shutdown
    logger.info("ML Model service shutting down...")
    sentiment_models.clear()

app = FastAPI(title="ML Model Service", version="2.0.0", lifespan=lifespan)

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint for Kubernetes probes"""
    global sentiment_models, startup_time
    
    model_loaded = len(sentiment_models) > 0
    uptime = time.time() - startup_time if startup_time else 0
    status = "healthy" if model_loaded else "unhealthy"
    
    return HealthResponse(
        status=status,
        model_loaded=model_loaded,
        uptime=f"{uptime:.2f}s"
    )

@app.post("/analyze", response_model=AnalyzeResponse)
def analyze(request: AnalyzeRequest):
    """Analyze sentiment of input text using enhanced ensemble approach"""
    global sentiment_models
    
    if not sentiment_models:
        logger.error("No models loaded")
        raise HTTPException(status_code=503, detail="No models loaded")
    
    if not request.text or len(request.text.strip()) == 0:
        raise HTTPException(status_code=400, detail="Text cannot be empty")
    
    if len(request.text) > 5000:  # Limit text length for performance
        raise HTTPException(status_code=400, detail="Text too long (max 5000 characters)")
    
    try:
        start_time = time.time()
        
        # Preprocess the text
        processed_text = preprocess_text(request.text)
        logger.debug(f"Original: '{request.text}' -> Processed: '{processed_text}'")
        
        # Get ensemble prediction
        label, confidence = ensemble_predict(processed_text, sentiment_models)
        
        processing_time = time.time() - start_time
        
        logger.info(f"Processed text in {processing_time:.3f}s: {label} ({confidence:.3f}) using {len(sentiment_models)} model(s)")
        
        return AnalyzeResponse(label=label, confidence=confidence)
        
    except Exception as e:
        logger.error(f"Model error: {e}")
        raise HTTPException(status_code=500, detail=f"Model error: {str(e)}")

@app.get("/")
async def root():
    """Root endpoint with enhanced service info"""
    global sentiment_models
    
    return {
        "service": "Enhanced ML Model Service",
        "version": "2.0.0",
        "models": list(sentiment_models.keys()) if sentiment_models else [],
        "features": [
            "Multi-model ensemble",
            "Text preprocessing", 
            "Confidence weighting",
            "Improved accuracy"
        ],
        "status": "running"
    }

@app.get("/models")
async def get_models():
    """Get information about loaded models"""
    global sentiment_models
    
    return {
        "loaded_models": len(sentiment_models),
        "model_names": list(sentiment_models.keys()),
        "ensemble_enabled": len(sentiment_models) > 1
    }