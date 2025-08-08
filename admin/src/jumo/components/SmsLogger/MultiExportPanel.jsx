import React, { useEffect, useMemo, useState } from 'react';
import { exportUserConversations, exportPhoneConversations, mapConversationToRows, sanitizeString } from './utils/ExcelExporter';

const MultiExportPanel = ({ cache, currentColor }) => {
  const { getFromIndexedDB } = cache;

  // 데이터
  const [usersData, setUsersData] = useState([]);
  const [phonesData, setPhonesData] = useState([]);
  const [smsLogsData, setSmsLogsData] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  // 검색
  const [userSearch, setUserSearch] = useState('');
  const [phoneSearch, setPhoneSearch] = useState('');

  // 선택 (순서 유지)
  const [selectedUserIds, setSelectedUserIds] = useState([]);
  const [selectedPhones, setSelectedPhones] = useState([]);

  // 진행률
  const [progressText, setProgressText] = useState('');

  useEffect(() => {
    const load = async () => {
      try {
        setIsLoading(true);
        const [users, sms] = await Promise.all([
          getFromIndexedDB('users'),
          getFromIndexedDB('smsLogs'),
        ]);

        const uniqueUserIds = [...new Set((sms || []).filter(l => l.userId).map(l => l.userId))];
        const matchingUsers = (users || []).filter(u => uniqueUserIds.includes(u.id));
        setUsersData(matchingUsers);

        const uniquePhones = [...new Set((sms || []).map(l => l.phoneNumber))];
        setPhonesData(uniquePhones);

        setSmsLogsData(sms || []);
      } finally {
        setIsLoading(false);
      }
    };
    load();
  }, [getFromIndexedDB]);

  const filteredUsers = useMemo(() => {
    let list = [...usersData];
    if (userSearch) {
      const s = userSearch.toLowerCase();
      list = list.filter(u =>
        (u.name && u.name.toLowerCase().includes(s)) ||
        (u.phoneNumber && u.phoneNumber.includes(userSearch)) ||
        (u.loginId && u.loginId.toLowerCase().includes(s))
      );
    }
    // 상단 고정: 선택된 것들 먼저(선택 순서)
    const selectedSet = new Set(selectedUserIds);
    const selectedTop = selectedUserIds.map(id => list.find(u => u.id === id)).filter(Boolean);
    const rest = list.filter(u => !selectedSet.has(u.id));
    return [...selectedTop, ...rest];
  }, [usersData, userSearch, selectedUserIds]);

  const filteredPhones = useMemo(() => {
    let list = [...phonesData];
    if (phoneSearch) list = list.filter(p => p.includes(phoneSearch));
    const selectedSet = new Set(selectedPhones);
    const selectedTop = selectedPhones.filter(p => list.includes(p));
    const rest = list.filter(p => !selectedSet.has(p));
    return [...selectedTop, ...rest];
  }, [phonesData, phoneSearch, selectedPhones]);

  const toggleSelectUser = (id) => {
    setSelectedUserIds(prev => prev.includes(id) ? prev.filter(x => x !== id) : [...prev, id]);
  };

  const toggleSelectPhone = (phone) => {
    setSelectedPhones(prev => prev.includes(phone) ? prev.filter(x => x !== phone) : [...prev, phone]);
  };

  const handleBulkUserExport = async () => {
    if (!selectedUserIds.length) return;
    try {
      for (let i = 0; i < selectedUserIds.length; i++) {
        const userId = selectedUserIds[i];
        const user = usersData.find(u => u.id === userId);
        if (!user) continue;

        setProgressText(`${i + 1}/${selectedUserIds.length} 저장 중… (${sanitizeString(user.name || user.loginId || '')})`);

        const logs = smsLogsData.filter(l => l.userId === userId);
        const uniquePhones = [...new Set(logs.map(l => l.phoneNumber))];
        const conversationsPerPhone = uniquePhones.map(phone => mapConversationToRows(
          logs.filter(l => l.phoneNumber === phone).sort((a, b) => new Date(a.time) - new Date(b.time))
        ));
        const phoneSummaryData = uniquePhones.map((phone, idx) => ({ phoneNumber: phone, messageCount: conversationsPerPhone[idx].length }));

        await Promise.resolve(exportUserConversations({
          selectedUserName: user.name || user.loginId,
          selectedUserPhone: user.phoneNumber || '',
          phoneNumbers: uniquePhones,
          phoneSummaryData,
          conversationsPerPhone,
        }));

        // 약간의 텀으로 UI 여유
        await new Promise(res => setTimeout(res, 80));
      }
      setProgressText('완료');
      alert('다중 사용자 대화내역 저장 완료');
    } catch (e) {
      console.error(e);
      alert('저장 중 오류가 발생했습니다.');
    } finally {
      setTimeout(() => setProgressText(''), 500);
    }
  };

  const handleBulkPhoneExport = async () => {
    if (!selectedPhones.length) return;
    try {
      for (let i = 0; i < selectedPhones.length; i++) {
        const phone = selectedPhones[i];
        setProgressText(`${i + 1}/${selectedPhones.length} 저장 중… (${phone})`);

        const phoneLogs = smsLogsData.filter(l => l.phoneNumber === phone);
        const userIds = [...new Set(phoneLogs.filter(l => l.userId).map(l => l.userId))];
        const usersWithPhone = usersData.filter(u => userIds.includes(u.id)).map(u => ({ id: u.id, name: u.name || '이름 없음', phoneNumber: u.phoneNumber || '' }));
        const userSummaryData = usersWithPhone.map(u => ({ name: u.name, phoneNumber: u.phoneNumber, messageCount: phoneLogs.filter(l => l.userId === u.id).length }));
        const conversationsPerUser = usersWithPhone.map(u => mapConversationToRows(
          phoneLogs.filter(l => l.userId === u.id).sort((a, b) => new Date(a.time) - new Date(b.time))
        ));

        await Promise.resolve(exportPhoneConversations({
          selectedPhone: phone,
          usersWithPhone,
          userSummaryData,
          conversationsPerUser,
        }));

        await new Promise(res => setTimeout(res, 80));
      }
      setProgressText('완료');
      alert('다중 전화번호 대화내역 저장 완료');
    } catch (e) {
      console.error(e);
      alert('저장 중 오류가 발생했습니다.');
    } finally {
      setTimeout(() => setProgressText(''), 500);
    }
  };

  return (
    <div>
      {/* 컨트롤 바 */}
      <div className="flex items-center justify-end mb-4 gap-2">
        <button className="px-4 py-2 text-white rounded-md" style={{ backgroundColor: currentColor }} disabled={!selectedUserIds.length} onClick={handleBulkUserExport}>
          다중 사용자 대화내역 저장
        </button>
        <button className="px-4 py-2 text-white rounded-md" style={{ backgroundColor: currentColor }} disabled={!selectedPhones.length} onClick={handleBulkPhoneExport}>
          다중 전화번호 대화내역 저장
        </button>
      </div>

      {progressText && (
        <div className="mb-2 text-sm text-gray-600">{progressText}</div>
      )}

      {/* 본문 */}
      {isLoading ? (
        <div className="flex justify-center items-center h-64">
          <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2" style={{ borderColor: currentColor }}></div>
        </div>
      ) : (
        <div className="grid grid-cols-12 gap-4">
          {/* 좌: 사용자 */}
          <div className="col-span-12 md:col-span-6">
            <div className="bg-white shadow-md rounded-lg p-4 h-[70vh] flex flex-col">
              <div className="mb-2 flex items-center justify-between">
                <h2 className="font-bold text-lg">
                  사용자 <span className="text-sm font-normal text-gray-500">( 총 {usersData.length}명, 최대 동시 100명 다운로드 가능 )</span>
                </h2>
                <span className="text-sm text-gray-500">선택됨: {selectedUserIds.length}</span>
              </div>
              <div className="mb-3 relative">
                <input className="w-full p-2 pl-8 border rounded-md" placeholder="사용자 검색…" value={userSearch} onChange={(e) => setUserSearch(e.target.value)} />
                <span className="absolute left-2 top-2.5 text-gray-400">
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                  </svg>
                </span>
              </div>
              <div className="flex-1 overflow-y-auto">
                {filteredUsers.map(user => (
                  <label key={user.id} className="flex items-center gap-2 p-2 mb-1 border rounded cursor-pointer hover:bg-gray-50">
                    <input type="checkbox" checked={selectedUserIds.includes(user.id)} onChange={() => toggleSelectUser(user.id)} />
                    <div className="flex flex-col">
                      <span className="font-medium">{user.name || '이름 없음'}</span>
                      <span className="text-sm text-gray-600">{user.phoneNumber || user.loginId}</span>
                    </div>
                  </label>
                ))}
              </div>
            </div>
          </div>

          {/* 우: 전화번호 */}
          <div className="col-span-12 md:col-span-6">
            <div className="bg-white shadow-md rounded-lg p-4 h-[70vh] flex flex-col">
              <div className="mb-2 flex items-center justify-between">
                <h2 className="font-bold text-lg">
                  전화번호 <span className="text-sm font-normal text-gray-500">( 총 {phonesData.length}명, 최대 동시 100명 다운로드 가능 )</span>
                </h2>
                <span className="text-sm text-gray-500">선택됨: {selectedPhones.length}</span>
              </div>
              <div className="mb-3 relative">
                <input className="w-full p-2 pl-8 border rounded-md" placeholder="전화번호 검색…" value={phoneSearch} onChange={(e) => setPhoneSearch(e.target.value)} />
                <span className="absolute left-2 top-2.5 text-gray-400">
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                  </svg>
                </span>
              </div>
              <div className="flex-1 overflow-y-auto">
                {filteredPhones.map(phone => (
                  <label key={phone} className="flex items-center gap-2 p-2 mb-1 border rounded cursor-pointer hover:bg-gray-50">
                    <input type="checkbox" checked={selectedPhones.includes(phone)} onChange={() => toggleSelectPhone(phone)} />
                    <div className="font-medium">{phone}</div>
                  </label>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default MultiExportPanel;


