import React, { useEffect } from 'react';
import { AiOutlineMenu } from 'react-icons/ai';
import { RiNotification3Line } from 'react-icons/ri';
import { TooltipComponent } from '@syncfusion/ej2-react-popups';

import { useStateContext } from '../contexts/ContextProvider';


const NavButton = ({ title, customFunc, icon, color, dotColor }) => (
  <TooltipComponent content={title} position="BottomCenter" >
    <button
      type='button'
      onClick={customFunc}
      style={{ color }}
      className="relative text-xl rounded-full p-3 hover:bg-light-gray hover:drop-shadow-xl">
      <span style={{ background: dotColor }} className="absolute inline-flex rounded-full h-2 w-2 right-2 top-2" />
      {icon}
    </button>
  </TooltipComponent>
)


const Navbar = () => {

  const { activeMenu, setActiveMenu, isClicked, setIsClicked, handleClick, screenSize, setScreenSize, currentColor } = useStateContext();

  useEffect(() => {
    const handleResize = () => setScreenSize(window.innerWidth)
    window.addEventListener('resize', handleResize)
    handleResize()

    return () => window.removeEventListener('resize', handleResize)
  }, [])

  useEffect(() => {
    if (screenSize <= 900) {
      setActiveMenu(false)
    } else {
      setActiveMenu(true)
    }
  }, [screenSize])


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

      </div>
    </nav>
  )
};

export default Navbar;
