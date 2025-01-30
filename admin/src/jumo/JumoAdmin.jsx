// JumoAdmin.jsx
import React, { useEffect, useState } from 'react';
import { Routes, Route, Navigate, useLocation } from 'react-router-dom';
import { Navbar, Sidebar } from './components/index.jsx';
import { routes } from './RoutesConfig.js';
import { ContextProvider, useStateContext } from './contexts/ContextProvider.js';
import './JumoAdmin.css';

import Summary from './pages/Summary.jsx';
import CallLogs from './pages/CallLogs.jsx';
// 필요시 import Login from './pages/Login.jsx'; // (지금은 App.js에서 분리했으니 X)

const JumoAdminContent = () => {
  const { activeMenu } = useStateContext();
  const [menuInitialized, setMenuInitialized] = useState(false);

  // 토큰 체크
  const token = localStorage.getItem('adminToken');
  const location = useLocation();

  useEffect(() => {
    setMenuInitialized(true);
  }, []);

  // 만약 토큰이 없다 && 현재 경로가 "/login"이 아니라면 => 로그인 페이지로
  // (단, App.js에서 이미 /login 라우트를 분리했으면 이 부분은 생략 가능)
  if (!token && location.pathname !== '/login') {
    return <Navigate to="/login" />;
  }

  if (!menuInitialized) return null;

  return (
    <div className="flex relative dark:bg-main-dark-bg">
      {/* Sidebar */}
      {activeMenu ? (
        <div className="w-56 fixed sidebar dark:bg-secondary-dark-bg bg-white">
          <Sidebar />
        </div>
      ) : (
        <div className="w-0 dark:bg-secondary-dark-bg">
          <Sidebar />
        </div>
      )}

      {/* Main Content */}
      <div
        className={`dark:bg-main-dark-bg bg-main-bg min-h-screen w-full ${
          activeMenu ? 'md:ml-56' : 'flex-2'
        }`}
      >
        <Navbar />

        <Routes>
          {/* 기본 "/" -> "/summary" */}
          <Route path="/" element={<Navigate to="/summary" />} />

          {/* 아래: Dynamic RoutesConfig */}
          {routes.map((category) =>
            category.links.map((route, index) => (
              <Route key={index} path={route.path} element={route.component} />
            ))
          )}

          {/* 예시: 직접 import 한 페이지를 여기서 라우팅해도 됨 */}
          {/* <Route path="/summary" element={<Summary />} />
          <Route path="/calllogs" element={<CallLogs />} /> */}
        </Routes>
      </div>
    </div>
  );
};

const JumoAdmin = () => {
  return (
    <ContextProvider>
      <JumoAdminContent />
    </ContextProvider>
  );
};

export default JumoAdmin;
