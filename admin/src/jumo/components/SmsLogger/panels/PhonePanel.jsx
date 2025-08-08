import React, { forwardRef } from 'react';

const PhonePanel = forwardRef(({ title = '전화번호 목록', phones, activeState, search, onSearch, onSelect, currentColor }, ref) => {
  const renderItem = (phone) => {
    const state = activeState[phone] || 'inactive';
    return (
      <div
        key={phone}
        data-phone={phone}
        className={`cursor-pointer p-2 mb-1 ${
          state === 'selected' ? `bg-opacity-20 border-l-4` : state === 'active' ? 'bg-white' : 'bg-gray-100'
        }`}
        style={{
          borderLeftColor: state === 'selected' ? currentColor : 'transparent',
          backgroundColor: state === 'selected' ? `${currentColor}22` : '',
          opacity: state === 'inactive' ? 0.7 : 1,
        }}
        onClick={() => onSelect(phone)}
      >
        <div className="font-bold">{phone}</div>
      </div>
    );
  };

  return (
    <div className="bg-white shadow-md rounded-lg p-4 h-[70vh] flex flex-col">
      <div className="mb-4">
        <h2 className="font-bold text-lg mb-2">{title}</h2>
        <div className="relative">
          <input
            type="text"
            placeholder="전화번호 검색..."
            className="w-full p-2 pl-8 border rounded-md"
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
      <div ref={ref} className="flex-1 overflow-y-auto">
        {phones.length > 0 ? (
          <div>{phones.map(renderItem)}</div>
        ) : (
          <div className="p-4 text-center text-gray-500">표시할 전화번호가 없습니다.</div>
        )}
      </div>
    </div>
  );
});

export default PhonePanel;


