// src/pages/ContentsWithQuill.jsx

import React, { useState, useEffect, useRef } from 'react';
import { useQuery, useLazyQuery, useMutation } from '@apollo/client';

import {
  GridComponent,
  ColumnsDirective,
  ColumnDirective,
  Page,
  Sort,
  Filter,
  Inject,
} from '@syncfusion/ej2-react-grids';

import ReactQuill from 'react-quill';
import 'react-quill/dist/quill.snow.css';
import Quill from 'quill'; // 실시간 Delta -> HTML 변환용 (npm install quill)

import { GET_CONTENTS, GET_SINGLE_CONTENT } from '../graphql/queries';
import { CREATE_CONTENT,
    UPDATE_CONTENT,
    DELETE_CONTENT,
    CREATE_REPLY,
    DELETE_REPLY, } from '../graphql/mutations';

// Quill toolbar 설정
const quillModules = {
  toolbar: [
    [{ size: [] }],
    ['bold', 'italic', 'underline'],
    [{ color: [] }, { background: [] }],
    [{ align: [] }],
    ['clean'],
  ],
};
const quillFormats = [
  'size',
  'bold', 'italic', 'underline',
  'color', 'background',
  'align',
];

const PAGE_SIZE = 10;

/** Delta -> HTML 변환(실제 Quill 사용) */
function deltaToHtml(deltaObj) {
  if (!deltaObj || !deltaObj.ops) {
    return '<p>(비어있음)</p>';
  }
  // 임시 div
  const tempDiv = document.createElement('div');
  // Quill 인스턴스 생성(해당 div 에 연결)
  const tempQuill = new Quill(tempDiv);
  // Delta 세팅
  tempQuill.setContents(deltaObj);
  // 최종 HTML 추출
  return tempQuill.root.innerHTML;
}

function ContentsWithQuill() {
  const gridRef = useRef(null);

  // 목록 필터 (type)
  const [typeFilter, setTypeFilter] = useState(0);

  // 목록
  const { data, loading, error, refetch } = useQuery(GET_CONTENTS, {
    variables: { type: typeFilter },
    fetchPolicy: 'network-only',
  });
  const [list, setList] = useState([]);

  // 상세 lazyQuery
  // fetchPolicy:'network-only' => 매번 서버에서 fresh data
  const [getSingleLazy, { data: singleData }] = useLazyQuery(GET_SINGLE_CONTENT, {
    fetchPolicy: 'network-only',
  });

  // Mutation
  const [createContentMut] = useMutation(CREATE_CONTENT);
  const [updateContentMut] = useMutation(UPDATE_CONTENT);
  const [deleteContentMut] = useMutation(DELETE_CONTENT);
  const [createReplyMut] = useMutation(CREATE_REPLY);
  const [deleteReplyMut] = useMutation(DELETE_REPLY);

  // 새글 모달
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [newType, setNewType] = useState(0);
  const [newTitle, setNewTitle] = useState('');
  const [newDelta, setNewDelta] = useState(null); // Delta 객체

  // 상세/수정 모달
  const [showDetailModal, setShowDetailModal] = useState(false);
  const [detailItem, setDetailItem] = useState(null); // { id, userId, content(Delta), createdAt, ... }
  const [editMode, setEditMode] = useState(false);

  // 수정 시
  const [editType, setEditType] = useState(0);
  const [editTitle, setEditTitle] = useState('');
  const [editDelta, setEditDelta] = useState(null); // Delta 객체

  // 댓글
  const [replyText, setReplyText] = useState('');

  // 목록 로딩
  useEffect(() => {
    if (data?.getContents) {
      setList(data.getContents);
      if (gridRef.current) {
        gridRef.current.dataSource = data.getContents;
        gridRef.current.refresh();
      }
    }
  }, [data]);

  // 상세 로딩
  useEffect(() => {
    if (singleData?.getSingleContent) {
      setDetailItem(singleData.getSingleContent);
      setShowDetailModal(true);
      setEditMode(false);
      setReplyText('');
      // 초기값
      setEditTitle(singleData.getSingleContent.title || '');
      setEditType(singleData.getSingleContent.type || 0);
      if (singleData.getSingleContent.content) {
        // Delta 객체
        setEditDelta(singleData.getSingleContent.content);
      } else {
        setEditDelta(null);
      }
    }
  }, [singleData]);

  // 핸들러
  const handleTypeChange = (e) => {
    const val = parseInt(e.target.value, 10);
    setTypeFilter(val);
    refetch({ type: val });
  };

  // 새글
  const handleCreateClick = () => {
    setNewType(typeFilter);
    setNewTitle('');
    setNewDelta(null);
    setShowCreateModal(true);
  };
  const handleCreateSubmit = async () => {
    try {
      // Delta 객체 -> 서버: content: JSON
      // if null => { ops: [] } 로 대체
      const finalDelta = newDelta || { ops: [] };
      await createContentMut({
        variables: {
          type: newType,
          title: newTitle,
          content: finalDelta,
        },
      });
      alert('작성 완료!');
      setShowCreateModal(false);
      refetch({ type: typeFilter });
    } catch (err) {
      alert(err.message);
    }
  };

  // 상세 열기
  const handleDetailOpen = async (row) => {
    try {
      await getSingleLazy({ variables: { contentId: row.id } });
    } catch (err) {
      alert(err.message);
    }
  };

  // 글 삭제
  const handleDeleteContent = async (row) => {
    if (!window.confirm('정말 삭제?')) return;
    try {
      const res = await deleteContentMut({ variables: { contentId: row.id } });
      if (res.data.deleteContent) {
        alert('삭제 완료');
        refetch({ type: typeFilter });
      }
    } catch (err) {
      alert(err.message);
    }
  };

  // 댓글 등록
  const handleReplySubmit = async () => {
    if (!detailItem) return;
    if (!replyText.trim()) return;
    try {
      const res = await createReplyMut({
        variables: { contentId: detailItem.id, comment: replyText },
      });
      if (res.data.createReply) {
        setDetailItem({
          ...detailItem,
          comments: res.data.createReply.comments,
        });
        setReplyText('');
      }
    } catch (err) {
      alert(err.message);
    }
  };

  // 댓글 삭제
  const handleDeleteReply = async (idx) => {
    if (!detailItem) return;
    if (!window.confirm('댓글 삭제?')) return;
    try {
      const res = await deleteReplyMut({
        variables: { contentId: detailItem.id, index: idx },
      });
      if (res.data.deleteReply) {
        // 수동 제거
        const newCom = [...detailItem.comments];
        newCom.splice(idx, 1);
        setDetailItem({ ...detailItem, comments: newCom });
      }
    } catch (err) {
      alert(err.message);
    }
  };

  // 수정 저장
  const handleUpdateSubmit = async () => {
    if (!detailItem) return;
    try {
      const finalDelta = editDelta || { ops: [] };
      const res = await updateContentMut({
        variables: {
          contentId: detailItem.id,
          title: editTitle,
          type: editType,
          content: finalDelta,
        },
      });
      alert('수정 완료!');
      setEditMode(false);
      setDetailItem(res.data.updateContent);
      refetch({ type: typeFilter });
    } catch (err) {
      alert(err.message);
    }
  };

  // 닫기 (상세)
  const handleCloseDetail = () => {
    setShowDetailModal(false);
    setDetailItem(null);
  };

  // 닫기 (새글)
  const handleCloseCreate = () => {
    setShowCreateModal(false);
  };

  // Delta -> HTML
  const renderDeltaAsHtml = (deltaObj) => {
    return { __html: deltaToHtml(deltaObj) };
  };

  // 포맷된 Date
  const formatDate = (dateString) => {
    if (!dateString) return '';
    const d = new Date(dateString);
    if (isNaN(d.getTime())) return dateString;
    return d.toLocaleString();
  };

  return (
    <div className="p-4">
      <h1 className="font-bold text-xl mb-2">게시판 (Syncfusion + Quill) - 개선버전</h1>

      {/* Filter */}
      <div className="flex gap-2 mb-4">
        <select value={typeFilter} onChange={handleTypeChange} className="border p-1 rounded">
          <option value={0}>CONTENT_0</option>
          <option value={1}>CONTENT_1</option>
          <option value={2}>CONTENT_2</option>
        </select>
        <button
          className="bg-blue-500 text-white px-3 py-1 rounded"
          onClick={handleCreateClick}
        >
          새글 작성
        </button>
      </div>

      {loading && <p>로딩중...</p>}
      {error && <p className="text-red-500">{error.message}</p>}

      {/* 목록(Grid) */}
      <GridComponent
        ref={gridRef}
        dataSource={list}
        allowPaging={true}
        pageSettings={{ pageSize: PAGE_SIZE }}
        allowSorting={true}
      >
        <ColumnsDirective>
          <ColumnDirective field="id" headerText="ID" width="100" />
          <ColumnDirective field="userId" headerText="User" width="100" />
          <ColumnDirective field="title" headerText="Title" width="200" />
          <ColumnDirective field="type" headerText="Type" width="60" textAlign="Center" />
          <ColumnDirective
            field="createdAt"
            headerText="Date"
            width="140"
            textAlign="Center"
            template={(rowData) => (
              <span>{formatDate(rowData.createdAt)}</span>
            )}
          />
          <ColumnDirective
            headerText="Detail"
            width="80"
            textAlign="Center"
            template={(rowData) => (
              <button
                className="bg-green-500 text-white px-2 py-1 rounded"
                onClick={() => handleDetailOpen(rowData)}
              >
                열기
              </button>
            )}
          />
          <ColumnDirective
            headerText="Del"
            width="80"
            textAlign="Center"
            template={(rowData) => (
              <button
                className="bg-red-500 text-white px-2 py-1 rounded"
                onClick={() => handleDeleteContent(rowData)}
              >
                삭제
              </button>
            )}
          />
        </ColumnsDirective>
        <Inject services={[Page, Sort, Filter]} />
      </GridComponent>

      {/* CREATE MODAL */}
      {showCreateModal && (
        <div className="fixed inset-0 bg-black bg-opacity-40 flex justify-center items-center z-50">
          <div
            className="bg-white rounded shadow-2xl p-4 overflow-hidden flex flex-col"
            style={{ width: '80%', height: '80%' }}
          >
            <h2 className="text-xl font-bold mb-2">새글 작성</h2>

            <div className="flex-none mb-2">
              <label>Type: </label>
              <select
                className="border p-1 rounded w-32 mr-2"
                value={newType}
                onChange={(e) => setNewType(parseInt(e.target.value, 10))}
              >
                <option value={0}>CONTENT_0</option>
                <option value={1}>CONTENT_1</option>
                <option value={2}>CONTENT_2</option>
              </select>

              <label>Title: </label>
              <input
                className="border p-1 ml-2"
                value={newTitle}
                onChange={(e) => setNewTitle(e.target.value)}
              />
            </div>

            <div className="flex-auto overflow-auto border mb-2">
              <ReactQuill
                modules={quillModules}
                formats={quillFormats}
                onChange={(html, delta, source, editor) => {
                  // deltaObj
                  const deltaObj = editor.getContents();
                  setNewDelta(deltaObj); // Delta 객체 그대로
                }}
                style={{ height: '100%' }}
              />
            </div>

            <div className="flex-none flex gap-2 justify-end">
              <button
                className="bg-blue-500 text-white px-4 py-2 rounded"
                onClick={handleCreateSubmit}
              >
                작성
              </button>
              <button
                className="bg-gray-300 px-4 py-2 rounded"
                onClick={() => setShowCreateModal(false)}
              >
                닫기
              </button>
            </div>
          </div>
        </div>
      )}

      {/* DETAIL MODAL */}
      {showDetailModal && detailItem && (
        <div className="fixed inset-0 bg-black bg-opacity-40 flex justify-center items-center z-50">
          <div
            className="bg-white rounded shadow-2xl p-4 overflow-hidden flex flex-col"
            style={{ width: '80%', height: '80%' }}
          >
            {!editMode ? (
              // 뷰 모드
              <>
                <h2 className="text-xl font-bold mb-2">상세 보기</h2>
                <div className="flex-none mb-2">
                  <p>ID: {detailItem.id}</p>
                  <p>User: {detailItem.userId}</p>
                  <p>Type: {detailItem.type}</p>
                  <p>Title: {detailItem.title}</p>
                  <p>CreatedAt: {formatDate(detailItem.createdAt)}</p>
                </div>

                <div className="flex-auto border overflow-auto mb-2 p-2">
                  {/* Delta -> HTML */}
                  <div dangerouslySetInnerHTML={renderDeltaAsHtml(detailItem.content)} />
                </div>

                {/* 댓글 */}
                <div className="flex-none border p-2 mb-2 overflow-auto" style={{ maxHeight:'150px' }}>
                  <h3 className="font-semibold">댓글 ({detailItem.comments.length})</h3>
                  {detailItem.comments.map((c, idx) => (
                    <div key={idx} className="border p-1 my-1">
                      <p>작성자: {c.userId}</p>
                      <p>{c.comment}</p>
                      <p>{formatDate(c.createdAt)}</p>
                      <button
                        className="bg-red-500 text-white px-2 py-1 rounded"
                        onClick={() => handleDeleteReply(idx)}
                      >
                        삭제
                      </button>
                    </div>
                  ))}
                  <div className="mt-2 flex gap-2">
                    <input
                      className="border p-1 flex-1"
                      placeholder="댓글 입력"
                      value={replyText}
                      onChange={(e) => setReplyText(e.target.value)}
                    />
                    <button
                      className="bg-blue-500 text-white px-3 py-1 rounded"
                      onClick={handleReplySubmit}
                    >
                      등록
                    </button>
                  </div>
                </div>

                <div className="flex-none flex gap-2 justify-end">
                  <button
                    className="bg-orange-500 text-white px-3 py-1 rounded"
                    onClick={() => {
                      setEditTitle(detailItem.title);
                      setEditType(detailItem.type);
                      setEditDelta(detailItem.content || { ops:[] });
                      setEditMode(true);
                    }}
                  >
                    수정
                  </button>
                  <button
                    className="bg-gray-300 px-3 py-1 rounded"
                    onClick={() => {
                      setShowDetailModal(false);
                      setDetailItem(null);
                    }}
                  >
                    닫기
                  </button>
                </div>
              </>
            ) : (
              // 수정 모드
              <>
                <h2 className="text-xl font-bold mb-2">글 수정</h2>
                <div className="flex-none mb-2">
                  <label>Type: </label>
                  <select
                    className="border p-1 rounded w-32"
                    value={editType}
                    onChange={(e) => setEditType(parseInt(e.target.value, 10))}
                  >
                    <option value={0}>CONTENT_0</option>
                    <option value={1}>CONTENT_1</option>
                    <option value={2}>CONTENT_2</option>
                  </select>
                  <label className="ml-2">Title: </label>
                  <input
                    className="border p-1 ml-1"
                    value={editTitle}
                    onChange={(e) => setEditTitle(e.target.value)}
                  />
                </div>

                <div className="flex-auto border overflow-auto mb-2 p-2">
                  <ReactQuill
                    modules={quillModules}
                    formats={quillFormats}
                    style={{ height: '100%' }}
                    onChange={(html, delta, source, editor) => {
                      const deltaObj = editor.getContents();
                      setEditDelta(deltaObj);
                    }}
                    onReady={(quill) => {
                      // Quill 초기화 후, 기존 Delta 세팅
                      if (editDelta) {
                        quill.setContents(editDelta);
                      }
                    }}
                  />
                </div>

                <div className="flex-none flex gap-2 justify-end">
                  <button
                    className="bg-blue-500 text-white px-4 py-2 rounded"
                    onClick={handleUpdateSubmit}
                  >
                    저장
                  </button>
                  <button
                    className="bg-gray-300 px-4 py-2 rounded"
                    onClick={() => setEditMode(false)}
                  >
                    취소
                  </button>
                </div>
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

export default ContentsWithQuill;
