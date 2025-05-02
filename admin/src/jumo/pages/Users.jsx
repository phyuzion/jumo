import React, { useState, useEffect, useRef } from "react";
import { useQuery, useMutation, useLazyQuery } from "@apollo/client";
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

import {
  GET_ALL_USERS,
  GET_USER_RECORDS,
  GET_USER_CALL_LOG, // 통화로그
  GET_USER_SMS_LOG,  // 문자로그
  GET_ALL_GRADES,
  GET_ALL_REGIONS,
  GET_USER_TYPES,
} from "../graphql/queries";
import {
  CREATE_USER,
  UPDATE_USER,
  RESET_USER_PASSWORD,
  RESET_REQUESTED_PASSWORD
} from "../graphql/mutations";

import { Header } from "../components";
import { localTimeToUTCString, parseServerTimeToLocal } from '../../utils/dateUtils';

const PAGE_SIZE = 10; // syncfusion paging size(예시)

/** 날짜 포맷 (로컬 표시) */
function formatLocalDate(str) {
  if (!str) return '';
  const d = new Date(parseInt(str));
  if (isNaN(d.getTime())) return str;
  return d.toLocaleString(); 
}

const Users = () => {
  const gridRef = useRef(null);

  // (1) getAllUsers
  const { data, loading, error, refetch } = useQuery(GET_ALL_USERS, {
    fetchPolicy: 'network-only',
  });

  // (2) 등급/지역 목록
  const { data: gradesData } = useQuery(GET_ALL_GRADES);
  const { data: regionsData } = useQuery(GET_ALL_REGIONS);

  // (3) create / update / reset
  const [createUserMutation]         = useMutation(CREATE_USER);
  const [updateUserMutation]         = useMutation(UPDATE_USER);
  const [resetUserPasswordMutation]  = useMutation(RESET_USER_PASSWORD);
  const [resetRequestedPasswordMutation] = useMutation(RESET_REQUESTED_PASSWORD);

  // (4) 전화번호부 기록 (lazy)
  const [getUserRecordsLazy, { data: recordsData }] = useLazyQuery(GET_USER_RECORDS, {
    fetchPolicy: 'no-cache',
    notifyOnNetworkStatusChange: true,
  });

  // (5) 통화/문자 로그 (lazy)
  const [getUserCallLogLazy, { data: callLogData }] = useLazyQuery(GET_USER_CALL_LOG, {
    fetchPolicy: 'no-cache',
    notifyOnNetworkStatusChange: true,
  });
  const [getUserSMSLogLazy, { data: smsLogData }]   = useLazyQuery(GET_USER_SMS_LOG, {
    fetchPolicy: 'no-cache',
    notifyOnNetworkStatusChange: true,
  });

  // (6) 유저 타입 목록
  const { data: userTypesData } = useQuery(GET_USER_TYPES);
  const [userTypes, setUserTypes] = useState([]);

  // ========== State ==========
  const [users, setUsers] = useState([]);
  const [grades, setGrades] = useState([]);
  const [regions, setRegions] = useState([]);

  // 생성/수정 모달 표시 여부
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [showEditModal,   setShowEditModal]   = useState(false);
  const [editUser,        setEditUser]        = useState(null);

  // 기록 모달
  const [showRecordsModal, setShowRecordsModal] = useState(false);
  const [recordUser,       setRecordUser]       = useState(null);

  // 탭 구분: phoneRecords | callLogs | smsLogs
  const [selectedTab,  setSelectedTab]  = useState('phoneRecords');
  const [phoneRecords, setPhoneRecords] = useState([]);
  const [callLogs,     setCallLogs]     = useState([]);
  const [smsLogs,      setSmsLogs]      = useState([]);

  // 생성 폼
  const [formLoginId,  setFormLoginId]  = useState('');
  const [formPhone,    setFormPhone]    = useState('');
  const [formName,     setFormName]     = useState('');
  const [formUserType, setFormUserType] = useState('일반');
  const [formRegion,   setFormRegion]   = useState('');
  const [formGrade,    setFormGrade]    = useState('');

  // 수정 폼
  const [editLoginId,      setEditLoginId]      = useState('');
  const [editPhone,        setEditPhone]        = useState('');
  const [editName,         setEditName]         = useState('');
  const [editUserType,     setEditUserType]     = useState('일반');
  const [editValidUntil,   setEditValidUntil]   = useState('');
  const [editRegion,       setEditRegion]       = useState('');
  const [editGrade,        setEditGrade]        = useState('');

  // <<< 비밀번호 변경 요청 모달 관련 State 추가 >>>
  const [showResetRequestedModal, setShowResetRequestedModal] = useState(false);
  const [resetRequestedUser, setResetRequestedUser] = useState(null);
  const [newPasswordInput, setNewPasswordInput] = useState('');

  // ================= useEffect =================

  // getAllUsers -> users
  useEffect(() => {
    if (data?.getAllUsers) {
      setUsers(data.getAllUsers);
    }
  }, [data]);

  // 등급/지역 데이터 설정
  useEffect(() => {
    if (gradesData?.getGrades) {
      // limit 값이 작은 순서대로 정렬
      const sortedGrades = [...gradesData.getGrades].sort((a, b) => a.limit - b.limit);
      setGrades(sortedGrades);
      // 첫 번째 등급을 기본값으로 설정
      if (sortedGrades.length > 0) {
        setFormGrade(sortedGrades[0].name);
        setEditGrade(sortedGrades[0].name);
      }
    }
    if (regionsData?.getRegions) {
      setRegions(regionsData.getRegions);
      // 첫 번째 지역을 기본값으로 설정
      if (regionsData.getRegions.length > 0) {
        setFormRegion(regionsData.getRegions[0].name);
        setEditRegion(regionsData.getRegions[0].name);
      }
    }
  }, [gradesData, regionsData]);

  // 전화번호부 기록
  useEffect(() => {
    if (recordsData?.getUserRecords) {
      const { user, records } = recordsData.getUserRecords;
      setRecordUser(user);
      setPhoneRecords(records);
      // 기록 모달 열기 + 탭 기본값 = 'phoneRecords'
      setSelectedTab('phoneRecords');
      setShowRecordsModal(true);
    }
  }, [recordsData]);

  // 통화로그
  useEffect(() => {
    if (callLogData?.getUserCallLog) {
      setCallLogs(callLogData.getUserCallLog);
    }
  }, [callLogData]);

  // 문자로그
  useEffect(() => {
    if (smsLogData?.getUserSMSLog) {
      setSmsLogs(smsLogData.getUserSMSLog);
    }
  }, [smsLogData]);

  // 유저 타입 데이터 설정
  useEffect(() => {
    if (userTypesData?.getUserTypes) {
      setUserTypes(userTypesData.getUserTypes);
      // 첫 번째 유저 타입을 기본값으로 설정
      if (userTypesData.getUserTypes.length > 0) {
        setFormUserType(userTypesData.getUserTypes[0].name);
        setEditUserType(userTypesData.getUserTypes[0].name);
      }
    }
  }, [userTypesData]);

  // users 바뀌면 syncfusion grid 갱신
  useEffect(() => {
    if (gridRef.current) {
      gridRef.current.dataSource = users;
      gridRef.current.refresh();
    }
  }, [users]);

  // ============= COLUMN HELPER =============
  // 유효기간
  const validUntilAccessor = (field, data) => {
    if (!data.validUntil) return '';
    return parseServerTimeToLocal(data.validUntil);
  };

  // 시간 변환 헬퍼
  const timeAccessor = (field, data) => {
    if (!data[field]) return '';
    return parseServerTimeToLocal(data[field]);
  };

  // ============= CREATE =============
  const handleCreate = () => {
    setFormLoginId('');
    setFormPhone('');
    setFormName('');
    // 첫 번째 값으로 초기화
    if (userTypes.length > 0) {
      setFormUserType(userTypes[0].name);
    }
    if (regions.length > 0) {
      setFormRegion(regions[0].name);
    }
    if (grades.length > 0) {
      setFormGrade(grades[0].name);
    }
    setShowCreateModal(true);
  };

  const handleCreateSubmit = async () => {
    try {
      const res = await createUserMutation({
        variables: {
          loginId: formLoginId,
          phoneNumber: formPhone,
          name: formName,
          userType: formUserType,
          region: formRegion,
          grade: formGrade,
        },
      });
      alert(`임시비번: ${res.data?.createUser?.tempPassword}`);

      setShowCreateModal(false);
      handleRefresh();
    } catch (err) {
      alert(err.message);
    }
  };

  // ============= REFRESH =============
  const handleRefresh = async () => {
    try {
      await refetch();
    } catch (err) {
      alert(err.message);
    }
  };

  // ============= EDIT =============
  const handleEditClick = (u) => {
    setEditUser(u);
    setEditLoginId(u.loginId);
    setEditPhone(u.phoneNumber);
    setEditName(u.name);
    setEditUserType(u.userType);
    
    // UTC -> 로컬 시간으로 변환하여 표시
    if (u.validUntil) {
      const d = new Date(parseInt(u.validUntil));
      if (!isNaN(d.getTime())) {
        const year = d.getFullYear();
        const month = String(d.getMonth() + 1).padStart(2, '0');
        const day = String(d.getDate()).padStart(2, '0');
        setEditValidUntil(`${year}-${month}-${day}`);
      } else {
        setEditValidUntil('');
      }
    } else {
      setEditValidUntil('');
    }
    
    setEditRegion(u.region);
    setEditGrade(u.grade);
    setShowEditModal(true);
  };

  const handleEditSubmit = async () => {
    try {
      // 로컬 시간을 UTC로 변환
      let validUntilUTC = null;
      if (editValidUntil) {
        // 입력된 날짜의 시작 시간(00:00:00)을 UTC로 변환
        const localDate = new Date(editValidUntil + 'T00:00:00');
        validUntilUTC = localTimeToUTCString(localDate);
      }

      await updateUserMutation({
        variables: {
          userId: editUser.id,
          loginId: editLoginId,
          phoneNumber: editPhone,
          name: editName,
          userType: editUserType,
          validUntil: validUntilUTC,
          region: editRegion,
          grade: editGrade,
        },
      });
      alert('수정 완료');
      setShowEditModal(false);
      handleRefresh();
    } catch (err) {
      alert(err.message);
    }
  };

  // ============= RESET PASSWORD =============
  const handleResetPassword = async (u) => {
    try {
      const res = await resetUserPasswordMutation({ variables: { userId: u.id } });
      const newPass = res.data?.resetUserPassword;
      alert(`임시비번: ${newPass}`);
    } catch (err) {
      alert(err.message);
    }
  };

  // ============= RESET REQUESTED PASSWORD (비번 변경) =============
  const handleResetRequestedClick = (u) => {
    setResetRequestedUser(u);
    setNewPasswordInput(''); // 입력 필드 초기화
    setShowResetRequestedModal(true);
  };

  const handleResetRequestedSubmit = async () => {
    if (!resetRequestedUser || !newPasswordInput) {
      alert('새 비밀번호를 입력해주세요.');
      return;
    }
    if (newPasswordInput.length < 4) {
      alert('새 비밀번호는 4자 이상이어야 합니다.');
      return;
    }

    try {
      await resetRequestedPasswordMutation({
        variables: {
          userId: resetRequestedUser.id,
          newPassword: newPasswordInput,
        },
      });
      alert('비밀번호 변경 완료');
      setShowResetRequestedModal(false);
      setResetRequestedUser(null); // 상태 초기화
    } catch (err) {
      alert(`비밀번호 변경 실패: ${err.message}`);
    }
  };

  // ============= RECORDS, CALL LOG, SMS LOG ============
  // 1) 전화번호부 기록 버튼
  const handleRecordsClick = async (u) => {
    try {
      await getUserRecordsLazy({ variables: { userId: u.id, _ts: Date.now() } });
    } catch (err) {
      alert(err.message);
    }
  };

  // 2) 탭 전환
  const handleTabSelect = async (tab) => {
    setSelectedTab(tab);
    if (!recordUser) return;
    const uid = recordUser.id;

    if (tab === 'callLogs') {
      // 통화로그 조회
      try {
        await getUserCallLogLazy({ variables: { userId: uid, _ts: Date.now() } });
      } catch (err) {
        alert(err.message);
      }
    } else if (tab === 'smsLogs') {
      // 문자로그 조회
      try {
        await getUserSMSLogLazy({ variables: { userId: uid, _ts: Date.now() } });
      } catch (err) {
        alert(err.message);
      }
    }
    // phoneRecords 탭은 이미 getUserRecords로 가져왔음
  };

  // ============= SYNCFUSION HANDLERS (옵션) =============
  const handleActionBegin = (args) => {
    // paging, sorting 등 확장 시 필요
  };

  // ============= RENDER =============
  return (
    <div className="m-2 md:m-2 p-2 md:p-5 bg-white rounded-2xl shadow-xl">
      <Header category="Page" title="유저 목록" />

      <div className="flex gap-2 mb-4">
        <button
          onClick={handleCreate}
          className="bg-blue-500 text-white px-3 py-1 rounded"
        >
          유저 생성
        </button>
        <button
          onClick={handleRefresh}
          className="bg-green-500 text-white px-3 py-1 rounded"
        >
          새로고침
        </button>
      </div>

      {loading && <p>Loading...</p>}
      {error && <p className="text-red-500">{error.message}</p>}

      {!loading && !error && (
        <GridComponent
          ref={gridRef}
          dataSource={users}
          enableHover={true}
          allowPaging={true}
          pageSettings={{ pageSize: PAGE_SIZE }}
          toolbar={['Search']}
          actionBegin={handleActionBegin}
          allowSorting={true}
        >
          <ColumnsDirective>
            <ColumnDirective field="loginId"     headerText="아이디"    width="90" />
            <ColumnDirective field="name"        headerText="상호"      width="120" />
            <ColumnDirective field="phoneNumber" headerText="번호"      width="110" />
            <ColumnDirective field="userType"     headerText="타입"      width="60"  textAlign="Center" />
            <ColumnDirective field="region"      headerText="지역"      width="80"  textAlign="Center" />
            <ColumnDirective field="grade"       headerText="등급"      width="80"  textAlign="Center" />
            <ColumnDirective
              field="validUntil"
              headerText="유효기간"
              width="90"
              textAlign="Center"
              valueAccessor={validUntilAccessor}
            />
            {/* Edit */}
            <ColumnDirective
              headerText="Edit"
              width="80"
              textAlign="Center"
              template={(u) => (
                <button
                  className="bg-orange-500 text-white px-2 py-1 rounded"
                  onClick={() => handleEditClick(u)}
                >
                  수정
                </button>
              )}
            />
            {/* Reset PW */}
            <ColumnDirective
              headerText="Reset"
              width="70"
              textAlign="Center"
              template={(u) => (
                <button
                  className="bg-red-500 text-white px-2 py-1 rounded"
                  onClick={() => handleResetPassword(u)}
                >
                  PW
                </button>
              )}
            />
            {/* <<< 비번 변경 버튼 추가 시작 >>> */}
            <ColumnDirective
              headerText="비번변경"
              width="70"
              textAlign="Center"
              template={(u) => (
                <button
                  className="bg-teal-500 text-white px-2 py-1 rounded" // 색상 변경 (예: teal)
                  onClick={() => handleResetRequestedClick(u)}
                >
                  비번변경
                </button>
              )}
            />
            {/* <<< 비번 변경 버튼 추가 끝 >>> */}
            {/* Records */}
            <ColumnDirective
              headerText="기록"
              width="70"
              textAlign="Center"
              template={(u) => (
                <button
                  className="bg-purple-500 text-white px-2 py-1 rounded"
                  onClick={() => handleRecordsClick(u)}
                >
                  기록
                </button>
              )}
            />
          </ColumnsDirective>
          <Inject services={[Resize, Sort, Filter, Page, Toolbar, Search]} />
        </GridComponent>
      )}

      {/* CREATE MODAL */}
      {showCreateModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex justify-center items-center">
          <div className="bg-white p-4 w-80 rounded shadow">
            <h2 className="text-xl font-bold mb-2">유저 생성</h2>
            <div className="flex flex-col gap-2">
              <input
                placeholder="아이디"
                value={formLoginId}
                onChange={(e) => setFormLoginId(e.target.value)}
                className="border p-1"
              />
              <input
                placeholder="전화번호"
                value={formPhone}
                onChange={(e) => setFormPhone(e.target.value)}
                className="border p-1"
              />
              <input
                placeholder="상호"
                value={formName}
                onChange={(e) => setFormName(e.target.value)}
                className="border p-1"
              />
              <select
                value={formUserType}
                onChange={(e) => setFormUserType(e.target.value)}
                className="border p-1"
              >
                {userTypes.map((ut) => (
                  <option key={ut.name} value={ut.name}>{ut.name}</option>
                ))}
              </select>
              <select
                value={formRegion}
                onChange={(e) => setFormRegion(e.target.value)}
                className="border p-1"
              >
                {regions.map((region) => (
                  <option key={region.name} value={region.name}>
                    {region.name}
                  </option>
                ))}
              </select>
              <select
                value={formGrade}
                onChange={(e) => setFormGrade(e.target.value)}
                className="border p-1"
              >
                {grades.map((grade) => (
                  <option key={grade.name} value={grade.name}>
                    {grade.name} (제한: {grade.limit}회)
                  </option>
                ))}
              </select>
            </div>
            <div className="mt-4 flex gap-2">
              <button
                className="bg-blue-500 text-white px-3 py-1 rounded"
                onClick={handleCreateSubmit}
              >
                생성
              </button>
              <button
                className="bg-gray-300 px-3 py-1 rounded"
                onClick={() => setShowCreateModal(false)}
              >
                닫기
              </button>
            </div>
          </div>
        </div>
      )}

      {/* EDIT MODAL */}
      {showEditModal && editUser && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex justify-center items-center">
          <div className="bg-white p-4 w-80 rounded shadow">
            <h2 className="text-xl font-bold mb-2">유저 수정</h2>
            <p className="mb-2">UserID: {editUser.loginId}</p>
            <div className="flex flex-col gap-2">
              <input
                placeholder="전화번호"
                value={editPhone}
                onChange={(e) => setEditPhone(e.target.value)}
                className="border p-1"
              />
              <input
                placeholder="상호"
                value={editName}
                onChange={(e) => setEditName(e.target.value)}
                className="border p-1"
              />
              <select
                value={editUserType}
                onChange={(e) => setEditUserType(e.target.value)}
                className="border p-1"
              >
                {userTypes.map((ut) => (
                  <option key={ut.name} value={ut.name}>{ut.name}</option>
                ))}
              </select>
              <select
                value={editRegion}
                onChange={(e) => setEditRegion(e.target.value)}
                className="border p-1"
              >
                {regions.map((region) => (
                  <option key={region.name} value={region.name}>
                    {region.name}
                  </option>
                ))}
              </select>
              <select
                value={editGrade}
                onChange={(e) => setEditGrade(e.target.value)}
                className="border p-1"
              >
                {grades.map((grade) => (
                  <option key={grade.name} value={grade.name}>
                    {grade.name} (제한: {grade.limit}회)
                  </option>
                ))}
              </select>
              <div>
                <label className="block text-sm text-gray-600 mb-1">유효기간 (KST)</label>
                <input
                  type="date"
                  value={editValidUntil}
                  onChange={(e) => setEditValidUntil(e.target.value)}
                  className="border p-1 w-full"
                />
                <small className="text-gray-500">
                  선택한 날짜의 00:00:00 KST가 서버에 저장됩니다.
                </small>
              </div>
            </div>
            <div className="mt-4 flex gap-2">
              <button
                className="bg-orange-500 text-white px-3 py-1 rounded"
                onClick={handleEditSubmit}
              >
                수정
              </button>
              <button
                className="bg-gray-300 px-3 py-1 rounded"
                onClick={() => {
                  setShowEditModal(false);
                  setEditUser(null);
                }}
              >
                닫기
              </button>
            </div>
          </div>
        </div>
      )}

      {/* <<< 비밀번호 변경 요청 모달 추가 시작 >>> */}
      {showResetRequestedModal && resetRequestedUser && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex justify-center items-center">
          <div className="bg-white p-4 w-80 rounded shadow">
            <h2 className="text-xl font-bold mb-2">비밀번호 변경</h2>
            <p className="mb-2">UserID: {resetRequestedUser.loginId}</p>
            <div className="flex flex-col gap-2">
              <input
                type="text" // 비밀번호지만 확인 위해 text로 둘 수도 있음
                placeholder="새 비밀번호 (4자 이상)"
                value={newPasswordInput}
                onChange={(e) => setNewPasswordInput(e.target.value)}
                className="border p-1"
              />
            </div>
            <div className="mt-4 flex gap-2">
              <button
                className="bg-teal-500 text-white px-3 py-1 rounded"
                onClick={handleResetRequestedSubmit}
              >
                비번변경
              </button>
              <button
                className="bg-gray-300 px-3 py-1 rounded"
                onClick={() => {
                  setShowResetRequestedModal(false);
                  setResetRequestedUser(null);
                }}
              >
                취소
              </button>
            </div>
          </div>
        </div>
      )}
      {/* <<< 비밀번호 변경 요청 모달 추가 끝 >>> */}

      {/* RECORDS MODAL (전화번호부 + 통화로그 + 문자로그 탭) */}
      {showRecordsModal && recordUser && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex justify-center items-center">
          <div className="bg-white rounded shadow w-[90vw] h-[90vh] flex flex-col">
            {/* 헤더 영역 - 고정 */}
            <div className="flex justify-between items-center p-4 border-b">
              <div>
                <h2 className="text-xl font-bold">유저 상세</h2>
                <p className="text-sm text-gray-600">
                  {recordUser.loginId} ({recordUser.name})
                </p>
              </div>
              <button
                className="bg-gray-300 px-3 py-1 rounded hover:bg-gray-400"
                onClick={() => {
                  setShowRecordsModal(false);
                  setRecordUser(null);
                  setPhoneRecords([]);
                  setCallLogs([]);
                  setSmsLogs([]);
                  setSelectedTab('phoneRecords');
                }}
              >
                닫기
              </button>
            </div>

            {/* 탭 영역 - 고정 */}
            <div className="flex gap-2 p-4 border-b">
              <button
                className={`px-4 py-2 rounded ${
                  selectedTab === 'phoneRecords' ? 'bg-blue-500 text-white' : 'bg-gray-200'
                }`}
                onClick={() => handleTabSelect('phoneRecords')}
              >
                번호부
              </button>
              <button
                className={`px-4 py-2 rounded ${
                  selectedTab === 'callLogs' ? 'bg-blue-500 text-white' : 'bg-gray-200'
                }`}
                onClick={() => handleTabSelect('callLogs')}
              >
                콜로그
              </button>
              <button
                className={`px-4 py-2 rounded ${
                  selectedTab === 'smsLogs' ? 'bg-blue-500 text-white' : 'bg-gray-200'
                }`}
                onClick={() => handleTabSelect('smsLogs')}
              >
                문자로그
              </button>
            </div>

            {/* 그리드 영역 - 스크롤 가능 */}
            <div className="flex-1 p-4 overflow-auto">
              {selectedTab === 'phoneRecords' && (
                <GridComponent
                  dataSource={phoneRecords}
                  enableHover={true}
                  allowPaging={true}
                  pageSettings={{ pageSize: 10 }}
                  toolbar={['Search']}
                  allowSorting={true}
                >
                  <ColumnsDirective>
                    <ColumnDirective field="phoneNumber" headerText="전화번호" width="120" />
                    <ColumnDirective field="name" headerText="이름" width="120" />
                    <ColumnDirective field="memo" headerText="메모" width="200" />
                    <ColumnDirective field="userType" headerText="타입" width="80" />
                    <ColumnDirective field="createdAt" headerText="생성일" width="150" 
                      valueAccessor={timeAccessor}/>
                  </ColumnsDirective>
                  <Inject services={[Resize, Sort, Filter, Page, Toolbar, Search]} />
                </GridComponent>
              )}

              {selectedTab === 'callLogs' && (
                <GridComponent
                  dataSource={callLogs}
                  enableHover={true}
                  allowPaging={true}
                  pageSettings={{ pageSize: 10 }}
                  toolbar={['Search']}
                  allowSorting={true}
                  sortSettings={{
                    columns: [
                      { field: 'time', direction: 'Descending' }
                    ]
                  }}
                >
                  <ColumnsDirective>
                    <ColumnDirective field="phoneNumber" headerText="전화번호" width="120" />
                    <ColumnDirective 
                      field="time" 
                      headerText="시간" 
                      width="180"
                      valueAccessor={timeAccessor}
                    />
                    <ColumnDirective field="callType" headerText="통화타입" width="100" />
                  </ColumnsDirective>
                  <Inject services={[Resize, Sort, Filter, Page, Toolbar, Search]} />
                </GridComponent>
              )}

              {selectedTab === 'smsLogs' && (
                <GridComponent
                  dataSource={smsLogs}
                  enableHover={true}
                  allowPaging={true}
                  pageSettings={{ pageSize: 10 }}
                  toolbar={['Search']}
                  allowSorting={true}
                  sortSettings={{
                    columns: [
                      { field: 'time', direction: 'Descending' }
                    ]
                  }}
                >
                  <ColumnsDirective>
                    <ColumnDirective field="phoneNumber" headerText="전화번호" width="120" />
                    <ColumnDirective 
                      field="time" 
                      headerText="시간" 
                      width="180"
                      valueAccessor={timeAccessor}
                    />
                    <ColumnDirective field="smsType" headerText="문자타입" width="100" />
                    <ColumnDirective field="content" headerText="내용" width="300" />
                  </ColumnsDirective>
                  <Inject services={[Resize, Sort, Filter, Page, Toolbar, Search]} />
                </GridComponent>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Users;
