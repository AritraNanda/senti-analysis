import React from 'react';

const HistoryList = ({ history }) => {
  if (!history.length) return null;
  return (
    <div className="history-list">
      <h3>Analysis History</h3>
      <ul>
        {history.map((item, idx) => (
          <li key={idx}>
            <span>{item.timestamp}:</span> <em>{item.text}</em> → <strong>{item.label}</strong>
          </li>
        ))}
      </ul>
    </div>
  );
};

export default HistoryList;
