import React, { useEffect, useState } from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import { Navbar, Sidebar } from './components/index.jsx';
import { routes } from './RoutesConfig.js';
import { ContextProvider, useStateContext } from './contexts/ContextProvider.js';
import './JumoAdmin.css';

const JumoAdminContent = () => {
  const { activeMenu } = useStateContext();
  const [menuInitialized, setMenuInitialized] = useState(false);

  // activeMenu가 초기 상태에서 제대로 설정되도록 보장
  useEffect(() => {
    setMenuInitialized(true);
  }, []);

  if (!menuInitialized) return null; // 초기화 전까지는 렌더링하지 않음

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
          {/* Default Redirect */}
          <Route path="/" element={<Navigate to="/summary" />} />
          {/* Dynamic Routes */}
          {routes.map((category) =>
            category.links.map((route, index) => (
              <Route key={index} path={route.path} element={route.component} />
            ))
          )}
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
