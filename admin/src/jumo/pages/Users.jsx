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
  Selection
} from "@syncfusion/ej2-react-grids";

import { GET_ALL_USERS, GET_USER_RECORDS } from "../graphql/queries";
import { CREATE_USER, UPDATE_USER, RESET_USER_PASSWORD } from "../graphql/mutations";
import { Header } from "../components";

const PAGE_SIZE = 10; // syncfusion paging size(예시)

const Users = () => {
  const gridRef = useRef(null);

  // (1) getAllUsers
  const { data, loading, error, refetch } = useQuery(GET_ALL_USERS, {
    fetchPolicy: 'network-only',
  });

  // (2) create / update / reset
  const [createUserMutation] = useMutation(CREATE_USER);
  const [updateUserMutation] = useMutation(UPDATE_USER);
  const [resetUserPasswordMutation] = useMutation(RESET_USER_PASSWORD);

  // (3) getUserRecords (lazy)
  const [getUserRecordsLazy, { data: recordsData }] = useLazyQuery(GET_USER_RECORDS);

  // ========== State ==========
  const [users, setUsers] = useState([]);

  // 모달 제어
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [editUser, setEditUser] = useState(null);

  // 기록 모달
  const [showRecordsModal, setShowRecordsModal] = useState(false);
  const [recordUser, setRecordUser] = useState(null);
  const [phoneRecords, setPhoneRecords] = useState([]);

  // 생성 폼
  const [formPhone, setFormPhone] = useState('');
  const [formName, setFormName] = useState('');

  // 수정 폼
  const [editPhone, setEditPhone] = useState('');
  const [editName, setEditName] = useState('');
  const [editType, setEditType] = useState(0);
  const [editValidUntil, setEditValidUntil] = useState('');

  // ================= useEffect =================
  // getAllUsers 결과 -> users
  useEffect(() => {
    if (data?.getAllUsers) {
      setUsers(data.getAllUsers);
    }
  }, [data]);

  // getUserRecords 결과 -> recordUser, phoneRecords
  useEffect(() => {
    if (recordsData?.getUserRecords) {
      const { user, records } = recordsData.getUserRecords;
      setRecordUser(user);
      setPhoneRecords(records);
      setShowRecordsModal(true);
    }
  }, [recordsData]);

  // users 바뀌면 syncfusion grid refresh
  useEffect(() => {
    if (gridRef.current) {
      gridRef.current.dataSource = users;
      gridRef.current.refresh();
    }
  }, [users]);


  // ============= COLUMN HELPER =============
  const validUntilAccessor = (field, data) => {
    if (!data.validUntil) return '';
    const d = new Date(parseInt(data.validUntil));
    if (isNaN(d.getTime())) return data.validUntil;
    return d.toISOString().slice(0,10); // "YYYY-MM-DD"
  };

  // ============= CREATE =============
  const handleCreate = () => {
    setFormPhone('');
    setFormName('');
    setShowCreateModal(true);
  };

  const handleCreateSubmit = async () => {
    try {
      const res = await createUserMutation({
        variables: {
          phoneNumber: formPhone,
          name: formName,
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

    // validUntil => "YYYY-MM-DD"
    let dtStr = '';
    if (u.validUntil) {
      // u.validUntil가 "YYYY-MM-DDTHH:MM:SSZ" 형식일 수도, epoch일 수도
      // 여기서는 ISO string 가정
      try {
        const dt = new Date(parseInt(u.validUntil));
        console.log(dt);
        if (!isNaN(dt.getTime())) {
          dtStr = dt.toISOString().slice(0,10);
        }
      } catch (err) {}
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
          userId: editUser.id,  // or editUser.userId if server expects userId
          phoneNumber: editPhone,
          name: editName,
          type: parseInt(editType, 10),
          validUntil: validStr,
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
      const res = await resetUserPasswordMutation({
        variables: { userId: u.id }, // or u.userId, depending on server
      });
      const newPass = res.data?.resetUserPassword;
      alert(`임시비번: ${newPass}`);
    } catch (err) {
      alert(err.message);
    }
  };

  // ============= RECORDS =============
  const handleRecordsClick = async (u) => {
    try {
      await getUserRecordsLazy({ variables: { userId: u.id } }); // or u.userId
    } catch (err) {
      alert(err.message);
    }
  };

  // ============= SYNCFUSION HANDLERS (옵션) =============
  const handleActionBegin = (args) => {
    // 만약 Paging 쓸거면 설정
    // 여기서는 한방에 getAllUsers 하므로 페이징 로직 생략 or custom
  };

  // ============= RENDER =============
  return (
    <div className="m-2 md:m-10 p-2 md:p-10 bg-white rounded-3xl shadow-2xl">
      <Header category="Page" title="유저 목록" />

      <div className="flex gap-2 mb-4">
        <button onClick={handleCreate} className="bg-blue-500 text-white px-3 py-1 rounded">
          유저 생성
        </button>
        <button onClick={handleRefresh} className="bg-green-500 text-white px-3 py-1 rounded">
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
            <ColumnDirective field="loginId" headerText="아이디" width="40" />
            <ColumnDirective field="name" headerText="상호" width="150" />
            <ColumnDirective field="phoneNumber" headerText="번호" width="100" />
            <ColumnDirective field="type" headerText="타입" width="50" textAlign="Center" />
            <ColumnDirective
              field="validUntil"
              headerText="유효기간"
              width="50"
              textAlign="Center"
              valueAccessor={validUntilAccessor}
            />
            {/* Edit */}
            <ColumnDirective
              headerText="Edit"
              width="50"
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
              width="50"
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
              width="50"
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
                placeholder="ValidUntil YYYY-MM-DD"
                type="date"
                value={editValidUntil}
                onChange={(e) => setEditValidUntil(e.target.value)}
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

      {/* RECORDS MODAL */}
      {showRecordsModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex justify-center items-center">
          <div className="bg-white p-4 w-96 rounded shadow max-h-[80vh] overflow-y-auto">
            <h2 className="text-xl font-bold mb-2">유저 기록</h2>
            {recordUser && (
              <p className="mb-1">
                {recordUser.loginId} ({recordUser.name})
              </p>
            )}
            <div className="flex flex-col gap-2">
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
            <div className="mt-4 flex gap-2">
              <button
                className="bg-gray-300 px-3 py-1 rounded"
                onClick={() => {
                  setShowRecordsModal(false);
                  setRecordUser(null);
                  setPhoneRecords([]);
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
