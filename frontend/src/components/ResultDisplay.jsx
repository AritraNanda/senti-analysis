import React from 'react';

const ResultDisplay = ({ result }) => {
  if (!result) return null;
  return (
    <div className="result-display">
      <h3>Sentiment Result</h3>
      <p><strong>Label:</strong> {result.label}</p>
      <p><strong>Confidence:</strong> {(result.confidence * 100).toFixed(2)}%</p>
    </div>
  );
};

export default ResultDisplay;
