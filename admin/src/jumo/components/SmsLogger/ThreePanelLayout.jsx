import React, { useState, useEffect, useMemo, useRef, useCallback } from 'react';
import { STORES } from '../../utils/useIndexedDBCache';
import { parseServerTimeToLocal } from '../../../utils/dateUtils';
import {
  GridComponent,
  ColumnsDirective,
  ColumnDirective,
  Resize,
  Sort,
  Page,
  Inject,
  ExcelExport
} from '@syncfusion/ej2-react-grids';

/**
 * SMS 로거의 3분할 레이아웃 컴포넌트
 * 좌측: 사용자 목록, 중앙: 전화번호 목록, 우측: 대화 내역
 */
const ThreePanelLayout = ({ 
  cache,
  currentColor 
}) => {
  const { 
    getFromIndexedDB
  } = cache;

  // 데이터 상태
  const [usersData, setUsersData] = useState([]);
  const [phonesData, setPhonesData] = useState([]);
  const [smsLogsData, setSmsLogsData] = useState([]);
  const [selectedUser, setSelectedUser] = useState(null);
  const [selectedPhone, setSelectedPhone] = useState(null);
  const [conversations, setConversations] = useState([]);
  
  // 아이템 상태 (활성화, 비활성화, 선택)
  const [userActiveState, setUserActiveState] = useState({});
  const [phoneActiveState, setPhoneActiveState] = useState({});

  // 검색 상태
  const [userSearch, setUserSearch] = useState('');
  const [phoneSearch, setPhoneSearch] = useState('');
  const [contentSearch, setContentSearch] = useState('');
  
  // 로딩 상태
  const [isLoading, setIsLoading] = useState(true);
  
  // 스크롤 컨테이너 참조
  const userScrollContainerRef = useRef(null);
  const phoneScrollContainerRef = useRef(null);
  
  // 선택된 항목으로 스크롤 이동
  const scrollToSelected = useCallback((container, itemId, itemType) => {
    console.log(`스크롤 시도: ${itemType} - ${itemId}, 타입: ${typeof itemId}`, container);
    
    if (!container || !container.current) {
      console.log('컨테이너가 없음:', container);
      return;
    }
    
    // 약간의 지연 시간을 두어 렌더링 후 스크롤이 이동하도록 함
    setTimeout(() => {
      console.log(`스크롤 타이머 실행: ${itemType} - ${itemId}`);
      
      // 컨테이너의 모든 data 속성 요소 로그
      if (itemType === 'phone') {
        const allItems = container.current.querySelectorAll('[data-phone]');
        console.log('모든 전화번호 항목:', Array.from(allItems).map(el => el.getAttribute('data-phone')));
      }
      
      const selector = `[data-${itemType}="${itemId}"]`;
      console.log('찾는 선택자:', selector);
      
      const selectedItem = container.current.querySelector(selector);
      console.log('찾은 아이템:', selectedItem);
      
      if (selectedItem) {
        console.log('스크롤 실행:', selectedItem);
        selectedItem.scrollIntoView({ behavior: 'smooth', block: 'center' });
      } else {
        console.error('아이템을 찾을 수 없음:', selector);
        
        // 다른 방법으로 시도
        console.log('모든 자식 요소:', container.current.children);
        
        // 직접 문자열 비교로 찾기 시도
        if (itemType === 'phone') {
          const allDivs = container.current.querySelectorAll('div[data-phone]');
          for (let i = 0; i < allDivs.length; i++) {
            const phoneValue = allDivs[i].getAttribute('data-phone');
            console.log(`비교: "${phoneValue}" vs "${itemId}"`);
            if (phoneValue === String(itemId)) {
              console.log('직접 비교로 찾음:', allDivs[i]);
              allDivs[i].scrollIntoView({ behavior: 'smooth', block: 'center' });
              break;
            }
          }
        }
      }
    }, 100);
  }, []);

  // 사용자 선택 시 스크롤 처리 추가
  useEffect(() => {
    console.log('사용자 선택 변경:', selectedUser);
    if (selectedUser) {
      console.log('사용자 스크롤 호출:', selectedUser.id, userScrollContainerRef);
      scrollToSelected(userScrollContainerRef, selectedUser.id, 'user');
    }
  }, [selectedUser, scrollToSelected]);

  // 전화번호 선택 시 스크롤 처리 추가
  useEffect(() => {
    if (selectedPhone) {  
      // DOM에 직접 접근하여 스크롤 처리
      setTimeout(() => {
        if (phoneScrollContainerRef.current) {
          const phoneElements = phoneScrollContainerRef.current.querySelectorAll('div[data-phone]');
          let targetElement = null;
          
          // 모든 전화번호 요소 확인
          phoneElements.forEach(el => {
            const phoneAttr = el.getAttribute('data-phone');
            if (phoneAttr === selectedPhone) {
              targetElement = el;
            }
          });
          
          // 찾은 요소로 스크롤
          if (targetElement) {
            targetElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
          } else {
          }
        }
      }, 300);
    }
  }, [selectedPhone]);

  // 데이터 로딩
  useEffect(() => {
    const loadData = async () => {
      try {
        setIsLoading(true);
        
        // SMS 로그 데이터 가져오기
        const smsLogs = await getFromIndexedDB(STORES.sms);
        setSmsLogsData(smsLogs || []);
        
        // 유저 데이터 가져오기 (SMS 로그와 매칭되는 유저만)
        const users = await getFromIndexedDB(STORES.users);
        
        // SMS 로그에 있는 고유 userId 목록 추출
        const uniqueUserIds = [...new Set(smsLogs.filter(log => log.userId).map(log => log.userId))];
        
        // SMS 로그와 매칭되는 유저만 필터링
        const matchingUsers = users.filter(user => uniqueUserIds.includes(user.id));
        setUsersData(matchingUsers);
        
        // 전화번호 데이터 가져오기 (유니크한 전화번호만)
        const uniquePhoneNumbers = [...new Set(smsLogs.map(log => log.phoneNumber))];
        setPhonesData(uniquePhoneNumbers);
        
        // 초기 상태 설정 - 모두 비활성화
        const initialUserState = {};
        const initialPhoneState = {};
        
        matchingUsers.forEach(user => {
          initialUserState[user.id] = 'inactive';
        });
        
        uniquePhoneNumbers.forEach(phone => {
          initialPhoneState[phone] = 'inactive';
        });
        
        setUserActiveState(initialUserState);
        setPhoneActiveState(initialPhoneState);
        
        setIsLoading(false);
      } catch (error) {
        console.error('데이터 로딩 오류:', error);
        setIsLoading(false);
      }
    };
    
    loadData();
  }, [getFromIndexedDB]);

  // 특정 유저와 특정 전화번호 간의 대화 내역 조회
  const getConversationBetween = (userId, phoneNumber) => {
    return smsLogsData.filter(
      log => log.userId === userId && log.phoneNumber === phoneNumber
    ).sort((a, b) => new Date(a.time) - new Date(b.time));
  };

  // 유저 선택
  const handleUserSelect = (user) => {
    // 이미 선택된 유저를 클릭한 경우
    if (selectedUser && selectedUser.id === user.id) {
      return;
    }

    // 검색 초기화
    setUserSearch('');
    
    // 이 유저가 연락한 전화번호 찾기
    const userSmsLogs = smsLogsData.filter(log => log.userId === user.id);
    const relatedPhones = [...new Set(userSmsLogs.map(log => log.phoneNumber))];
    
    // 활성화 상태 업데이트
    const newUserState = {};
    const newPhoneState = {};
    
    // 디버깅용 로그
    console.log('유저 선택 - selectedPhone 상태:', selectedPhone);
    
    // 선택된 전화번호가 있는 경우 (파생 시나리오)
    if (selectedPhone) {
      setSelectedUser(user);
      
      // 선택된 유저와 전화번호 간의 대화 내역 조회
      const conversation = getConversationBetween(user.id, selectedPhone);
      setConversations(conversation);
      
      // 이 전화번호와 연락한 모든 유저 찾기
      const phoneSmslogs = smsLogsData.filter(log => log.phoneNumber === selectedPhone);
      const usersWithPhone = [...new Set(phoneSmslogs.filter(log => log.userId).map(log => log.userId))];
      
      // 모든 유저는 비활성화하고, 이 전화번호와 대화한 유저들은 활성화, 선택된 유저만 'selected'
      usersData.forEach(u => {
        if (u.id === user.id) {
          newUserState[u.id] = 'selected';
        } else if (usersWithPhone.includes(u.id)) {
          newUserState[u.id] = 'active';
        } else {
          newUserState[u.id] = 'inactive';
        }
      });
      
      // 전화번호 상태 유지 - 선택된 전화번호만 'selected', 나머지는 이 유저가 사용하는 번호만 활성화
      phonesData.forEach(phone => {
        if (phone === selectedPhone) {
          newPhoneState[phone] = 'selected';
        } else if (relatedPhones.includes(phone)) {
          newPhoneState[phone] = 'active';
        } else {
          newPhoneState[phone] = 'inactive';
        }
      });
    } else {
      // 전화번호가 선택되지 않은 경우 (1번 시나리오)
      setSelectedUser(user);
      setConversations([]);
      
      // 모든 유저는 비활성화하고 선택된 유저만 'selected'
      usersData.forEach(u => {
        newUserState[u.id] = 'inactive';
      });
      newUserState[user.id] = 'selected';
      
      // 전화번호 활성화 상태 업데이트
      phonesData.forEach(phone => {
        newPhoneState[phone] = relatedPhones.includes(phone) ? 'active' : 'inactive';
      });
    }
    
    setUserActiveState(newUserState);
    setPhoneActiveState(newPhoneState);
    
    // 중요: 사용자 선택 시 선택된 전화번호가 있다면 전화번호 목록에서도 스크롤 처리
    if (selectedPhone) {
      // 전화번호 목록으로 스크롤 (타이머 추가로 상태 업데이트 후 스크롤)
      setTimeout(() => {
        console.log('사용자 선택 후 전화번호로 스크롤 시도:', selectedPhone);
        if (phoneScrollContainerRef.current) {
          const phoneElements = phoneScrollContainerRef.current.querySelectorAll('div[data-phone]');
          let targetElement = null;
          
          // 모든 전화번호 요소 확인
          phoneElements.forEach(el => {
            const phoneAttr = el.getAttribute('data-phone');
            if (phoneAttr === selectedPhone) {
              targetElement = el;
            }
          });
          
          // 찾은 요소로 스크롤
          if (targetElement) {
            targetElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
          }
        }
      }, 300);
    }
  };

  // 전화번호 선택
  const handlePhoneSelect = (phone) => {
    // 이미 선택된 전화번호를 클릭한 경우
    if (selectedPhone === phone) {
      return;
    }

    // 검색 초기화
    setPhoneSearch('');
    
    // 전화번호가 비활성화된 상태에서 선택한 경우
    if (phoneActiveState[phone] === 'inactive') {
      // 모든 선택 초기화
      setSelectedUser(null);
      setSelectedPhone(phone);
      setConversations([]);
      
      // 이 전화번호와 연락한 유저 찾기
      const phoneSmsLogs = smsLogsData.filter(log => log.phoneNumber === phone);
      const relatedUserIds = [...new Set(phoneSmsLogs.filter(log => log.userId).map(log => log.userId))];
      
      // 활성화 상태 업데이트
      const newUserState = {};
      const newPhoneState = {};
      
      // 유저 활성화 상태 업데이트
      usersData.forEach(user => {
        newUserState[user.id] = relatedUserIds.includes(user.id) ? 'active' : 'inactive';
      });
      
      // 모든 전화번호는 비활성화하고 선택된 전화번호만 'selected'
      phonesData.forEach(p => {
        newPhoneState[p] = 'inactive';
      });
      newPhoneState[phone] = 'selected';
      
      setUserActiveState(newUserState);
      setPhoneActiveState(newPhoneState);
      return;
    }
    
    // 활성화된 전화번호 선택
    setSelectedPhone(phone);
    
    if (selectedUser) {
      // 이미 유저가 선택된 상태에서 전화번호 선택 (3번 시나리오)
      // 선택된 유저와 전화번호 간의 대화 내역 조회
      const conversation = getConversationBetween(selectedUser.id, phone);
      setConversations(conversation);
      
      // 이 전화번호와 대화한 모든 유저 찾기
      const phoneSmslogs = smsLogsData.filter(log => log.phoneNumber === phone);
      const usersWithPhone = [...new Set(phoneSmslogs.filter(log => log.userId).map(log => log.userId))];
      
      // 유저 상태 업데이트 - 이 전화번호와 대화한 유저들 활성화
      const newUserState = { ...userActiveState };
      usersData.forEach(u => {
        if (u.id === selectedUser.id) {
          newUserState[u.id] = 'selected';
        } else if (usersWithPhone.includes(u.id)) {
          newUserState[u.id] = 'active';
        } else {
          newUserState[u.id] = 'inactive';
        }
      });
      setUserActiveState(newUserState);
      
      // 전화번호 상태 업데이트 - 선택된 전화번호만 'selected', 나머지는 그대로 유지
      const newPhoneState = { ...phoneActiveState };
      Object.keys(newPhoneState).forEach(p => {
        if (p === phone) {
          newPhoneState[p] = 'selected';
        } else if (newPhoneState[p] === 'selected') {
          // 이전에 선택됐던 전화번호는 active로 변경
          newPhoneState[p] = 'active';
        }
      });
      
      setPhoneActiveState(newPhoneState);
    } else {
      // 유저가 선택되지 않은 상태에서 활성화된 전화번호 선택 (2번 시나리오)
      // 이 전화번호와 연락한 유저 찾기
      const phoneSmsLogs = smsLogsData.filter(log => log.phoneNumber === phone);
      const relatedUserIds = [...new Set(phoneSmsLogs.filter(log => log.userId).map(log => log.userId))];
      
      // 활성화 상태 업데이트
      const newUserState = {};
      const newPhoneState = {};
      
      // 유저 활성화 상태 업데이트 - 이 전화번호와 대화한 유저만 활성화
      usersData.forEach(user => {
        newUserState[user.id] = relatedUserIds.includes(user.id) ? 'active' : 'inactive';
      });
      
      // 모든 전화번호는 비활성화하고 선택된 전화번호만 'selected'
      phonesData.forEach(p => {
        newPhoneState[p] = 'inactive';
      });
      newPhoneState[phone] = 'selected';
      
      setUserActiveState(newUserState);
      setPhoneActiveState(newPhoneState);
      setConversations([]);
    }
  };

  // 비활성화된 유저 선택
  const handleInactiveUserSelect = (user) => {
    // 모든 검색 초기화
    setUserSearch('');
    setPhoneSearch('');
    setContentSearch('');
    
    // 모든 선택 초기화
    setSelectedUser(user);
    setSelectedPhone(null);
    setConversations([]);
    
    // 이 유저가 연락한 전화번호 찾기
    const userSmsLogs = smsLogsData.filter(log => log.userId === user.id);
    const relatedPhones = [...new Set(userSmsLogs.map(log => log.phoneNumber))];
    
    // 활성화 상태 업데이트
    const newUserState = {};
    const newPhoneState = {};
    
    // 모든 유저는 비활성화하고 선택된 유저만 'selected'
    usersData.forEach(u => {
      newUserState[u.id] = 'inactive';
    });
    newUserState[user.id] = 'selected';
    
    // 전화번호 활성화 상태 업데이트
    phonesData.forEach(phone => {
      newPhoneState[phone] = relatedPhones.includes(phone) ? 'active' : 'inactive';
    });
    
    setUserActiveState(newUserState);
    setPhoneActiveState(newPhoneState);
  };

  // 모든 상태 초기화
  const handleReset = () => {
    setSelectedUser(null);
    setSelectedPhone(null);
    setConversations([]);
    setUserSearch('');
    setPhoneSearch('');
    setContentSearch('');
    
    // 모든 아이템 비활성화 상태로 초기화
    const resetUserState = {};
    const resetPhoneState = {};
    
    usersData.forEach(user => {
      resetUserState[user.id] = 'inactive';
    });
    
    phonesData.forEach(phone => {
      resetPhoneState[phone] = 'inactive';
    });
    
    setUserActiveState(resetUserState);
    setPhoneActiveState(resetPhoneState);
  };

  // 엑셀 파일용 그리드 참조
  const excelGridRef = useRef(null);
  
  // 문자열 정제 함수 - XML과 호환되지 않는 문자 제거/치환
  const sanitizeString = (str) => {
    if (!str) return '';
    
    // XML에서 허용되지 않는 문자 제거 (ASCII 제어 문자)
    let result = str.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '');
    
    // XML 특수문자 치환
    result = result
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&apos;');
      
    return result;
  };

  // 파일명 특수문자 정제
  const sanitizeFileName = (name) => {
    return name.replace(/[\\/:*?"<>|]/g, '_');
  };
  
  // 엑셀용 데이터 생성 (시간을 KST로 변환)
  const prepareDataForExport = () => {
    if (!filteredConversations || !Array.isArray(filteredConversations)) return [];
    
    return filteredConversations.map(item => ({
      phoneNumber: sanitizeString(item.phoneNumber),
      time: parseServerTimeToLocal(item.time),
      content: sanitizeString(item.content || ''),
      smsType: item.smsType
    }));
  };

  // 엑셀 다운로드
  const handleExcelDownload = () => {
    try {
      if (!excelGridRef.current || !filteredConversations || filteredConversations.length === 0) {
        alert('다운로드할 대화 내역이 없습니다.');
        return;
      }
      
      // 파일명 생성
      let fileName = 'SMS_대화내역';
      
      // 선택된 사용자나 전화번호 정보 추가
      if (selectedUser) {
        fileName += `_${sanitizeFileName(selectedUser.name || selectedUser.loginId || '')}`;
      }
      
      if (selectedPhone) {
        fileName += `_${sanitizeString(selectedPhone)}`;
      }
      
      fileName += `_${new Date().toISOString().slice(0, 10)}`;
      
      // 엑셀 내보내기 설정
      const exportProperties = {
        fileName: `${fileName}.xlsx`,
        header: {
          headerRows: 2,
          rows: [
            { cells: [{ colSpan: 4, value: '대화 내역', style: { fontSize: 12, hAlign: 'Center', bold: true } }] },
            { cells: [{ colSpan: 4, value: selectedUser ? `사용자: ${selectedUser.name || selectedUser.loginId}` : '' +
                        selectedPhone ? `전화번호: ${selectedPhone}` : '', style: { fontSize: 11, bold: true, hAlign: 'Center' } }] }
          ]
        },
        footer: {
          footerRows: 1,
          rows: [{ cells: [{ colSpan: 4, value: '출력일: ' + new Date().toLocaleString(), style: { fontSize: 10 } }] }]
        },
        workbook: {
          worksheets: [{ worksheetName: '대화내역' }]
        },
        // 유니코드 지원 및 안전한 내보내기 설정
        enableFilter: false,
        encodeHtml: false,
        exportType: 'xlsx',
        dataSource: prepareDataForExport(),
        columns: [
          { field: 'phoneNumber', width: 120 },
          { field: 'time', width: 150, wrapText: true },
          { field: 'smsType', width: 80 },
          { field: 'content', width: 400, wrapText: true }
        ]
      };
      
      excelGridRef.current.excelExport(exportProperties);
    } catch (error) {
      console.error('엑셀 내보내기 중 오류:', error);
      alert('엑셀 파일 생성 중 오류가 발생했습니다.');
    }
  };

  // 필터링된 사용자 목록
  const filteredUsers = useMemo(() => {
    let result = [...usersData];
    
    // 검색어로 필터링
    if (userSearch) {
      const search = userSearch.toLowerCase();
      result = result.filter(user => (
        (user.name && user.name.toLowerCase().includes(search)) ||
        (user.phoneNumber && user.phoneNumber.includes(search)) ||
        (user.loginId && user.loginId.toLowerCase().includes(search))
      ));
    }
    
    // 활성화 상태에 따라 정렬 (selected -> active -> inactive)
    result.sort((a, b) => {
      const stateA = userActiveState[a.id] || 'inactive';
      const stateB = userActiveState[b.id] || 'inactive';
      
      if (stateA === 'selected') return -1;
      if (stateB === 'selected') return 1;
      if (stateA === 'active' && stateB !== 'active') return -1;
      if (stateB === 'active' && stateA !== 'active') return 1;
      return 0;
    });
    
    return result;
  }, [usersData, userSearch, userActiveState]);

  // 필터링된 전화번호 목록
  const filteredPhones = useMemo(() => {
    let result = [...phonesData];
    
    // 검색어로 필터링
    if (phoneSearch) {
      result = result.filter(phone => phone.includes(phoneSearch));
    }
    
    // 활성화된 전화번호(검정색)는 위로, 비활성화된 전화번호(회색)는 아래로 정렬
    result.sort((a, b) => {
      const stateA = phoneActiveState[a] || 'inactive';
      const stateB = phoneActiveState[b] || 'inactive';
      
      // 활성화 상태인지 비활성화 상태인지만 구분
      if (stateA !== 'inactive' && stateB === 'inactive') return -1; // A가 활성화되었고 B가 비활성화됨 -> A가 위로
      if (stateA === 'inactive' && stateB !== 'inactive') return 1;  // A가 비활성화되었고 B가 활성화됨 -> B가 위로
      return 0; // 둘 다 활성화 또는 비활성화된 경우 원래 순서 유지
    });
    
    return result;
  }, [phonesData, phoneSearch, phoneActiveState]);

  // 필터링된 대화 내역
  const filteredConversations = useMemo(() => {
    if (!conversations.length) return [];
    
    return conversations.filter(conv => {
      if (!contentSearch) return true;
      return conv.content && conv.content.includes(contentSearch);
    });
  }, [conversations, contentSearch]);

  // 사용자 아이템 렌더링
  const renderUserItem = (user) => {
    const state = userActiveState[user.id] || 'inactive';
    
    const handleClick = () => {
      if (state === 'inactive') {
        handleInactiveUserSelect(user);
      } else {
        handleUserSelect(user);
      }
    };
    
    return (
      <div
        key={user.id}
        data-user={user.id} // 스크롤 타겟으로 사용할 데이터 속성
        className={`cursor-pointer p-2 mb-1 ${
          state === 'selected'
            ? `bg-opacity-20 border-l-4`
            : state === 'active'
            ? 'bg-white'
            : 'bg-gray-100'
        }`}
        style={{
          borderLeftColor: state === 'selected' ? currentColor : 'transparent',
          backgroundColor: state === 'selected' ? `${currentColor}22` : '',
          opacity: state === 'inactive' ? 0.7 : 1
        }}
        onClick={handleClick}
      >
        <div className="font-bold">{user.name || '이름 없음'}</div>
        <div className="text-sm text-gray-600">{user.phoneNumber || user.loginId}</div>
      </div>
    );
  };

  // 전화번호 아이템 렌더링
  const renderPhoneItem = (phone) => {
    const state = phoneActiveState[phone] || 'inactive';
    
    const handleClick = () => {
      handlePhoneSelect(phone);
    };
    
    // 전화번호에 해당하는 사용자 정보 찾기
    const relatedUser = usersData.find(u => u.phoneNumber === phone);
        
    return (
      <div
        key={phone}
        data-phone={phone} // 스크롤 타겟으로 사용할 데이터 속성
        className={`cursor-pointer p-2 mb-1 ${
          state === 'selected'
            ? `bg-opacity-20 border-l-4`
            : state === 'active'
            ? 'bg-white'
            : 'bg-gray-100'
        }`}
        style={{
          borderLeftColor: state === 'selected' ? currentColor : 'transparent',
          backgroundColor: state === 'selected' ? `${currentColor}22` : '',
          opacity: state === 'inactive' ? 0.7 : 1
        }}
        onClick={handleClick}
      >
        <div className="font-bold">{phone}</div>
        <div className="text-sm text-gray-600">
          {relatedUser ? relatedUser.name : '외부 번호'}
        </div>
      </div>
    );
  };

  // 메시지 아이템 렌더링
  const renderMessageItem = (message, index) => {
    const isInbound = message.smsType.toLowerCase() === 'inbox' || message.smsType.toLowerCase() === 'in';
    const currentUser = usersData.find(user => user.id === message.userId);
    const messageDate = new Date(message.time);
    
    return (
      <div 
        key={index} 
        className={`flex mb-2 ${isInbound ? 'justify-start' : 'justify-end'}`}
      >
        <div
          className={`p-3 max-w-[70%] rounded-lg ${
            isInbound
              ? 'bg-gray-100 text-gray-800 rounded-tl-none'
              : 'text-white rounded-tr-none'
          }`}
          style={{ backgroundColor: isInbound ? '' : currentColor }}
        >
          <div>{message.content}</div>
          <div 
            className={`text-xs mt-1 ${isInbound ? 'text-gray-500' : 'text-white opacity-80'} ${
              isInbound ? 'text-left' : 'text-right'
            }`}
          >
            {parseServerTimeToLocal(messageDate.toISOString())}
          </div>
        </div>
      </div>
    );
  };

  return (
    <div>
      {/* 컨트롤 패널 */}
      <div className="flex justify-between items-center mb-6">
        <div className="flex items-center">
          <button
            className="px-4 py-2 mr-4 text-white rounded-md"
            style={{ backgroundColor: currentColor }}
            onClick={handleReset}
          >
            리셋
          </button>
        </div>
        
        <button
          className="px-4 py-2 text-white rounded-md"
          style={{ backgroundColor: currentColor }}
          onClick={handleExcelDownload}
        >
          엑셀 저장
        </button>
      </div>
      
      {/* 로딩 표시 */}
      {isLoading && (
        <div className="flex justify-center items-center h-64">
          <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2" style={{ borderColor: currentColor }}></div>
        </div>
      )}
      
      {/* 숨겨진 엑셀 내보내기용 그리드 */}
      <div style={{ display: 'none' }}>
        <GridComponent
          ref={excelGridRef}
          dataSource={filteredConversations}
          allowExcelExport={true}
        >
          <ColumnsDirective>
            <ColumnDirective field="phoneNumber" headerText="전화번호" width="150" />
            <ColumnDirective field="time" headerText="시간" width="200" />
            <ColumnDirective field="smsType" headerText="유형" width="100" />
            <ColumnDirective field="content" headerText="내용" width="400" />
          </ColumnsDirective>
          <Inject services={[Resize, Sort, Page, ExcelExport]} />
        </GridComponent>
      </div>
      
      {/* 메인 컨텐츠 영역 */}
      {!isLoading && (
        <div className="grid grid-cols-12 gap-4">
          {/* 왼쪽 패널: 사용자 목록 */}
          <div className="col-span-12 md:col-span-3">
            <div className="bg-white shadow-md rounded-lg p-4 h-[70vh] flex flex-col">
              <div className="mb-4">
                <h2 className="font-bold text-lg mb-2">사용자 목록</h2>
                <div className="relative">
                  <input 
                    type="text" 
                    placeholder="사용자 검색..."
                    className="w-full p-2 pl-8 border rounded-md"
                    value={userSearch}
                    onChange={(e) => setUserSearch(e.target.value)}
                  />
                  <span className="absolute left-2 top-2.5 text-gray-400">
                    {/* Search icon */}
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                    </svg>
                  </span>
                  {userSearch && (
                    <span 
                      className="absolute right-2 top-2.5 text-gray-400 cursor-pointer" 
                      onClick={() => setUserSearch('')}
                    >
                      {/* X icon */}
                      <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </span>
                  )}
                </div>
              </div>
              
              <div ref={userScrollContainerRef} className="flex-1 overflow-y-auto">
                {filteredUsers.length > 0 ? (
                  <div>
                    {filteredUsers.map(renderUserItem)}
                  </div>
                ) : (
                  <div className="p-4 text-center text-gray-500">
                    표시할 사용자가 없습니다.
                  </div>
                )}
              </div>
            </div>
          </div>
          
          {/* 중앙 패널: 전화번호 목록 */}
          <div className="col-span-12 md:col-span-3">
            <div className="bg-white shadow-md rounded-lg p-4 h-[70vh] flex flex-col">
              <div className="mb-4">
                <h2 className="font-bold text-lg mb-2">전화번호 목록</h2>
                <div className="relative">
                  <input 
                    type="text" 
                    placeholder="전화번호 검색..."
                    className="w-full p-2 pl-8 border rounded-md"
                    value={phoneSearch}
                    onChange={(e) => setPhoneSearch(e.target.value)}
                  />
                  <span className="absolute left-2 top-2.5 text-gray-400">
                    {/* Search icon */}
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                    </svg>
                  </span>
                  {phoneSearch && (
                    <span 
                      className="absolute right-2 top-2.5 text-gray-400 cursor-pointer" 
                      onClick={() => setPhoneSearch('')}
                    >
                      {/* X icon */}
                      <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </span>
                  )}
                </div>
              </div>
              
              <div ref={phoneScrollContainerRef} className="flex-1 overflow-y-auto">
                {filteredPhones.length > 0 ? (
                  <div>
                    {filteredPhones.map(renderPhoneItem)}
                  </div>
                ) : (
                  <div className="p-4 text-center text-gray-500">
                    표시할 전화번호가 없습니다.
                  </div>
                )}
              </div>
            </div>
          </div>
          
          {/* 오른쪽 패널: 대화 내역 */}
          <div className="col-span-12 md:col-span-6">
            <div className="bg-white shadow-md rounded-lg p-4 h-[70vh] flex flex-col">
              <div className="flex justify-between items-center mb-4">
                <h2 className="text-lg font-bold">
                  대화 내역
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
                    value={contentSearch}
                    onChange={(e) => setContentSearch(e.target.value)}
                  />
                  <span className="absolute left-2 top-2.5 text-gray-400">
                    {/* Search icon */}
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                    </svg>
                  </span>
                  {contentSearch && (
                    <span 
                      className="absolute right-2 top-2.5 text-gray-400 cursor-pointer" 
                      onClick={() => setContentSearch('')}
                    >
                      {/* X icon */}
                      <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </span>
                  )}
                </div>
              </div>
              
              <div className="flex-1 overflow-y-auto p-2">
                {selectedUser && selectedPhone ? (
                  filteredConversations.length > 0 ? (
                    <div>
                      {filteredConversations.map(renderMessageItem)}
                    </div>
                  ) : (
                    <div className="p-4 text-center text-gray-500">
                      대화 내역이 없습니다.
                    </div>
                  )
                ) : (
                  <div className="p-4 text-center text-gray-500">
                    사용자와 전화번호를 모두 선택하세요.
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default ThreePanelLayout;