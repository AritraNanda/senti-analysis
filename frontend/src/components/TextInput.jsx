import React, { useState } from 'react';

const TextInput = ({ onAnalyze, loading }) => {
  const [text, setText] = useState('');

  const handleSubmit = (e) => {
    e.preventDefault();
    if (text.trim()) {
      onAnalyze(text);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="text-input-form">
      <textarea
        value={text}
        onChange={e => setText(e.target.value)}
        placeholder="Enter text to analyze..."
        rows={4}
        className="text-input-area"
        disabled={loading}
      />
      <button type="submit" disabled={loading || !text.trim()}>
        {loading ? 'Analyzing...' : 'Analyze'}
      </button>
    </form>
  );
};

export default TextInput;
