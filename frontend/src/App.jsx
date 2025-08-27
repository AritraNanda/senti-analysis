import React, { useState } from 'react';
import TextInput from './components/TextInput';
import ResultDisplay from './components/ResultDisplay';
import HistoryList from './components/HistoryList';
import './App.css';

const InfoSection = () => (
  <div className="info-section">
    <h2>What is Sentiment Analysis?</h2>
    <p>
      Sentiment analysis uses AI to determine whether a piece of text is positive, negative, or neutral. It's widely used in social media monitoring, customer feedback, and more.
    </p>
    <ul>
      <li>🔍 Analyze any English text instantly</li>
      <li>⚡ Fast, AI-powered results</li>
      <li>📝 See your recent analysis history</li>
    </ul>
  </div>
);


function App() {
  const [result, setResult] = useState(null);
  const [loading, setLoading] = useState(false);
  const [history, setHistory] = useState([]);

  // Real API call to backend
  const analyzeText = async (text) => {
    setLoading(true);
    setResult(null);
    try {
      const response = await fetch("/api/analyze", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ text })
      });
      if (!response.ok) throw new Error("API error");
      const data = await response.json();
      setResult(data);
      setHistory(prev => [
        { text, label: data.label, timestamp: new Date().toLocaleString() },
        ...prev
      ]);
    } catch (err) {
      setResult({ label: "Error", confidence: 0 });
    }
    setLoading(false);
  };

  return (
    <div className="main-bg">
      <header className="header">
        <span className="logo-emoji" role="img" aria-label="AI">🤖</span>
        <h1>AI Sentiment Analyzer</h1>
      </header>
      <div className="app-container">
        <InfoSection />
        <TextInput onAnalyze={analyzeText} loading={loading} />
        <ResultDisplay result={result} />
        <HistoryList history={history} />
      </div>
      <footer className="footer">
        <span>Made with <span role="img" aria-label="love">❤️</span> by Aritra</span>
      </footer>
    </div>
  );
}

export default App;
