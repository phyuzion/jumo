import React from 'react';
import { parseServerTimeToLocal } from '../../../../utils/dateUtils';

const ConversationPanel = ({ title = '대화 내역', selectedUser, selectedPhone, items, search, onSearch, currentColor }) => {
  const renderMessageItem = (message, index) => {
    const isInbound = message.smsType?.toLowerCase() === 'inbox' || message.smsType?.toLowerCase() === 'in';
    return (
      <div key={index} className={`flex mb-2 ${isInbound ? 'justify-start' : 'justify-end'}`}>
        <div
          className={`p-3 max-w-[70%] rounded-lg ${isInbound ? 'bg-gray-100 text-gray-800 rounded-tl-none' : 'text-white rounded-tr-none'}`}
          style={{ backgroundColor: isInbound ? '' : currentColor }}
        >
          <div>{message.content}</div>
          <div className={`${isInbound ? 'text-left text-gray-500' : 'text-right text-white opacity-80'} text-xs mt-1`}>
            {parseServerTimeToLocal(new Date(message.time).toISOString())}
          </div>
        </div>
      </div>
    );
  };

  return (
    <div className="bg-white shadow-md rounded-lg p-4 h-[70vh] flex flex-col">
      <div className="flex justify-between items-center mb-4">
        <h2 className="text-lg font-bold">
          {title}
          {selectedUser && selectedPhone && (
            <span className="text-sm font-normal ml-2 text-gray-500">
              ({selectedUser.name || '사용자'}{selectedUser.phoneNumber ? `(${selectedUser.phoneNumber})` : ''} ↔ {selectedPhone})
            </span>
          )}
        </h2>
        <div className="relative">
          <input
            type="text"
            placeholder="내용 검색..."
            className="p-2 pl-8 border rounded-md w-[200px]"
            value={search}
            onChange={(e) => onSearch(e.target.value)}
          />
          <span className="absolute left-2 top-2.5 text-gray-400">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
          </span>
          {search && (
            <span className="absolute right-2 top-2.5 text-gray-400 cursor-pointer" onClick={() => onSearch('')}>
              <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            </span>
          )}
        </div>
      </div>
      <div className="flex-1 overflow-y-auto p-2">
        {selectedUser && selectedPhone ? (
          items.length > 0 ? <div>{items.map(renderMessageItem)}</div> : (
            <div className="p-4 text-center text-gray-500">대화 내역이 없습니다.</div>
          )
        ) : (
          <div className="p-4 text-center text-gray-500">사용자와 전화번호를 모두 선택하세요.</div>
        )}
      </div>
    </div>
  );
};

export default ConversationPanel;


