import React, { useState, useEffect, useRef } from 'react';
import { useQuery, useMutation } from '@apollo/client';
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
  Search
} from '@syncfusion/ej2-react-grids';

import { CREATE_NOTIFICATION } from '../graphql/mutations';
import { GET_NOTIFICATIONS } from '../graphql/queries';

const PAGE_SIZE = 10;

/** 날짜 포맷 (로컬 표시) */
function formatLocalDate(str) {
  if (!str) return '';
  const d = new Date(parseInt(str));
  if (isNaN(d.getTime())) return str;
  return d.toLocaleString(); 
}

export default function Notifications() {
  // ====== 1) getNotifications (Query) ======
  const { data, loading, error, refetch } = useQuery(GET_NOTIFICATIONS, {
    fetchPolicy: 'network-only',
  });
  const [notifications, setNotifications] = useState([]);

  // ====== 2) createNotification (Mutation) ======
  const [createNotificationMut] = useMutation(CREATE_NOTIFICATION);

  // ====== 3) 모달 제어 ======
  const [showCreateModal, setShowCreateModal] = useState(false);
  
  // 새 알림 form
  const [title, setTitle] = useState('');
  const [message, setMessage] = useState('');
  const [validDate, setValidDate] = useState('');  // "YYYY-MM-DDTHH:MM" 형식 (HTML5 datetime-local)
  const [targetUserId, setTargetUserId] = useState(''); // optional
  
  // ====== useEffect: data -> notifications ======
  useEffect(() => {
    if (data && data.getNotifications) {
      setNotifications(data.getNotifications);
    }
  }, [data]);

  // ====== Grid ref ======
  const gridRef = useRef(null);

  useEffect(() => {
    if (gridRef.current) {
      gridRef.current.dataSource = notifications;
      gridRef.current.refresh();
    }
  }, [notifications]);

  // ====== create modal 열기 ======
  const handleCreateClick = () => {
    setTitle('');
    setMessage('');
    setValidDate('');      // "" => "기본 1일" 서버 정책
    setTargetUserId('');
    setShowCreateModal(true);
  };

  // ====== create modal 닫기 ======
  const handleCloseModal = () => {
    setShowCreateModal(false);
  };

  // ====== 새 알림 생성 ======
  const handleCreateSubmit = async () => {
    try {
      // validDate(로컬) -> ISO(UTC)
      // 예) "2023-09-15T23:00" (KST) -> new Date("2023-09-15T23:00:00") -> .toISOString()
      let finalValidUntil = undefined;
      if (validDate) {
        const localDT = new Date(validDate);
        // HTML datetime-local은 로컬 타임존 기준
        // .toISOString() => UTC
        finalValidUntil = localDT.toISOString();
      }

      const variables = {
        title,
        message,
        validUntil: finalValidUntil,
      };
      if (targetUserId.trim()) {
        variables.userId = targetUserId.trim();
      }

      await createNotificationMut({ variables });
      alert('알림 생성 완료!');
      setShowCreateModal(false);

      refetch(); // 목록 갱신
    } catch (err) {
      alert(err.message);
    }
  };

  // ====== render ======
  return (
    <div className="m-2 md:m-10 p-2 md:p-10 bg-white rounded-3xl shadow-2xl">
      <div className="flex justify-between items-center mb-4">
        <h2 className="text-xl font-bold">알림 목록</h2>
        <button
          className="bg-blue-500 text-white px-3 py-1 rounded"
          onClick={handleCreateClick}
        >
          알림 생성
        </button>
      </div>

      {loading && <p>로딩중...</p>}
      {error && <p className="text-red-500">{error.message}</p>}

      {/* Syncfusion Grid */}
      <GridComponent
        ref={gridRef}
        dataSource={notifications}
        allowPaging={true}
        pageSettings={{ pageSize: PAGE_SIZE }}
        allowSorting={true}
      >
        <ColumnsDirective>
          <ColumnDirective field="id" headerText="ID" width="150" />
          <ColumnDirective field="title" headerText="제목" width="120" />
          <ColumnDirective field="message" headerText="내용" width="200" />
          
          {/* targetUserId가 null이면 전역, 아니면 특정 유저 */}
          <ColumnDirective
            field="targetUserId"
            headerText="대상유저"
            width="120"
            template={(rowData) => {
              return rowData.targetUserId 
                ? rowData.targetUserId 
                : "(전역)";
            }}
          />

          {/* validUntil */}
          <ColumnDirective
            field="validUntil"
            headerText="유효기간"
            width="120"
            textAlign="Center"
            template={(rowData) => (
              <span>{formatLocalDate(rowData.validUntil)}</span>
            )}
          />
          
          {/* createdAt */}
          <ColumnDirective
            field="createdAt"
            headerText="생성일시"
            width="120"
            textAlign="Center"
            template={(rowData) => (
              <span>{formatLocalDate(rowData.createdAt)}</span>
            )}
          />
        </ColumnsDirective>

        <Inject services={[Resize, Sort, Filter, Page, Toolbar, Search]} />
      </GridComponent>

      {/* ========== CREATE MODAL ========== */}
      {showCreateModal && (
        <div className="fixed inset-0 bg-black bg-opacity-40 
                        flex justify-center items-center z-50">
          <div 
            className="bg-white p-4 w-96 rounded shadow-md"
          >
            <h2 className="text-xl font-bold mb-3">알림 생성</h2>

            <label className="block mb-1">제목</label>
            <input
              className="border p-1 w-full mb-3"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
            />

            <label className="block mb-1">내용</label>
            <textarea
              className="border p-1 w-full mb-3"
              rows={3}
              value={message}
              onChange={(e) => setMessage(e.target.value)}
            />

            <label className="block mb-1">유효기간 (KST로)</label>
            <input
              type="datetime-local"
              className="border p-1 w-full mb-3"
              value={validDate}
              onChange={(e) => setValidDate(e.target.value)}
            />
            <small className="text-gray-500">
              (미입력 시 서버에서 기본 1일)
            </small>

            <label className="block mt-3 mb-1">특정 유저ID (선택)</label>
            <input
              className="border p-1 w-full mb-3"
              placeholder="비워두면 전역 알림"
              value={targetUserId}
              onChange={(e) => setTargetUserId(e.target.value)}
            />

            <div className="flex gap-2 justify-end">
              <button
                className="bg-blue-500 text-white px-4 py-2 rounded"
                onClick={handleCreateSubmit}
              >
                생성
              </button>
              <button
                className="bg-gray-300 px-4 py-2 rounded"
                onClick={handleCloseModal}
              >
                닫기
              </button>
            </div>
          </div>
        </div>
      )}

    </div>
  );
}
