// RoutesConfig.js
import { PhoneRecords, Summary, Users, Contents, Notifications } from './pages';
import { FiShoppingBag } from 'react-icons/fi';
import { AiOutlineCalendar, AiOutlinePhone, AiOutlineBook, AiOutlineBell } from 'react-icons/ai';

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
        path: "records",
        name: "전화번호부",
        component: <PhoneRecords />,
        icon: <AiOutlinePhone />,
      },
      {
        path: "contents",
        name: "게시판",
        component: <Contents />,
        icon: <AiOutlineBook />,
      },
      {
        path: "notifications",
        name: "알림",
        component: <Notifications />,
        icon: <AiOutlineBell />,
      },
    ],
  },
];
