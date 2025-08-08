import React, { useState } from "react";
import { useQuery } from "@apollo/client";
import {
  GET_ALL_USERS,
  GET_ALL_SMS_LOGS
} from "../graphql/queries";
import { Header } from "../components";
import { useStateContext } from "../contexts/ContextProvider";
import useIndexedDBCache from "../utils/useIndexedDBCache";
import CacheControls from "../components/SmsLogger/CacheControls";
import ThreePanelLayoutContainer from "../components/SmsLogger/ThreePanelLayoutContainer";
import MultiExportPanel from "../components/SmsLogger/MultiExportPanel";

/**
 * SMS 로거 페이지 컴포넌트
 * IndexedDB를 사용하여 로컬 캐싱을 구현하고, 3분할 레이아웃으로 UI를 제공
 */
const SmsLogger = () => {
  const { currentColor } = useStateContext();
  const [currentView, setCurrentView] = useState('cache'); // 'cache' | 'smsLogger' | 'multiExport'
  
  // IndexedDB 캐시 훅
  const cache = useIndexedDBCache();
  
  const {
    isDataLoaded,
    setIsDataLoaded,
    setLoadTime,
    setDataCounts,
    isLoading,
    setIsLoading,
    loadProgress,
    setLoadProgress,
    saveToIndexedDB,
    saveMetadata,
    initDB
  } = cache;

  // Apollo 쿼리 (필요할 때만 호출할 예정)
  const { refetch: refetchUsers } = useQuery(GET_ALL_USERS, {
    skip: true, // 초기에 실행하지 않음
    fetchPolicy: 'network-only',
  });
  
  const { refetch: refetchSms } = useQuery(GET_ALL_SMS_LOGS, {
    skip: true, // 초기에 실행하지 않음
    fetchPolicy: 'network-only',
  });

  // 데이터 로드 및 캐시 처리
  const handleLoad = async () => {
    setIsLoading(true);
    setLoadProgress({ status: '데이터베이스 초기화 중...', progress: 5 });
    
    try {
      // 사용자 데이터 로드
      setLoadProgress({ status: '사용자 데이터 가져오는 중...', progress: 10 });
      const usersResponse = await refetchUsers();
      const usersData = usersResponse.data.getAllUsers;
      
      // SMS 데이터 로드
      setLoadProgress({ status: 'SMS 로그 데이터 가져오는 중...', progress: 30 });
      const smsResponse = await refetchSms();
      const smsData = smsResponse.data.getAllSmsLogs;
      
      // IndexedDB에 데이터 저장
      setLoadProgress({ status: '사용자 데이터 저장 중...', progress: 50 });
      await saveToIndexedDB('users', usersData);
      
      setLoadProgress({ status: 'SMS 로그 데이터 저장 중...', progress: 70 });
      await saveToIndexedDB('smsLogs', smsData);
      
      // 현재 시간을 메타데이터로 저장
      const now = new Date();
      await saveMetadata('lastCacheTime', now.getTime());
      setLoadTime(now);
      
      // 데이터 카운트 업데이트
      setDataCounts({
        users: usersData.length,
        sms: smsData.length
      });
      
      setLoadProgress({ status: '완료!', progress: 100 });
      setIsDataLoaded(true);
      
      // 사용자에게 알림
      alert(`데이터가 성공적으로 캐시에 저장되었습니다.\n사용자: ${usersData.length}명\nSMS 로그: ${smsData.length}개`);
      
    } catch (error) {
      console.error('데이터 로드 오류:', error);
      setLoadProgress({ status: `오류 발생: ${error.message}`, progress: 0 });
      alert(`데이터 로드 중 오류가 발생했습니다: ${error.message}`);
    } finally {
      setIsLoading(false);
    }
  };

  // 캐시 삭제
  const handleClearCache = async () => {
    if (!window.confirm('모든 캐시 데이터를 삭제하시겠습니까?')) {
      return;
    }
    
    try {
      setIsLoading(true);
      setLoadProgress({ status: '캐시 삭제 중...', progress: 50 });
      
      const db = await initDB();
      const transaction = db.transaction(['users', 'smsLogs', 'metadata'], "readwrite");
      
      transaction.objectStore('users').clear();
      transaction.objectStore('smsLogs').clear();
      transaction.objectStore('metadata').clear();
      
      transaction.oncomplete = () => {
        setIsLoading(false);
        setLoadProgress({ status: '캐시 삭제 완료', progress: 100 });
        setLoadTime(null);
        setIsDataLoaded(false);
        setDataCounts({ users: 0, sms: 0 });
        setCurrentView('cache');
        
        setTimeout(() => {
          setLoadProgress({ status: '', progress: 0 });
        }, 2000);
        
        alert('모든 캐시 데이터가 삭제되었습니다.');
      };
      
      transaction.onerror = (event) => {
        console.error('캐시 삭제 오류:', event.target.error);
        alert(`캐시 삭제 중 오류가 발생했습니다: ${event.target.error}`);
        setIsLoading(false);
      };
    } catch (error) {
      console.error('캐시 삭제 오류:', error);
      alert(`캐시 삭제 중 오류가 발생했습니다: ${error.message}`);
      setIsLoading(false);
    }
  };

  // IndexedDB 데이터 가져오기
  const handleImportData = (event) => {
    const file = event.target.files[0];
    if (!file) return;
    
    const reader = new FileReader();
    
    reader.onload = async (e) => {
      try {
        const importData = JSON.parse(e.target.result);
        
        if (!importData.users || !importData.sms) {
          throw new Error('유효하지 않은 가져오기 파일 형식입니다.');
        }
        
        setIsLoading(true);
        setLoadProgress({ status: '데이터 가져오는 중...', progress: 30 });
        
        // 데이터 저장
        await saveToIndexedDB('users', importData.users);
        await saveToIndexedDB('smsLogs', importData.sms);
        
        // 현재 시간을 메타데이터로 저장
        const now = new Date();
        await saveMetadata('lastCacheTime', now.getTime());
        setLoadTime(now);
        
        // 데이터 카운트 업데이트
        setDataCounts({
          users: importData.users.length,
          sms: importData.sms.length
        });
        
        setLoadProgress({ status: '완료!', progress: 100 });
        setIsDataLoaded(true);
        setIsLoading(false);
        
        alert(`데이터를 성공적으로 가져왔습니다.\n사용자: ${importData.users.length}명\nSMS 로그: ${importData.sms.length}개`);
        
      } catch (error) {
        console.error('데이터 가져오기 오류:', error);
        alert(`데이터 가져오기 중 오류가 발생했습니다: ${error.message}`);
        setIsLoading(false);
      }
      
      // 파일 입력 초기화 (같은 파일 재선택 가능하도록)
      event.target.value = null;
    };
    
    reader.readAsText(file);
  };

  // 뷰 전환
  const switchToSmsLogger = () => {
    setCurrentView('smsLogger');
  };
  
  const switchToCache = () => {
    setCurrentView('cache');
  };

  return (
    <div className="m-2 md:m-10 mt-24 p-2 md:p-10 bg-white rounded-3xl">
      <Header category="어드민 페이지" title="SMS 로거" />
      
      {/* 뷰 전환 탭 */}
      {isDataLoaded && (
        <div className="mb-6">
          <div className="flex border-b">
            <button
              className={`py-2 px-4 ${currentView === 'cache' ? 'border-b-2 font-medium' : 'text-gray-500'}`}
              style={{ borderColor: currentView === 'cache' ? currentColor : 'transparent' }}
              onClick={switchToCache}
            >
              캐시 관리
            </button>
            <button
              className={`py-2 px-4 ${currentView === 'smsLogger' ? 'border-b-2 font-medium' : 'text-gray-500'}`}
              style={{ borderColor: currentView === 'smsLogger' ? currentColor : 'transparent' }}
              onClick={switchToSmsLogger}
            >
              SMS 로거
            </button>
            <button
              className={`py-2 px-4 ${currentView === 'multiExport' ? 'border-b-2 font-medium' : 'text-gray-500'}`}
              style={{ borderColor: currentView === 'multiExport' ? currentColor : 'transparent' }}
              onClick={() => setCurrentView('multiExport')}
            >
              다중 저장
            </button>
          </div>
        </div>
      )}
      
      {currentView === 'cache' && (
        <CacheControls 
          cache={cache}
          onLoad={handleLoad}
          onClearCache={handleClearCache}
          onImportData={handleImportData}
          currentColor={currentColor}
        />
      )}
      
      {/* 메인 컨텐츠 영역 - 데이터가 로드된 경우에만 표시 */}
      {isDataLoaded ? (
        currentView === 'smsLogger' ? (
          <ThreePanelLayoutContainer cache={cache} currentColor={currentColor} />
        ) : currentView === 'multiExport' ? (
          <MultiExportPanel cache={cache} currentColor={currentColor} />
        ) : (
          <div className="bg-white shadow-md rounded-lg p-6 text-center">
            <p className="mb-4">캐시된 데이터를 사용하여 SMS 로거 기능을 이용할 수 있습니다.</p>
            <button
              className="px-4 py-2 text-white rounded-md"
              style={{ backgroundColor: currentColor }}
              onClick={switchToSmsLogger}
            >
              SMS 로거 시작하기
            </button>
          </div>
        )
      ) : (
        <div className="bg-white shadow-md rounded-lg p-6 text-center">
          <p className="text-lg text-gray-600">
            데이터를 먼저 로드하거나 가져오기 해주세요.
          </p>
        </div>
      )}
    </div>
  );
};

export default SmsLogger;