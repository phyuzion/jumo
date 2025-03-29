import React, { useState, useEffect, useRef } from 'react';
import { useLazyQuery, useMutation } from '@apollo/client';
import {
  GridComponent,
  ColumnsDirective,
  ColumnDirective,
  Inject,
  Page,
  Sort,
  Filter,
  Toolbar,
} from '@syncfusion/ej2-react-grids';

import { GET_PHONE_NUMBER } from '../graphql/queries';
import { UPSERT_PHONE_RECORDS } from '../graphql/mutations';
import { Header } from '../components';

const PAGE_SIZE = 10;

const PhoneRecords = () => {
  const gridRef = useRef(null);

  // 전화번호 검색
  const [searchPhone, setSearchPhone] = useState('');
  const [phoneNumberDoc, setPhoneNumberDoc] = useState(null);
  const [records, setRecords] = useState([]);

  // create/edit 모달
  const [showModal, setShowModal] = useState(false);
  const [editRecord, setEditRecord] = useState(null);

  // 폼 필드
  const [formPhoneNumber, setFormPhoneNumber] = useState('');
  const [formName, setFormName] = useState('');
  const [formMemo, setFormMemo] = useState('');
  const [formType, setFormType] = useState(0);
  const [formUserName, setFormUserName] = useState('');
  const [formUserType, setFormUserType] = useState('일반');
  const [formCreatedAt, setFormCreatedAt] = useState(''); // epoch or ISO

  // gql
  const [getPhoneNumberLazy, { loading: loadingPhone, error: errorPhone, data: dataPhone }] =
    useLazyQuery(GET_PHONE_NUMBER, { fetchPolicy: 'network-only' });

  const [upsertPhoneRecords] = useMutation(UPSERT_PHONE_RECORDS);

  // effect
  useEffect(() => {
    if (dataPhone?.getPhoneNumber) {
      setPhoneNumberDoc(dataPhone.getPhoneNumber);
      setRecords(dataPhone.getPhoneNumber.records);
    }
  }, [dataPhone]);

  useEffect(() => {
    if (gridRef.current) {
      gridRef.current.dataSource = records;
      gridRef.current.refresh();
    }
  }, [records]);

  const handleSearch = () => {
    if (!searchPhone) {
      alert('전화번호를 입력하세요.');
      return;
    }
    getPhoneNumberLazy({ variables: { phoneNumber: searchPhone } });
  };

  // 새 레코드
  const handleCreateClick = () => {
    setEditRecord(null);
    // 기본값
    setFormPhoneNumber(searchPhone); // 검색한 번호가 있으면 그걸 기본으로
    setFormName('');
    setFormMemo('');
    setFormType(0);
    setFormUserName('');
    setFormUserType('일반');
    const now = new Date();
    const isoStr = now.toISOString().slice(0, 16);
    setFormCreatedAt(isoStr);
    setShowModal(true);
  };

  // 수정
  const handleEditClick = (rec) => {
    setEditRecord(rec);
    setFormPhoneNumber(searchPhone);
    setFormName(rec.name || '');
    setFormMemo(rec.memo || '');
    setFormType(rec.type || 0);
    setFormUserName(rec.userName || '');
    setFormUserType(rec.userType || '일반');

    if (rec.createdAt) {
      // ISO 문자열을 datetime-local 형식으로 변환
      setFormCreatedAt(rec.createdAt.slice(0, 16));
    } else {
      const now = new Date();
      const isoStr = now.toISOString().slice(0, 16);
      setFormCreatedAt(isoStr);
    }

    setShowModal(true);
  };

  const handleSave = async () => {
    if (!formPhoneNumber) {
      alert('phoneNumber는 필수입니다.');
      return;
    }
    // 레코드 1개
    const inputRec = {
      phoneNumber: formPhoneNumber,
      name: formName,
      memo: formMemo,
      type: parseInt(formType, 10),
      userName: formUserName,
      userType: formUserType,
      createdAt: formCreatedAt, // 문자열이지만 서버에서 parse
    };
    try {
      await upsertPhoneRecords({ variables: { records: [inputRec] } });
      alert('저장 완료');
      setShowModal(false);
      // 재검색
      if (searchPhone) {
        getPhoneNumberLazy({ variables: { phoneNumber: searchPhone } });
      }
    } catch (err) {
      alert(err.message);
    }
  };

  // 그리드 헬퍼
  const createdAtAccessor = (field, data) => {
    if (!data[field]) return '';
    try {
      // ISO 문자열이면 포맷 변경
      if (typeof data[field] === 'string' && data[field].includes('T')) {
        return data[field].replace('T', ' ').substring(0, 19); // "2023-04-28T14:30:45" -> "2023-04-28 14:30:45"
      }
      
      return data[field];
    } catch (e) {
      return data[field];
    }
  };

  return (
    <div className="m-2 md:m-2 p-2 md:p-5 bg-white rounded-2xl shadow-xl">
      <Header category="Page" title="전화번호 레코드 관리" />

      <div className="mb-4 flex gap-2 items-center">
        <input
          className="border p-1 rounded"
          placeholder="전화번호(01012345678)"
          value={searchPhone}
          onChange={(e) => setSearchPhone(e.target.value)}
        />
        <button className="bg-gray-500 text-white px-3 py-1 rounded" onClick={handleSearch}>
          검색
        </button>
        <button className="bg-blue-500 text-white px-3 py-1 rounded" onClick={handleCreateClick}>
          새 레코드
        </button>
      </div>

      {loadingPhone && <p>Loading phone data...</p>}
      {errorPhone && <p className="text-red-500">Error: {errorPhone.message}</p>}

      {records.length > 0 && (
        <GridComponent
          ref={gridRef}
          dataSource={records}
          allowPaging={true}
          pageSettings={{ pageSize: PAGE_SIZE }}
          allowSorting={true}
        >
          <ColumnsDirective>
            {/* 순서: name | memo | type | userName | userType | createdAt */}
            <ColumnDirective field="name" headerText="이름" width="100" />
            <ColumnDirective field="memo" headerText="메모" width="120" />
            <ColumnDirective field="type" headerText="타입" width="60" textAlign="Center" />
            <ColumnDirective field="userName" headerText="상호" width="120" />
            <ColumnDirective field="userType" headerText="상호타입" width="80" textAlign="Center" />
            <ColumnDirective
              field="createdAt"
              headerText="생성일"
              width="120"
              textAlign="Center"
              valueAccessor={createdAtAccessor}
            />
            {/* Edit */}
            <ColumnDirective
              headerText="수정"
              width="80"
              textAlign="Center"
              template={(rec) => (
                <button
                  className="bg-orange-500 text-white px-2 py-1 rounded"
                  onClick={() => handleEditClick(rec)}
                >
                  수정
                </button>
              )}
            />
          </ColumnsDirective>
          <Inject services={[Page, Sort, Filter, Toolbar]} />
        </GridComponent>
      )}

      {showModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex justify-center items-center">
          <div className="bg-white p-4 w-96 rounded shadow max-h-[80vh] overflow-y-auto">
            <h2 className="text-xl font-bold mb-2">{editRecord ? '레코드 수정' : '레코드 생성'}</h2>
            
            <div className="flex flex-col gap-2">
              {/* phoneNumber */}
              <div className="flex gap-2">
                <label className="w-24">Phone#</label>
                <input
                  className="border p-1 flex-1"
                  placeholder="01012345678"
                  value={formPhoneNumber}
                  onChange={(e) => setFormPhoneNumber(e.target.value)}
                />
              </div>

              {/* name */}
              <div className="flex gap-2">
                <label className="w-24">이름</label>
                <input
                  className="border p-1 flex-1"
                  value={formName}
                  onChange={(e) => setFormName(e.target.value)}
                />
              </div>

              {/* memo */}
              <div className="flex gap-2">
                <label className="w-24">메모</label>
                <input
                  className="border p-1 flex-1"
                  value={formMemo}
                  onChange={(e) => setFormMemo(e.target.value)}
                />
              </div>

              {/* type */}
              <div className="flex gap-2">
                <label className="w-24">타입</label>
                <input
                  type="number"
                  className="border p-1 flex-1"
                  value={formType}
                  onChange={(e) => setFormType(e.target.value)}
                />
              </div>

              {/* userName */}
              <div className="flex gap-2">
                <label className="w-24">상호</label>
                <input
                  className="border p-1 flex-1"
                  value={formUserName}
                  onChange={(e) => setFormUserName(e.target.value)}
                />
              </div>

              {/* userType */}
              <div className="flex gap-2">
                <label className="w-24">상호타입</label>
                <select
                  className="border p-1 flex-1"
                  value={formUserType}
                  onChange={(e) => setFormUserType(e.target.value)}
                >
                  <option value="일반">일반</option>
                  <option value="중개">중개</option>
                  <option value="기타">기타</option>
                </select>
              </div>

              {/* createdAt */}
              <div className="flex gap-2">
                <label className="w-24">생성일</label>
                <input
                  type="datetime-local"
                  className="border p-1 flex-1"
                  value={formCreatedAt}
                  onChange={(e) => setFormCreatedAt(e.target.value)}
                />
              </div>
            </div>

            <div className="mt-4 flex gap-2 justify-end">
              <button
                className="bg-blue-500 text-white px-3 py-1 rounded"
                onClick={handleSave}
              >
                저장
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
    </div>
  );
};

export default PhoneRecords;
