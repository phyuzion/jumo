// App.js
import React from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import JumoAdmin from './jumo/JumoAdmin.jsx';
import Login from './jumo/pages/Login.jsx'; // 로그인 컴포넌트

const App = () => {
  return (
    <BrowserRouter>
      <Routes>
        {/* /login 경로 -> Login 페이지 */}
        <Route path="/login" element={<Login />} />

        {/* 그 외 -> JumoAdmin */}
        <Route path="/*" element={<JumoAdmin />} />
      </Routes>
    </BrowserRouter>
  );
};

export default App;
