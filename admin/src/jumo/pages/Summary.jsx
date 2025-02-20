// src/pages/Summary.jsx
import React, { useEffect } from 'react';
import { useQuery } from '@apollo/client';

import { MdOutlineSupervisorAccount } from 'react-icons/md';
import { BsBoxSeam } from 'react-icons/bs';
import { HiOutlineRefresh } from 'react-icons/hi';

import { GET_SUMMARY } from '../graphql/queries';

const Summary = () => {
  // 1) GET_SUMMARY 호출
  const { data, loading, error } = useQuery(GET_SUMMARY);

  // 2) 로컬 스토리지 저장 (useEffect)
  useEffect(() => {
    if (data && data.getSummary) {
      // 예: { usersCount, phoneCount, dangerPhoneCount }
      localStorage.setItem('summaryData', JSON.stringify(data.getSummary));
    }
  }, [data]);

  if (loading) return <p>Loading summary...</p>;
  if (error) return <p>Error: {error.message}</p>;

  // 3) 서버에서 받은 결과 (새로운 필드명)
  const { usersCount, phoneCount, dangerPhoneCount } = data.getSummary;

  // 4) 카드 구성 예시
  // 아이콘, 개수(amount), 제목(title)을 매핑
  const summaryData = [
    {
      icon: <MdOutlineSupervisorAccount />,
      amount: usersCount,
      title: '유저수',
      iconColor: '#03C9D7',
      iconBg: '#E5FAFB',
    },
    {
      icon: <BsBoxSeam />,
      amount: phoneCount,
      title: '전화번호(문서)수',
      iconColor: 'rgb(255, 244, 229)',
      iconBg: 'rgb(254, 201, 15)',
    },
    {
      icon: <HiOutlineRefresh />,
      amount: dangerPhoneCount,
      title: '위험번호(99) 수',
      iconColor: 'rgb(228, 106, 118)',
      iconBg: 'rgb(255, 244, 229)',
    },
  ];

  return (
    <section className="mt-24 md:mt-2 mx-7">
      <div className="flex flex-wrap lg:flex-nowrap justify-center flex-col items-center">
        <div className="flex m-3 flex-wrap justify-center gap-5 items-center">
          {summaryData.map((item, index) => (
            <div
              key={index}
              className="bg-white dark:text-gray-200 dark:bg-secondary-dark-bg
                         md:w-56 p-4 pt-9 rounded-2xl shadow-xl
                         hover:drop-shadow-xl cursor-pointer flex flex-col items-center"
            >
              {/* 아이콘 영역 */}
              <div className="flex justify-center items-center w-full mb-4">
                <button
                  type="button"
                  style={{ color: item.iconColor, backgroundColor: item.iconBg }}
                  className="text-4xl opacity-0.9 rounded-full p-4 hover:drop-shadow-xl
                             flex items-center justify-center"
                >
                  {item.icon}
                </button>
              </div>

              {/* Amount, Title */}
              <div className="flex w-full px-4">
                <p className="mr-auto text-lg font-semibold">{item.amount}</p>
                <p className="ml-auto text-sm text-gray-500">{item.title}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
};

export default Summary;
