// RoutesConfig.js
import { PhoneRecords, Summary, Users, Contents, Notifications, Version, CommonSettings } from './pages';
import { FiShoppingBag } from 'react-icons/fi';
import { AiOutlineCalendar, AiOutlinePhone, AiOutlineBook, AiOutlineBell, AiOutlineFile, AiOutlineSetting } from 'react-icons/ai';

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
        path: "common-settings",
        name: "공통설정",
        component: <CommonSettings />,
        icon: <AiOutlineSetting />,
      },
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
      {
        path: "version",
        name: "버전",
        component: <Version />,
        icon: <AiOutlineFile />,
      },
    ],
  },
];
