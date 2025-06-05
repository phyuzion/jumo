import React, { useState } from 'react';
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
 * 사용자의 통화 및 문자 로그를 표시하는 다이얼로그
 * @param {Object} props - 컴포넌트 속성
 * @param {boolean} props.isOpen - 다이얼로그 표시 여부
 * @param {Function} props.onClose - 닫기 버튼 클릭 핸들러
 * @param {Object} props.user - 사용자 객체
 * @param {Array} props.callLogs - 통화 로그 배열
 * @param {Array} props.smsLogs - 문자 로그 배열
 * @param {Function} props.onTabChange - 탭 변경 핸들러
 */
const UsersLogsDialog = ({ 
  isOpen, 
  onClose, 
  user, 
  callLogs, 
  smsLogs, 
  onTabChange 
}) => {
  // 탭 상태 (callLogs, smsLogs)
  const [activeTab, setActiveTab] = useState('callLogs');

  if (!isOpen) return null;

  // 탭 변경 핸들러
  const handleTabChange = (tab) => {
    setActiveTab(tab);
    if (onTabChange) {
      onTabChange(tab);
    }
  };

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
            {user?.name || 'Unknown'} ({user?.loginId || 'Unknown'}) - 사용자 기록
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

        {/* 탭 선택 */}
        <div className="flex border-b">
          <button
            className={`px-4 py-2 font-medium ${
              activeTab === 'callLogs'
                ? 'text-blue-600 border-b-2 border-blue-600'
                : 'text-gray-500 hover:text-gray-700'
            }`}
            onClick={() => handleTabChange('callLogs')}
          >
            통화 로그
          </button>
          <button
            className={`px-4 py-2 font-medium ${
              activeTab === 'smsLogs'
                ? 'text-blue-600 border-b-2 border-blue-600'
                : 'text-gray-500 hover:text-gray-700'
            }`}
            onClick={() => handleTabChange('smsLogs')}
          >
            문자 로그
          </button>
        </div>

        {/* 콘텐츠 */}
        <div className="flex-1 overflow-auto p-4">
          {activeTab === 'callLogs' && (
            <GridComponent
              dataSource={callLogs}
              allowPaging={true}
              pageSettings={{ pageSize: 10 }}
              toolbar={['Search']}
              allowSorting={true}
            >
              <ColumnsDirective>
                <ColumnDirective
                  field="phoneNumber"
                  headerText="전화번호"
                  width="150"
                />
                <ColumnDirective
                  field="time"
                  headerText="시간"
                  width="150"
                  textAlign="Center"
                  valueAccessor={timeAccessor}
                />
                <ColumnDirective
                  field="callType"
                  headerText="유형"
                  width="100"
                  textAlign="Center"
                  template={(log) => {
                    switch (log.callType) {
                      case 'INCOMING':
                        return <span className="text-blue-600">수신</span>;
                      case 'OUTGOING':
                        return <span className="text-green-600">발신</span>;
                      case 'MISSED':
                        return <span className="text-red-600">부재중</span>;
                      case 'REJECTED':
                        return <span className="text-orange-600">거부</span>;
                      default:
                        return <span>{log.callType}</span>;
                    }
                  }}
                />
              </ColumnsDirective>
              <Inject services={[Resize, Sort, Filter, Page, Toolbar, Search]} />
            </GridComponent>
          )}

          {activeTab === 'smsLogs' && (
            <GridComponent
              dataSource={smsLogs}
              allowPaging={true}
              pageSettings={{ pageSize: 10 }}
              toolbar={['Search']}
              allowSorting={true}
            >
              <ColumnsDirective>
                <ColumnDirective
                  field="phoneNumber"
                  headerText="전화번호"
                  width="150"
                />
                <ColumnDirective
                  field="time"
                  headerText="시간"
                  width="150"
                  textAlign="Center"
                  valueAccessor={timeAccessor}
                />
                <ColumnDirective
                  field="smsType"
                  headerText="유형"
                  width="100"
                  textAlign="Center"
                  template={(log) => {
                    switch (log.smsType) {
                      case 'RECEIVED':
                        return <span className="text-blue-600">수신</span>;
                      case 'SENT':
                        return <span className="text-green-600">발신</span>;
                      default:
                        return <span>{log.smsType}</span>;
                    }
                  }}
                />
                <ColumnDirective
                  field="content"
                  headerText="내용"
                  width="300"
                />
              </ColumnsDirective>
              <Inject services={[Resize, Sort, Filter, Page, Toolbar, Search]} />
            </GridComponent>
          )}
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

export default UsersLogsDialog; 