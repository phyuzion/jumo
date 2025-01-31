import React, { useState, useEffect, useRef } from "react";
import { useQuery, useMutation, useLazyQuery } from "@apollo/client";
import {
  GridComponent,
  ColumnsDirective,
  ColumnDirective,
  Resize,
  Sort,
  ContextMenu,
  Filter,
  Page,
  ExcelExport,
  PdfExport,
  Inject,
  Toolbar,
} from "@syncfusion/ej2-react-grids";

import { GET_USER_LIST, GET_USER_BY_PHONE, GET_USER_BY_NAME } from "../graphql/queries";
import { CREATE_USER, UPDATE_USER } from "../graphql/mutations";
import { Header } from "../components";

const PAGE_SIZE = 10; 

const Users = () => {
  const gridRef = useRef(null);


  // 1) summaryData 로컬 스토리지에서 읽기
  const summaryDataStr = localStorage.getItem('summaryData');
  let totalCount = 200; // 디폴트
  if (summaryDataStr) {
    try {
      const parsed = JSON.parse(summaryDataStr);
      // parsed = { callLogsCount, usersCount, customersCount }
      if (parsed?.usersCount) {
        totalCount = parseInt(parsed.usersCount, 10) || 200;
      }
    } catch (err) {
      // parse 실패 시 그냥 200 유지
    }
  }


  // ----------------- GRAPHQL: List Query -----------------
  const { loading, error, data, refetch } = useQuery(GET_USER_LIST, {
    variables: { start: 1, end: PAGE_SIZE },
    fetchPolicy: 'network-only',
  });

  // ----------------- STATES -----------------
  const [users, setUsers] = useState([]);

  // 모달 제어
  const [showModal, setShowModal] = useState(false);   // create
  const [showEditModal, setShowEditModal] = useState(false); // edit
  const [editUser, setEditUser] = useState(null);

  // form 입력값
  const [formPhone, setFormPhone] = useState('');
  const [formName, setFormName] = useState('');
  const [formMemo, setFormMemo] = useState('');
  const [formValidUntil, setFormValidUntil] = useState(''); // string "YYYY-MM-DD"

  // 뮤테이션
  const [createUserMutation] = useMutation(CREATE_USER);
  const [updateUserMutation] = useMutation(UPDATE_USER);

  // 검색
  const [searchValue, setSearchValue] = useState('');
  const [searchType, setSearchType] = useState('phone');

  // lazy query
  const [getUserByPhoneLazy, { data: phoneData }] = useLazyQuery(GET_USER_BY_PHONE, { fetchPolicy: 'network-only' });
  const [getUserByNameLazy, { data: nameData }] = useLazyQuery(GET_USER_BY_NAME, { fetchPolicy: 'network-only' });

  // ===================== useEffect =====================
  // 메인 목록
  useEffect(() => {
    if (data?.getUserList) {
      setUsers(data.getUserList);
      localStorage.setItem('users', JSON.stringify(data.getUserList));
    }
  }, [data]);

  // 검색: phone
  useEffect(() => {
    if (phoneData?.getUserByPhone) {
      setUsers(phoneData.getUserByPhone);
      localStorage.setItem('users', JSON.stringify(phoneData.getUserByPhone));
    }
  }, [phoneData]);

  // 검색: name
  useEffect(() => {
    if (nameData?.getUserByName) {
      setUsers(nameData.getUserByName);
      localStorage.setItem('users', JSON.stringify(nameData.getUserByName));
    }
  }, [nameData]);

  // users가 바뀔 때마다 Grid 강제 refresh
  useEffect(() => {
    if (gridRef.current) {
      gridRef.current.dataSource = users;
      gridRef.current.refresh();
    }
  }, [users]);

  // ============= Grid Paging =============
  const handleActionBegin = async (args) => {
    if (args.requestType === 'paging') {
      args.cancel = true;
      const currentPage = args.currentPage;
      const start = (currentPage - 1) * PAGE_SIZE + 1;
      const end   = currentPage * PAGE_SIZE;
      try {
        const res = await refetch({ start, end });
        if (res.data?.getUserList) {
          setUsers(res.data.getUserList);
          localStorage.setItem('users', JSON.stringify(res.data.getUserList));
        }
      } catch (err) {
        console.error(err);
      }
    }
  };

  // ============= 새로고침 =============
  const handleRefresh = async () => {
    try {
      const res = await refetch({ start:1, end: PAGE_SIZE });
      if (res.data?.getUserList) {
        setUsers(res.data.getUserList);
        localStorage.setItem('users', JSON.stringify(res.data.getUserList));
      }
    } catch (err) {
      alert(err.message);
    }
  };

  // ============= 검색 =============
  const handleSearch = async () => {
    if (!searchValue) {
      handleRefresh();
      return;
    }
    try {
      if (searchType === 'phone') {
        await getUserByPhoneLazy({ variables: { phone: searchValue } });
      } else {
        await getUserByNameLazy({ variables: { name: searchValue } });
      }
    } catch (err) {
      alert(err.message);
    }
  };

  // ============= CREATE USER =============
  const handleCreateClick = () => {
    setFormPhone('');
    setFormName('');
    setFormMemo('');
    setFormValidUntil('');   // "YYYY-MM-DD"
    setShowModal(true);
  };

  const handleCreateSubmit = async () => {
    try {
      // formValidUntil => UTC
      let validIso = null;
      if (formValidUntil) {
        const dt = new Date(`${formValidUntil}T00:00:00`); // local midnight
        validIso = dt.toISOString();
      }
      await createUserMutation({
        variables: {
          phone: formPhone,
          name: formName,
          memo: formMemo,
          validUntil: validIso,
        }
      });
      alert('User created!');
      setShowModal(false);

      // 목록 재조회
      const res = await refetch({ start:1, end: PAGE_SIZE });
      if (res.data?.getUserList) {
        setUsers(res.data.getUserList);
        localStorage.setItem('users', JSON.stringify(res.data.getUserList));
      }
    } catch (err) {
      alert(err.message);
    }
  };

  // ============= UPDATE USER =============
  const handleEditClick = (user) => {
    setEditUser(user);
    setFormPhone(user.phone || '');
    setFormName(user.name || '');
    setFormMemo(user.memo || '');

    // user.validUntil => "YYYY-MM-DD"
    let dateStr = '';
    if (user.validUntil) {
      const dt = new Date(parseInt(user.validUntil));
      if (!isNaN(dt.getTime())) {
        dateStr = dt.toISOString().slice(0,10);
      }
    }
    setFormValidUntil(dateStr);

    setShowEditModal(true);
  };

  const handleUpdateSubmit = async () => {
    try {
      let validIso = null;
      if (formValidUntil) {
        const dt = new Date(`${formValidUntil}T00:00:00`);
        validIso = dt.toISOString();
      }
      await updateUserMutation({
        variables: {
          userId: editUser.userId,
          phone: formPhone,
          name: formName,
          memo: formMemo,
          validUntil: validIso,
        }
      });
      alert('User updated!');
      setShowEditModal(false);
      setEditUser(null);

      // 재조회
      const res = await refetch({ start:1, end: PAGE_SIZE });
      if (res.data?.getUserList) {
        setUsers(res.data.getUserList);
        localStorage.setItem('users', JSON.stringify(res.data.getUserList));
      }
    } catch (err) {
      alert(err.message);
    }
  };

  // ============= COLUMN HELPER =============
  const validUntilAccessor = (field, data) => {
    if (!data.validUntil) return '';
    const d = new Date(parseInt(data.validUntil));
    if (isNaN(d.getTime())) return data.validUntil;
    return d.toISOString().slice(0,10); // "YYYY-MM-DD"
  };

  return (
    <div className="m-2 md:m-10 p-2 md:p-10 bg-white rounded-3xl shadow-2xl">
      <Header category="Page" title="유저 목록 (서버 페이징)" />

      {/* TOP CONTROLS */}
      <div className="flex gap-2 mb-4">
        <button 
          className="bg-blue-500 text-white px-4 py-2 rounded"
          onClick={handleCreateClick}
        >
          유저 생성
        </button>
        <button 
          className="bg-green-500 text-white px-4 py-2 rounded"
          onClick={handleRefresh}
        >
          새로고침
        </button>

        <select 
          value={searchType} 
          onChange={(e) => setSearchType(e.target.value)}
          className="border p-1 rounded"
        >
          <option value="phone">Phone</option>
          <option value="name">Name</option>
        </select>
        <input 
          type="text"
          placeholder={`Search ${searchType}...`}
          value={searchValue}
          onChange={(e) => setSearchValue(e.target.value)}
          className="border p-1 rounded"
        />
        <button 
          className="bg-gray-500 text-white px-4 py-2 rounded"
          onClick={handleSearch}
        >
          검색
        </button>
      </div>

      {loading && <p>Loading users...</p>}
      {error && <p className="text-red-500">Error: {error.message}</p>}

      {/* GRID */}
      {!loading && !error && (
        <GridComponent
          ref={gridRef}
          dataSource={users}
          allowPaging={true}
          allowSorting={true}
          pageSettings={{
            pageSize: PAGE_SIZE,
            totalRecordsCount: totalCount,
            pageCount: 5,
          }}
          actionBegin={handleActionBegin}
        >
          <ColumnsDirective>
            <ColumnDirective field="_id" headerText="ID" width="90" textAlign="Center" />
            <ColumnDirective field="userId" headerText="UserID" width="110" textAlign="Center" />
            <ColumnDirective field="name" headerText="Name" width="100" />
            <ColumnDirective field="phone" headerText="Phone" width="120" />
            <ColumnDirective field="memo" headerText="Memo" width="120" />
            <ColumnDirective
              field="validUntil"
              headerText="ValidUntil"
              width="110"
              textAlign="Center"
              valueAccessor={validUntilAccessor}
            />
            <ColumnDirective
              headerText="Edit"
              width="80"
              textAlign="Center"
              template={(user) => (
                <button
                  className="bg-orange-500 text-white px-2 py-1 rounded"
                  onClick={() => handleEditClick(user)}
                >
                  수정
                </button>
              )}
            />
          </ColumnsDirective>

          <Inject
            services={[
              Resize,
              Sort,
              ContextMenu,
              Filter,
              Page,
              ExcelExport,
              PdfExport,
            ]}
          />
        </GridComponent>
      )}

      {/* CREATE MODAL */}
      {showModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex justify-center items-center">
          <div className="bg-white p-4 rounded shadow w-80">
            <h2 className="text-xl font-bold mb-2">유저 생성</h2>
            <div className="flex flex-col gap-2">
              <input
                placeholder="Phone"
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
                placeholder="Memo"
                value={formMemo}
                onChange={(e) => setFormMemo(e.target.value)}
                className="border p-1"
              />

              {/* HTML Date input */}
              <input
                type="date"
                placeholder="ValidUntil"
                value={formValidUntil}
                onChange={(e) => setFormValidUntil(e.target.value)}
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
                onClick={() => setShowModal(false)}
              >
                닫기
              </button>
            </div>
          </div>
        </div>
      )}

      {/* EDIT MODAL */}
      {showEditModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex justify-center items-center">
          <div className="bg-white p-4 rounded shadow w-80">
            <h2 className="text-xl font-bold mb-2">유저 수정</h2>
            <p className="mb-1">UserID: {editUser?.userId}</p>
            <div className="flex flex-col gap-2">
              <input
                placeholder="Phone"
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
                placeholder="Memo"
                value={formMemo}
                onChange={(e) => setFormMemo(e.target.value)}
                className="border p-1"
              />

              <input
                type="date"
                placeholder="ValidUntil"
                value={formValidUntil}
                onChange={(e) => setFormValidUntil(e.target.value)}
                className="border p-1"
              />
            </div>

            <div className="mt-4 flex gap-2">
              <button
                className="bg-orange-500 text-white px-3 py-1 rounded"
                onClick={handleUpdateSubmit}
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
    </div>
  );
};

export default Users;
