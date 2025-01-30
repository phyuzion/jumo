// RoutesConfig.js
import { Summary, Users, Customers, CallLogs, } from './pages';
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
        path: "users",
        name: "유저",
        component: <Users />,
        icon: <AiOutlineCalendar />,
      },
      {
        path: "customers",
        name: "고객",
        component: <Customers />,
        icon: <AiOutlineCalendar />,
      },
      {
        path: "calllogs",
        name: "수신내역",
        component: <CallLogs />,
        icon: <AiOutlineCalendar />,
      },
    ],
  },
];
