# Sentiment Analyzer - Local Development Setup

A full-stack sentiment analysis application using React frontend, FastAPI backend, DistilBERT ML model, and MongoDB Atlas database.

## 🏗️ Architecture

```
Frontend (React + Vite)     →     API Service (FastAPI)     →     ML Model Service (DistilBERT)
Port: 5173                        Port: 8000                       Port: 8001
                                      ↓
                              MongoDB Atlas (Cloud Database)
```

## 📋 Prerequisites

- Python 3.8+ installed
- Node.js and npm installed
- MongoDB Atlas account with connection string
- Git

## 🚀 Quick Start Guide

### 1. Clone and Setup Environment

```bash
# Clone the repository
git clone <your-repo-url>
cd Senti_anlyzr

# Create Python virtual environment
python -m venv .venv
source .venv/bin/activate  # On macOS/Linux
# OR
.venv\Scripts\activate     # On Windows
```

### 2. Configure Environment Variables

Create/update the `.env` file in the `api` folder:

```bash
# Edit api/.env file
MONGODB_URL=mongodb+srv://username:password@cluster.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0
DATABASE_NAME=sentiment
ML_MODEL_URL=http://127.0.0.1:8001/analyze
```

Replace `username`, `password`, and `cluster` with your actual MongoDB Atlas credentials.

## 🔧 Installation & Running Services

### Terminal 1: ML Model Service (Port 8001)

```bash
# Navigate to project directory
cd /path/to/Senti_anlyzr

# Activate virtual environment
source .venv/bin/activate

# Install ML model dependencies
pip install fastapi uvicorn transformers onnxruntime pydantic torch torchvision torchaudio

# Start ML model service
cd ml-model
PYTHONPATH=/path/to/Senti_anlyzr/ml-model /path/to/Senti_anlyzr/.venv/bin/uvicorn ml-model.main:app --host 127.0.0.1 --port 8001

# OR run from project root:
PYTHONPATH=/path/to/Senti_anlyzr/ml-model /path/to/Senti_anlyzr/.venv/bin/uvicorn ml-model.main:app --host 127.0.0.1 --port 8001
```

**Note**: The first time you run this, it will download the DistilBERT model (~268MB). This may take a few minutes.

### Terminal 2: API Service (Port 8000)

```bash
# Navigate to project directory
cd /path/to/Senti_anlyzr

# Activate virtual environment
source .venv/bin/activate

# Install API dependencies
pip install fastapi uvicorn httpx motor pymongo python-dotenv

# Start API service
PYTHONPATH=/path/to/Senti_anlyzr/api /path/to/Senti_anlyzr/.venv/bin/uvicorn api.main:app --host 127.0.0.1 --port 8000
```

### Terminal 3: Frontend Service (Port 5173)

```bash
# Navigate to frontend directory
cd /path/to/Senti_anlyzr/frontend

# Install dependencies (if not already done)
npm install

# Start development server
npm run dev
```

## 🌐 Access the Application

Once all three services are running:

- **Frontend**: http://localhost:5173/
- **API Documentation**: http://127.0.0.1:8000/docs
- **ML Model Documentation**: http://127.0.0.1:8001/docs

## 📝 Usage

1. Open your browser and go to http://localhost:5173/
2. Enter text in the input field (e.g., "I love this project!")
3. Click "Analyze" to get sentiment analysis results
4. View your analysis history below the results

## 🛠️ Development Commands

### Testing API Endpoints

```bash
# Test ML Model Service
curl -X POST http://127.0.0.1:8001/analyze \
  -H "Content-Type: application/json" \
  -d '{"text":"I am happy"}'

# Test API Service
curl -X POST http://127.0.0.1:8000/analyze \
  -H "Content-Type: application/json" \
  -d '{"text":"I am happy"}'

# Get analysis history
curl http://127.0.0.1:8000/history
```

### Installing Additional Dependencies

```bash
# For ML Model Service
cd ml-model
pip install -r requirements.txt

# For API Service
cd api
pip install -r requirements.txt

# For Frontend
cd frontend
npm install
```

## 🐛 Troubleshooting

### Common Issues and Solutions

1. **Port Already in Use**
   ```bash
   # Kill processes on specific ports
   lsof -ti:8000 | xargs kill -9  # API service
   lsof -ti:8001 | xargs kill -9  # ML model service
   lsof -ti:5173 | xargs kill -9  # Frontend service
   ```

2. **MongoDB Connection Issues**
   - Verify your connection string in `api/.env`
   - Check MongoDB Atlas cluster is running
   - Ensure IP address is whitelisted in Atlas

3. **Module Import Errors**
   - Make sure virtual environment is activated
   - Verify PYTHONPATH is set correctly
   - Run from the correct directory

4. **ML Model Download Issues**
   - Ensure stable internet connection
   - The model download may take time on first run
   - Check available disk space (268MB required)

### Stopping Services

To stop all services, press `Ctrl+C` in each terminal running the services.

## 📊 Project Structure

```
Senti_anlyzr/
├── api/                    # FastAPI backend service
│   ├── main.py            # API endpoints and MongoDB integration
│   ├── requirements.txt   # Python dependencies
│   ├── .env              # Environment variables
│   └── Dockerfile
├── ml-model/              # ML model service
│   ├── main.py           # DistilBERT sentiment analysis
│   ├── requirements.txt  # Python dependencies
│   └── Dockerfile
├── frontend/              # React frontend
│   ├── src/              # React components
│   ├── package.json      # Node.js dependencies
│   └── vite.config.js    # Vite configuration
├── .venv/                # Python virtual environment
└── docker-compose.yml   # Docker setup (optional)
```

## 🚀 Production Deployment

For production deployment, consider:
- Using proper SSL certificates for MongoDB connection
- Setting up environment-specific configuration
- Using Docker containers for consistent deployment
- Setting up proper logging and monitoring
- Using a process manager like PM2 for Node.js or systemd for Python services

## 📜 API Endpoints

- `POST /analyze` - Analyze sentiment of text
- `GET /history?limit=50` - Get recent analysis history

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test locally using the above commands
5. Submit a pull request

---

**Happy analyzing! 🎉**
