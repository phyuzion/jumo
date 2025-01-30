import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import JumoAdmin from './jumo/JumoAdmin.jsx';

const App = () => {
  return (
    <BrowserRouter>
      <Routes>
        {/* 기본 경로는 Admin으로 리다이렉트 */}
        <Route path="/" element={<Navigate to="/" />} />
        {/* Admin 페이지 */}
        <Route path="/*" element={<JumoAdmin />} />
      </Routes>
    </BrowserRouter>
  );
};

export default App;
