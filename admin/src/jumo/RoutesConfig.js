// RoutesConfig.js

import { Summary, CallLogs, } from './pages';
import { FiShoppingBag } from 'react-icons/fi';
import { AiOutlineCalendar } from 'react-icons/ai';


export const routes = [
  {
    category: "대시보드",
    links: [
      {
        path: "summary",
        name: "요약",
        component: <Summary />,
        icon: <FiShoppingBag />,
      },
    ],
  },
  {
    category: "카테고리",
    links: [
      {
        path: "calllogs",
        name: "수신내역",
        component: <CallLogs />,
        icon: <AiOutlineCalendar />,
      },
    ],
  },
];
