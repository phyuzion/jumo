import { useCallback, useEffect, useMemo, useState } from 'react';
import { STORES } from '../../../utils/useIndexedDBCache';

/**
 * ThreePanelLayout의 상태/로직을 모은 커스텀 훅
 * - 데이터 로딩 (IndexedDB)
 * - 선택/활성화 상태 전파
 * - 검색/필터 상태
 * - 대화 내역 산출
 */
const usePanelState = (cache) => {
  const { getFromIndexedDB } = cache;

  // 데이터 상태
  const [usersData, setUsersData] = useState([]);
  const [phonesData, setPhonesData] = useState([]);
  const [smsLogsData, setSmsLogsData] = useState([]);

  // 선택/활성화 상태
  const [selectedUser, setSelectedUser] = useState(null);
  const [selectedPhone, setSelectedPhone] = useState(null);
  const [conversations, setConversations] = useState([]);
  const [userActiveState, setUserActiveState] = useState({});
  const [phoneActiveState, setPhoneActiveState] = useState({});

  // 검색 상태
  const [userSearch, setUserSearch] = useState('');
  const [phoneSearch, setPhoneSearch] = useState('');
  const [contentSearch, setContentSearch] = useState('');

  // 로딩
  const [isLoading, setIsLoading] = useState(true);

  // 데이터 로드
  useEffect(() => {
    const loadData = async () => {
      try {
        setIsLoading(true);
        // SMS 로그
        const smsLogs = await getFromIndexedDB(STORES.sms);
        setSmsLogsData(smsLogs || []);

        // 유저 (SMS와 매칭된 유저만)
        const users = await getFromIndexedDB(STORES.users);
        const uniqueUserIds = [...new Set((smsLogs || []).filter(log => log.userId).map(log => log.userId))];
        const matchingUsers = users.filter(user => uniqueUserIds.includes(user.id));
        setUsersData(matchingUsers);

        // 전화번호 (유니크)
        const uniquePhoneNumbers = [...new Set((smsLogs || []).map(log => log.phoneNumber))];
        setPhonesData(uniquePhoneNumbers);

        // 초기 활성화 상태 = 모두 비활성화
        const initialUserState = {};
        const initialPhoneState = {};
        matchingUsers.forEach(user => { initialUserState[user.id] = 'inactive'; });
        uniquePhoneNumbers.forEach(phone => { initialPhoneState[phone] = 'inactive'; });
        setUserActiveState(initialUserState);
        setPhoneActiveState(initialPhoneState);
      } catch (e) {
        console.error('데이터 로딩 오류:', e);
      } finally {
        setIsLoading(false);
      }
    };
    loadData();
  }, [getFromIndexedDB]);

  // 특정 유저-번호 대화
  const getConversationBetween = useCallback((userId, phoneNumber) => {
    return smsLogsData
      .filter(log => log.userId === userId && log.phoneNumber === phoneNumber)
      .sort((a, b) => new Date(a.time) - new Date(b.time));
  }, [smsLogsData]);

  // 유저 선택 (비활성/활성 공통)
  const handleUserSelect = useCallback((user) => {
    if (selectedUser && selectedUser.id === user.id) return;
    setUserSearch('');

    const userSmsLogs = smsLogsData.filter(log => log.userId === user.id);
    const relatedPhones = [...new Set(userSmsLogs.map(log => log.phoneNumber))];

    const newUserState = {};
    const newPhoneState = {};

    if (selectedPhone) {
      setSelectedUser(user);
      const conversation = getConversationBetween(user.id, selectedPhone);
      setConversations(conversation);

      const phoneSmslogs = smsLogsData.filter(log => log.phoneNumber === selectedPhone);
      const usersWithPhone = [...new Set(phoneSmslogs.filter(log => log.userId).map(log => log.userId))];

      usersData.forEach(u => {
        if (u.id === user.id) newUserState[u.id] = 'selected';
        else if (usersWithPhone.includes(u.id)) newUserState[u.id] = 'active';
        else newUserState[u.id] = 'inactive';
      });

      phonesData.forEach(phone => {
        if (phone === selectedPhone) newPhoneState[phone] = 'selected';
        else if (relatedPhones.includes(phone)) newPhoneState[phone] = 'active';
        else newPhoneState[phone] = 'inactive';
      });
    } else {
      setSelectedUser(user);
      setConversations([]);

      usersData.forEach(u => { newUserState[u.id] = 'inactive'; });
      newUserState[user.id] = 'selected';

      phonesData.forEach(phone => {
        newPhoneState[phone] = relatedPhones.includes(phone) ? 'active' : 'inactive';
      });
    }

    setUserActiveState(newUserState);
    setPhoneActiveState(newPhoneState);
  }, [getConversationBetween, phonesData, selectedPhone, selectedUser, smsLogsData, usersData]);

  // 전화번호 선택
  const handlePhoneSelect = useCallback((phone) => {
    if (selectedPhone === phone) return;
    setPhoneSearch('');

    if (phoneActiveState[phone] === 'inactive') {
      setSelectedUser(null);
      setSelectedPhone(phone);
      setConversations([]);

      const phoneSmsLogs = smsLogsData.filter(log => log.phoneNumber === phone);
      const relatedUserIds = [...new Set(phoneSmsLogs.filter(log => log.userId).map(log => log.userId))];

      const newUserState = {};
      const newPhoneState = {};

      usersData.forEach(user => { newUserState[user.id] = relatedUserIds.includes(user.id) ? 'active' : 'inactive'; });
      phonesData.forEach(p => { newPhoneState[p] = 'inactive'; });
      newPhoneState[phone] = 'selected';

      setUserActiveState(newUserState);
      setPhoneActiveState(newPhoneState);
      return;
    }

    setSelectedPhone(phone);

    if (selectedUser) {
      const conversation = getConversationBetween(selectedUser.id, phone);
      setConversations(conversation);

      const phoneSmslogs = smsLogsData.filter(log => log.phoneNumber === phone);
      const usersWithPhone = [...new Set(phoneSmslogs.filter(log => log.userId).map(log => log.userId))];

      const newUserState = { ...userActiveState };
      usersData.forEach(u => {
        if (u.id === selectedUser.id) newUserState[u.id] = 'selected';
        else if (usersWithPhone.includes(u.id)) newUserState[u.id] = 'active';
        else newUserState[u.id] = 'inactive';
      });
      setUserActiveState(newUserState);

      const newPhoneState = { ...phoneActiveState };
      Object.keys(newPhoneState).forEach(p => {
        if (p === phone) newPhoneState[p] = 'selected';
        else if (newPhoneState[p] === 'selected') newPhoneState[p] = 'active';
      });
      setPhoneActiveState(newPhoneState);
    } else {
      const phoneSmsLogs = smsLogsData.filter(log => log.phoneNumber === phone);
      const relatedUserIds = [...new Set(phoneSmsLogs.filter(log => log.userId).map(log => log.userId))];

      const newUserState = {};
      const newPhoneState = {};

      usersData.forEach(user => { newUserState[user.id] = relatedUserIds.includes(user.id) ? 'active' : 'inactive'; });
      phonesData.forEach(p => { newPhoneState[p] = 'inactive'; });
      newPhoneState[phone] = 'selected';

      setUserActiveState(newUserState);
      setPhoneActiveState(newPhoneState);
      setConversations([]);
    }
  }, [phoneActiveState, phonesData, selectedPhone, selectedUser, smsLogsData, userActiveState, usersData, getConversationBetween]);

  // 비활성 유저 선택
  const handleInactiveUserSelect = useCallback((user) => {
    setUserSearch('');
    setPhoneSearch('');
    setContentSearch('');

    setSelectedUser(user);
    setSelectedPhone(null);
    setConversations([]);

    const userSmsLogs = smsLogsData.filter(log => log.userId === user.id);
    const relatedPhones = [...new Set(userSmsLogs.map(log => log.phoneNumber))];

    const newUserState = {};
    const newPhoneState = {};
    usersData.forEach(u => { newUserState[u.id] = 'inactive'; });
    newUserState[user.id] = 'selected';
    phonesData.forEach(phone => { newPhoneState[phone] = relatedPhones.includes(phone) ? 'active' : 'inactive'; });
    setUserActiveState(newUserState);
    setPhoneActiveState(newPhoneState);
  }, [phonesData, smsLogsData, usersData]);

  // 리셋
  const handleReset = useCallback(() => {
    setSelectedUser(null);
    setSelectedPhone(null);
    setConversations([]);
    setUserSearch('');
    setPhoneSearch('');
    setContentSearch('');

    const resetUserState = {};
    const resetPhoneState = {};
    usersData.forEach(user => { resetUserState[user.id] = 'inactive'; });
    phonesData.forEach(phone => { resetPhoneState[phone] = 'inactive'; });
    setUserActiveState(resetUserState);
    setPhoneActiveState(resetPhoneState);
  }, [phonesData, usersData]);

  // 필터링 결과
  const filteredUsers = useMemo(() => {
    let result = [...usersData];
    if (userSearch) {
      const search = userSearch.toLowerCase();
      result = result.filter(user => (
        (user.name && user.name.toLowerCase().includes(search)) ||
        (user.phoneNumber && user.phoneNumber.includes(search)) ||
        (user.loginId && user.loginId.toLowerCase().includes(search))
      ));
    }
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
  }, [userActiveState, userSearch, usersData]);

  const filteredPhones = useMemo(() => {
    let result = [...phonesData];
    if (phoneSearch) result = result.filter(phone => phone.includes(phoneSearch));
    result.sort((a, b) => {
      const stateA = phoneActiveState[a] || 'inactive';
      const stateB = phoneActiveState[b] || 'inactive';
      if (stateA !== 'inactive' && stateB === 'inactive') return -1;
      if (stateA === 'inactive' && stateB !== 'inactive') return 1;
      return 0;
    });
    return result;
  }, [phoneActiveState, phoneSearch, phonesData]);

  const filteredConversations = useMemo(() => {
    if (!conversations.length) return [];
    return conversations.filter(conv => {
      if (!contentSearch) return true;
      return conv.content && conv.content.includes(contentSearch);
    });
  }, [conversations, contentSearch]);

  return {
    // 데이터
    usersData,
    phonesData,
    smsLogsData,
    isLoading,

    // 선택 상태
    selectedUser,
    selectedPhone,
    conversations,
    userActiveState,
    phoneActiveState,

    // 검색
    userSearch,
    setUserSearch,
    phoneSearch,
    setPhoneSearch,
    contentSearch,
    setContentSearch,

    // 핸들러
    handleUserSelect,
    handlePhoneSelect,
    handleInactiveUserSelect,
    handleReset,
    getConversationBetween,

    // 필터 결과
    filteredUsers,
    filteredPhones,
    filteredConversations,
  };
};

export default usePanelState;


