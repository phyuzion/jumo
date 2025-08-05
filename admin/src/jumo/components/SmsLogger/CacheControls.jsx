import React from 'react';
import { parseServerTimeToLocal } from '../../../utils/dateUtils';
import { STORES, exportIndexedDBData } from '../../utils/useIndexedDBCache';

/**
 * SMS 로거의 캐시 컨트롤 컴포넌트
 */
const CacheControls = ({ 
  cache, 
  onLoad, 
  onClearCache, 
  onImportData,
  currentColor
}) => {
  const { 
    loadTime, 
    dataCounts, 
    isDataLoaded, 
    isLoading, 
    loadProgress,
    getFromIndexedDB
  } = cache;

  // 데이터 내보내기
  const handleExportData = () => exportIndexedDBData(getFromIndexedDB);

  return (
    <>
      {/* 캐시 상태 표시 */}
      <div className="mb-6 p-4 bg-gray-50 rounded-lg">
        <h2 className="text-lg font-bold mb-3">캐시 상태</h2>
        {loadTime ? (
          <div className="text-sm">
            <p className="text-green-600 font-semibold">
              마지막 캐시 생성: {parseServerTimeToLocal(loadTime.toISOString())}
            </p>
            <p className="mt-1 text-gray-600">
              사용자: {dataCounts.users}명, SMS 로그: {dataCounts.sms}개가 캐시되어 있습니다.
            </p>
          </div>
        ) : (
          <p className="text-orange-600">
            캐시된 데이터가 없습니다. '로드' 버튼을 클릭하여 데이터를 가져오세요.
          </p>
        )}
      </div>
      
      {/* 로드 및 캐시 컨트롤 */}
      <div className="bg-white shadow-md rounded-lg p-6 mb-6">
        <h2 className="text-lg font-bold mb-4">데이터 로드 및 캐시 관리</h2>
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* 서버에서 로드 */}
          <div>
            <h3 className="font-semibold mb-2">서버에서 데이터 로드</h3>
            <p className="text-sm text-gray-600 mb-3">
              서버에서 모든 사용자와 SMS 로그 데이터를 가져와 브라우저 캐시에 저장합니다.
            </p>
            
            <button
              className="px-4 py-2 text-white rounded-md mr-2"
              style={{ backgroundColor: currentColor }}
              onClick={onLoad}
              disabled={isLoading}
            >
              {isLoading ? '로딩 중...' : '로드'}
            </button>
            
            <button
              className="px-4 py-2 text-white bg-red-500 rounded-md"
              onClick={onClearCache}
              disabled={isLoading || !isDataLoaded}
            >
              캐시 삭제
            </button>
            
            {/* 로딩 프로그레스 */}
            {isLoading && (
              <div className="mt-4">
                <div className="w-full h-2 bg-gray-200 rounded-full">
                  <div 
                    className="h-2 bg-blue-500 rounded-full" 
                    style={{ 
                      width: `${loadProgress.progress}%`,
                      backgroundColor: currentColor 
                    }}
                  ></div>
                </div>
                <div className="text-sm text-gray-600 mt-1">{loadProgress.status}</div>
              </div>
            )}
          </div>
          
          {/* 데이터 내보내기/가져오기 */}
          <div>
            <h3 className="font-semibold mb-2">데이터 내보내기/가져오기</h3>
            <p className="text-sm text-gray-600 mb-3">
              캐시된 데이터를 파일로 내보내거나 이전에 내보낸 파일을 가져올 수 있습니다.
            </p>
            
            <div className="flex flex-col space-y-3">
              <div>
                <button
                  className="px-4 py-2 text-white rounded-md mr-2"
                  style={{ backgroundColor: currentColor }}
                  onClick={handleExportData}
                  disabled={!isDataLoaded}
                >
                  데이터 내보내기
                </button>
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  데이터 가져오기
                </label>
                <input 
                  type="file" 
                  accept=".json" 
                  onChange={onImportData}
                  disabled={isLoading}
                  className="block w-full text-sm text-gray-500
                    file:mr-4 file:py-2 file:px-4
                    file:rounded-md file:border-0
                    file:text-sm file:font-semibold
                    file:bg-gray-100 file:text-gray-700
                    hover:file:bg-gray-200"
                />
              </div>
            </div>
          </div>
        </div>
      </div>
    </>
  );
};

export default CacheControls;