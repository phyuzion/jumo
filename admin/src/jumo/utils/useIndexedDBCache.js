import { useState, useEffect, useCallback } from 'react';

// IndexedDB 데이터베이스 이름 및 스토어 이름 상수
export const DB_NAME = "smsLoggerDB";
export const DB_VERSION = 1;
export const STORES = {
  users: "users",
  sms: "smsLogs",
  meta: "metadata"
};

/**
 * IndexedDB를 사용한 캐시 관리 훅
 */
export const useIndexedDBCache = () => {
  const [loadTime, setLoadTime] = useState(null);
  const [isDataLoaded, setIsDataLoaded] = useState(false);
  const [dataCounts, setDataCounts] = useState({
    users: 0,
    sms: 0
  });
  const [isLoading, setIsLoading] = useState(false);
  const [loadProgress, setLoadProgress] = useState({
    status: '',
    progress: 0
  });

  // IndexedDB 초기화
  const initDB = useCallback(() => {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open(DB_NAME, DB_VERSION);
      
      request.onerror = (event) => {
        console.error("IndexedDB 에러:", event.target.error);
        reject("IndexedDB를 열 수 없습니다.");
      };
      
      request.onsuccess = (event) => {
        console.log("IndexedDB가 성공적으로 열렸습니다.");
        resolve(event.target.result);
      };
      
      request.onupgradeneeded = (event) => {
        const db = event.target.result;
        
        // 사용자 스토어 생성
        if (!db.objectStoreNames.contains(STORES.users)) {
          const userStore = db.createObjectStore(STORES.users, { keyPath: "id" });
          userStore.createIndex("loginId", "loginId", { unique: false });
          userStore.createIndex("name", "name", { unique: false });
        }
        
        // SMS 로그 스토어 생성
        if (!db.objectStoreNames.contains(STORES.sms)) {
          const smsStore = db.createObjectStore(STORES.sms, { keyPath: "id", autoIncrement: true });
          smsStore.createIndex("userId", "userId", { unique: false });
          smsStore.createIndex("phoneNumber", "phoneNumber", { unique: false });
        }
        
        // 메타데이터 스토어 생성
        if (!db.objectStoreNames.contains(STORES.meta)) {
          db.createObjectStore(STORES.meta, { keyPath: "key" });
        }
        
        console.log("IndexedDB 스토어가 생성되었습니다.");
      };
    });
  }, []);

  // 데이터 저장 함수
  const saveToIndexedDB = useCallback(async (storeName, data, clearFirst = true) => {
    const db = await initDB();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction(storeName, "readwrite");
      const store = transaction.objectStore(storeName);
      
      if (clearFirst) {
        const clearRequest = store.clear();
        clearRequest.onsuccess = () => {
          console.log(`${storeName} 스토어를 비웠습니다.`);
        };
      }
      
      let count = 0;
      
      // 배열일 경우 (사용자 또는 SMS 데이터)
      if (Array.isArray(data)) {
        data.forEach(item => {
          // SMS 로그의 경우 별도의 ID가 없을 수 있으므로 자동 생성
          // 자동 생성을 위해 id가 있다면 제거
          if (storeName === STORES.sms && item.id) {
            const { id, ...rest } = item;
            const request = store.add(rest);
            request.onsuccess = () => count++;
          } else {
            const request = store.put(item);
            request.onsuccess = () => count++;
          }
        });
      } 
      // 단일 객체일 경우 (메타데이터 등)
      else {
        const request = store.put(data);
        request.onsuccess = () => count++;
      }
      
      transaction.oncomplete = () => {
        console.log(`${storeName}에 ${count}개 항목을 저장했습니다.`);
        resolve(count);
      };
      
      transaction.onerror = (event) => {
        console.error(`${storeName} 저장 오류:`, event.target.error);
        reject(event.target.error);
      };
    });
  }, [initDB]);

  // IndexedDB에서 데이터 가져오기
  const getFromIndexedDB = useCallback(async (storeName, key = null) => {
    const db = await initDB();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction(storeName, "readonly");
      const store = transaction.objectStore(storeName);
      
      if (key !== null) {
        // 특정 키의 데이터만 가져오기
        const request = store.get(key);
        
        request.onsuccess = () => {
          resolve(request.result);
        };
        
        request.onerror = (event) => {
          reject(event.target.error);
        };
      } else {
        // 전체 데이터 가져오기
        const request = store.getAll();
        
        request.onsuccess = () => {
          resolve(request.result);
        };
        
        request.onerror = (event) => {
          reject(event.target.error);
        };
      }
    });
  }, [initDB]);

  // IndexedDB에서 데이터 쿼리하기
  const queryIndexedDB = useCallback(async (storeName, indexName, query) => {
    const db = await initDB();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction(storeName, "readonly");
      const store = transaction.objectStore(storeName);
      const index = store.index(indexName);
      
      const request = index.getAll(query);
      
      request.onsuccess = () => {
        resolve(request.result);
      };
      
      request.onerror = (event) => {
        reject(event.target.error);
      };
    });
  }, [initDB]);

  // IndexedDB에서 데이터 카운트 가져오기
  const getCountFromIndexedDB = useCallback(async (storeName) => {
    const db = await initDB();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction(storeName, "readonly");
      const store = transaction.objectStore(storeName);
      const request = store.count();
      
      request.onsuccess = () => {
        resolve(request.result);
      };
      
      request.onerror = (event) => {
        reject(event.target.error);
      };
    });
  }, [initDB]);

  // 메타데이터 저장
  const saveMetadata = useCallback(async (key, value) => {
    return saveToIndexedDB(STORES.meta, { key, value }, false);
  }, [saveToIndexedDB]);

  // 메타데이터 가져오기
  const getMetadata = useCallback(async (key) => {
    try {
      return await getFromIndexedDB(STORES.meta, key);
    } catch (error) {
      console.error('메타데이터 조회 오류:', error);
      return null;
    }
  }, [getFromIndexedDB]);

  // 캐시 상태 확인
  useEffect(() => {
    const checkCacheStatus = async () => {
      try {
        // 메타데이터에서 마지막 캐시 시간 확인
        const cacheTime = await getMetadata('lastCacheTime');
        
        if (cacheTime) {
          setLoadTime(new Date(cacheTime.value));
          
          // 데이터 카운트 확인
          const usersCount = await getCountFromIndexedDB(STORES.users);
          const smsCount = await getCountFromIndexedDB(STORES.sms);
          
          setDataCounts({
            users: usersCount,
            sms: smsCount
          });
          
          setIsDataLoaded(usersCount > 0 && smsCount > 0);
        }
      } catch (error) {
        console.error('캐시 상태 확인 오류:', error);
      }
    };
    
    checkCacheStatus();
  }, [getMetadata, getCountFromIndexedDB]);

  return {
    loadTime,
    setLoadTime,
    isDataLoaded,
    setIsDataLoaded,
    dataCounts,
    setDataCounts,
    isLoading,
    setIsLoading,
    loadProgress,
    setLoadProgress,
    initDB,
    saveToIndexedDB,
    getFromIndexedDB,
    queryIndexedDB,
    getCountFromIndexedDB,
    saveMetadata,
    getMetadata
  };
};

// IndexedDB 데이터 내보내기
export const exportIndexedDBData = async (getFromIndexedDB) => {
  try {
    const usersData = await getFromIndexedDB(STORES.users);
    const smsData = await getFromIndexedDB(STORES.sms);
    
    const exportData = {
      users: usersData,
      sms: smsData,
      exportDate: new Date().toISOString()
    };
    
    const blob = new Blob([JSON.stringify(exportData, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    
    const a = document.createElement('a');
    a.href = url;
    a.download = `sms_logger_export_${new Date().toISOString().slice(0, 10)}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    
    alert('데이터가 성공적으로 내보내졌습니다.');
  } catch (error) {
    console.error('데이터 내보내기 오류:', error);
    alert(`데이터 내보내기 중 오류가 발생했습니다: ${error.message}`);
  }
};

export default useIndexedDBCache;