// src/jumo/components/Navbar.jsx (수정)

import React, { useEffect } from 'react';
import { AiOutlineMenu } from 'react-icons/ai';
import { RiNotification3Line } from 'react-icons/ri';
import { FiLogOut } from 'react-icons/fi'; // 로그아웃 아이콘 예시
import { TooltipComponent } from '@syncfusion/ej2-react-popups';
import { useNavigate } from 'react-router-dom'; // 라우터 navigate

import { useStateContext } from '../contexts/ContextProvider';

const NavButton = ({ title, customFunc, icon, color, dotColor }) => (
  <TooltipComponent content={title} position="BottomCenter">
    <button
      type='button'
      onClick={customFunc}
      style={{ color }}
      className="relative text-xl rounded-full p-3 hover:bg-light-gray hover:drop-shadow-xl">
      {/* dotColor 있는 경우 알림 표시점 */}
      {dotColor && (
        <span
          style={{ background: dotColor }}
          className="absolute inline-flex rounded-full h-2 w-2 right-2 top-2"
        />
      )}
      {icon}
    </button>
  </TooltipComponent>
);

const Navbar = () => {
  const navigate = useNavigate(); // for redirect
  const {
    activeMenu,
    setActiveMenu,
    isClicked,
    setIsClicked,
    handleClick,
    screenSize,
    setScreenSize,
    currentColor
  } = useStateContext();

  useEffect(() => {
    const handleResize = () => setScreenSize(window.innerWidth);
    window.addEventListener('resize', handleResize);
    handleResize();

    return () => window.removeEventListener('resize', handleResize);
  }, []);

  useEffect(() => {
    if (screenSize <= 900) {
      setActiveMenu(false);
    } else {
      setActiveMenu(true);
    }
  }, [screenSize]);

  // 로그아웃 함수
  const handleLogout = () => {
    localStorage.removeItem('adminToken');
    navigate('/login'); // 또는 window.location.href = '/login';
  };

  return (
    <nav className='flex justify-between p-2 md:mx-6 relative'>
      {/* Sidebar toggle button */}
      <NavButton
        title="Menu"
        customFunc={() => setActiveMenu((prev) => !prev)}
        color={currentColor}
        icon={<AiOutlineMenu />}
      />

      {/* Right side buttons */}
      <div className='flex'>

        <NavButton
          title="Notifications"
          dotColor="#03C9D7"
          customFunc={() => handleClick('notification')}
          color={currentColor}
          icon={<RiNotification3Line />}
        />

        {/* 새로 추가: Logout 버튼 */}
        <NavButton
          title="Logout"
          customFunc={handleLogout}
          color={currentColor}
          icon={<FiLogOut />}
        />
      </div>
    </nav>
  );
};

export default Navbar;
