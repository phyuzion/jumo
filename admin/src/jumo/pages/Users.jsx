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
} from "../graphql/queries";
import {
  CREATE_USER,
  UPDATE_USER,
  RESET_USER_PASSWORD
} from "../graphql/mutations";

import { Header } from "../components";

const PAGE_SIZE = 10; // syncfusion paging size(예시)

const Users = () => {
  const gridRef = useRef(null);

  // (1) getAllUsers
  const { data, loading, error, refetch } = useQuery(GET_ALL_USERS, {
    fetchPolicy: 'network-only',
  });

  // (2) create / update / reset
  const [createUserMutation]         = useMutation(CREATE_USER);
  const [updateUserMutation]         = useMutation(UPDATE_USER);
  const [resetUserPasswordMutation]  = useMutation(RESET_USER_PASSWORD);

  // (3-1) 전화번호부 기록 (lazy)
  const [getUserRecordsLazy, { data: recordsData }] = useLazyQuery(GET_USER_RECORDS, {
    fetchPolicy: 'no-cache',
    notifyOnNetworkStatusChange: true,
  });

  // (3-2) 통화/문자 로그 (lazy)
  const [getUserCallLogLazy, { data: callLogData }] = useLazyQuery(GET_USER_CALL_LOG, {
    fetchPolicy: 'no-cache',
    notifyOnNetworkStatusChange: true,
  });
  const [getUserSMSLogLazy, { data: smsLogData }]   = useLazyQuery(GET_USER_SMS_LOG, {
    fetchPolicy: 'no-cache',
    notifyOnNetworkStatusChange: true,
  });

  // ========== State ==========
  const [users, setUsers] = useState([]);

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
  const [formPhone,  setFormPhone]  = useState('');
  const [formName,   setFormName]   = useState('');
  const [formRegion, setFormRegion] = useState('');

  // 수정 폼
  const [editPhone,      setEditPhone]      = useState('');
  const [editName,       setEditName]       = useState('');
  const [editType,       setEditType]       = useState(0);
  const [editValidUntil, setEditValidUntil] = useState('');
  const [editRegion,     setEditRegion]     = useState('');

  // ================= useEffect =================

  // getAllUsers -> users
  useEffect(() => {
    if (data?.getAllUsers) {
      setUsers(data.getAllUsers);
    }
  }, [data]);

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
    // validUntil이 epoch string인지, ISO string인지 상황에 따라 확인
    let dt = null;
    // 시도1: epoch 파싱
    const epoch = parseInt(data.validUntil, 10);
    if (!isNaN(epoch)) {
      dt = new Date(epoch);
    }
    // 시도2: 만약 epoch 변환 실패 시 Date로 직접 파싱
    if (!dt || isNaN(dt.getTime())) {
      dt = new Date(data.validUntil);
    }
    if (isNaN(dt.getTime())) return data.validUntil; 
    return dt.toISOString().slice(0, 10); // "YYYY-MM-DD"
  };

  // ============= CREATE =============
  const handleCreate = () => {
    setFormPhone('');
    setFormName('');
    setFormRegion('');
    setShowCreateModal(true);
  };

  const handleCreateSubmit = async () => {
    try {
      const res = await createUserMutation({
        variables: {
          phoneNumber: formPhone,
          name: formName,
          region: formRegion,
        },
      });
      const tempPass = res.data?.createUser?.tempPassword;
      alert(`유저 생성 완료! 임시비번: ${tempPass}`);

      setShowCreateModal(false);
      handleRefresh(); // 목록 재조회
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
    setEditPhone(u.phoneNumber || '');
    setEditName(u.name || '');
    setEditType(u.type || 0);
    setEditRegion(u.region || '');

    // validUntil => "YYYY-MM-DD"
    let dtStr = '';
    if (u.validUntil) {
      try {
        // epoch 시도
        const maybeEpoch = parseInt(u.validUntil, 10);
        let dt = null;
        if (!isNaN(maybeEpoch)) {
          dt = new Date(maybeEpoch);
        } else {
          dt = new Date(u.validUntil);
        }
        if (!isNaN(dt.getTime())) {
          dtStr = dt.toISOString().slice(0, 10);
        }
      } catch (err) {
        // ignore
      }
    }
    setEditValidUntil(dtStr);

    setShowEditModal(true);
  };

  const handleEditSubmit = async () => {
    if (!editUser) return;
    try {
      let validStr = null;
      if (editValidUntil) {
        const dt = new Date(`${editValidUntil}T00:00:00`);
        validStr = dt.toISOString();
      }
      await updateUserMutation({
        variables: {
          userId: editUser.id,
          phoneNumber: editPhone,
          name: editName,
          type: parseInt(editType, 10),
          validUntil: validStr,
          region: editRegion,
        }
      });
      alert('수정 완료!');
      setShowEditModal(false);
      setEditUser(null);
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
            <ColumnDirective field="type"        headerText="타입"      width="60"  textAlign="Center" />
            <ColumnDirective field="region"      headerText="지역"      width="80"  textAlign="Center" />
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
                placeholder="PhoneNumber"
                value={formPhone}
                onChange={(e) => setFormPhone(e.target.value)}
                className="border p-1"
              />
              <input
                placeholder="Name"
                value={formName}
                onChange={(e) => setFormName(e.target.value)}
                className="border p-1"
              />
              <input
                placeholder="Region"
                value={formRegion}
                onChange={(e) => setFormRegion(e.target.value)}
                className="border p-1"
              />
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
                placeholder="PhoneNumber"
                value={editPhone}
                onChange={(e) => setEditPhone(e.target.value)}
                className="border p-1"
              />
              <input
                placeholder="Name"
                value={editName}
                onChange={(e) => setEditName(e.target.value)}
                className="border p-1"
              />
              <input
                placeholder="Type (정수)"
                type="number"
                value={editType}
                onChange={(e) => setEditType(e.target.value)}
                className="border p-1"
              />
              <input
                placeholder="YYYY-MM-DD"
                type="date"
                value={editValidUntil}
                onChange={(e) => setEditValidUntil(e.target.value)}
                className="border p-1"
              />
              <input
                placeholder="Region"
                value={editRegion}
                onChange={(e) => setEditRegion(e.target.value)}
                className="border p-1"
              />
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

      {/* RECORDS MODAL (전화번호부 + 통화로그 + 문자로그 탭) */}
      {showRecordsModal && recordUser && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex justify-center items-center">
          <div className="bg-white p-4 w-96 rounded shadow max-h-[90vh] overflow-y-auto">
            <h2 className="text-xl font-bold mb-2">유저 상세</h2>
            <p className="mb-2">
              {recordUser.loginId} ({recordUser.name})
            </p>

            {/* 탭 버튼 */}
            <div className="flex gap-2 mb-4">
              <button
                className={`px-2 py-1 rounded ${
                  selectedTab === 'phoneRecords' ? 'bg-blue-300' : ''
                }`}
                onClick={() => handleTabSelect('phoneRecords')}
              >
                번호부
              </button>
              <button
                className={`px-2 py-1 rounded ${
                  selectedTab === 'callLogs' ? 'bg-blue-300' : ''
                }`}
                onClick={() => handleTabSelect('callLogs')}
              >
                콜로그
              </button>
              <button
                className={`px-2 py-1 rounded ${
                  selectedTab === 'smsLogs' ? 'bg-blue-300' : ''
                }`}
                onClick={() => handleTabSelect('smsLogs')}
              >
                문자로그
              </button>
            </div>

            {/* 탭 내용 */}
            {selectedTab === 'phoneRecords' && (
              <div className="flex flex-col gap-2">
                {phoneRecords.length === 0 && <p>기록이 없습니다.</p>}
                {phoneRecords.map((r, idx) => (
                  <div key={idx} className="border p-2 rounded">
                    <p>Phone: {r.phoneNumber}</p>
                    <p>Name: {r.name}</p>
                    <p>Memo: {r.memo}</p>
                    <p>Type: {r.type}</p>
                    <p>CreatedAt: {r.createdAt}</p>
                  </div>
                ))}
              </div>
            )}

            {selectedTab === 'callLogs' && (
              <div className="flex flex-col gap-2">
                {callLogs.length === 0 && <p>통화로그가 없습니다.</p>}
                {callLogs.map((c, idx) => (
                  <div key={idx} className="border p-2 rounded">
                    <p>Phone: {c.phoneNumber}</p>
                    <p>Time: {c.time}</p>
                    <p>Type: {c.callType}</p>
                  </div>
                ))}
              </div>
            )}

            {selectedTab === 'smsLogs' && (
              <div className="flex flex-col gap-2">
                {smsLogs.length === 0 && <p>문자로그가 없습니다.</p>}
                {smsLogs.map((m, idx) => (
                  <div key={idx} className="border p-2 rounded">
                    <p>Phone: {m.phoneNumber}</p>
                    <p>Time: {m.time}</p>
                    <p>Type: {m.smsType}</p>
                    <p>Content: {m.content}</p>
                  </div>
                ))}
              </div>
            )}

            <div className="mt-4 flex gap-2">
              <button
                className="bg-gray-300 px-3 py-1 rounded"
                onClick={() => {
                  // 모달 닫기
                  setShowRecordsModal(false);
                  setRecordUser(null);
                  // state 초기화
                  setPhoneRecords([]);
                  setCallLogs([]);
                  setSmsLogs([]);
                  setSelectedTab('phoneRecords');
                }}
              >
                닫기
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Users;
