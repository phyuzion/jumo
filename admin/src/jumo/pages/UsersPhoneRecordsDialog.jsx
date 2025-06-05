import React from 'react';
import { 
  GridComponent, 
  ColumnsDirective, 
  ColumnDirective,
  Resize, 
  Sort, 
  Filter, 
  Page, 
  Inject,
  Toolbar,
  Search,
} from "@syncfusion/ej2-react-grids";
import { parseServerTimeToLocal } from '../../utils/dateUtils';

/**
 * 사용자의 전화번호부 기록을 표시하는 다이얼로그
 * @param {Object} props - 컴포넌트 속성
 * @param {boolean} props.isOpen - 다이얼로그 표시 여부
 * @param {Function} props.onClose - 닫기 버튼 클릭 핸들러
 * @param {Object} props.user - 사용자 객체
 * @param {Array} props.phoneRecords - 전화번호부 기록 배열
 */
const UsersPhoneRecordsDialog = ({ isOpen, onClose, user, phoneRecords }) => {
  if (!isOpen) return null;

  // 시간 변환 헬퍼
  const timeAccessor = (field, data) => {
    if (!data[field]) return '';
    return parseServerTimeToLocal(data[field]);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50 p-4">
      <div className="bg-white rounded-lg shadow-xl w-full max-w-4xl max-h-[90vh] flex flex-col">
        {/* 헤더 */}
        <div className="flex justify-between items-center p-4 border-b">
          <h2 className="text-xl font-semibold">
            {user?.name || 'Unknown'} ({user?.loginId || 'Unknown'}) - 전화번호부 기록
          </h2>
          <button
            onClick={onClose}
            className="text-gray-500 hover:text-gray-700"
          >
            <svg
              className="w-6 h-6"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth="2"
                d="M6 18L18 6M6 6l12 12"
              />
            </svg>
          </button>
        </div>

        {/* 그리드 */}
        <div className="flex-1 overflow-auto p-4">
          <GridComponent
            dataSource={phoneRecords}
            allowPaging={true}
            pageSettings={{ pageSize: 10 }}
            toolbar={['Search']}
            allowSorting={true}
          >
            <ColumnsDirective>
              <ColumnDirective
                field="phoneNumber"
                headerText="전화번호"
                width="120"
              />
              <ColumnDirective field="name" headerText="이름" width="120" />
              <ColumnDirective field="memo" headerText="메모" width="200" />
              <ColumnDirective
                field="type"
                headerText="유형"
                width="80"
                textAlign="Center"
                template={(record) => {
                  switch (record.type) {
                    case 0:
                      return <span className="text-blue-600">일반</span>;
                    case 1:
                      return <span className="text-red-600">위험</span>;
                    case 2:
                      return <span className="text-orange-600">폭탄</span>;
                    default:
                      return <span>{record.type}</span>;
                  }
                }}
              />
              <ColumnDirective
                field="createdAt"
                headerText="생성일자"
                width="120"
                textAlign="Center"
                valueAccessor={timeAccessor}
              />
            </ColumnsDirective>
            <Inject services={[Resize, Sort, Filter, Page, Toolbar, Search]} />
          </GridComponent>
        </div>

        {/* 푸터 */}
        <div className="p-4 border-t flex justify-end">
          <button
            onClick={onClose}
            className="bg-gray-500 text-white px-4 py-2 rounded hover:bg-gray-600"
          >
            닫기
          </button>
        </div>
      </div>
    </div>
  );
};

export default UsersPhoneRecordsDialog; 