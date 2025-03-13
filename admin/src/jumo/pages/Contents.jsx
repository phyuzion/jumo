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

import { Header } from '../components';

import ReactQuill from 'react-quill';
import 'react-quill/dist/quill.snow.css';
import Quill from 'quill'; // Delta -> HTML 변환용

import {
  GET_CONTENTS,
  GET_SINGLE_CONTENT
} from '../graphql/queries';
import {
  CREATE_CONTENT,
  UPDATE_CONTENT,
  DELETE_CONTENT,
  CREATE_REPLY,
  DELETE_REPLY,
} from '../graphql/mutations';

// Quill 설정
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
  const tempDiv = document.createElement('div');
  const tempQuill = new Quill(tempDiv);
  tempQuill.setContents(deltaObj);
  return tempQuill.root.innerHTML;
}

/** 날짜 포맷 */
function formatDate(dateStr) {
  if (!dateStr) return '';
  let d = null;
  const maybeEpoch = parseInt(dateStr, 10);
  if (!isNaN(maybeEpoch)) {
    d = new Date(maybeEpoch);
  } else {
    d = new Date(dateStr);
  }
  if (isNaN(d.getTime())) return dateStr;
  return d.toLocaleString();
}

function Contents() {
  const gridRef = useRef(null);

  // ============ 목록 필터 ============
  const [typeFilter, setTypeFilter] = useState(0);

  // ============ 목록 Query ============
  const { data, loading, error, refetch } = useQuery(GET_CONTENTS, {
    variables: { type: typeFilter },
    fetchPolicy: 'network-only',
  });
  const [list, setList] = useState([]);

  // ============ 상세 LazyQuery ============
  const [getSingleLazy, { data: singleData }] = useLazyQuery(GET_SINGLE_CONTENT, {
    fetchPolicy: 'no-cache',
    notifyOnNetworkStatusChange: true,
  });

  // ============ Mutation ============
  const [createContentMut] = useMutation(CREATE_CONTENT);
  const [updateContentMut] = useMutation(UPDATE_CONTENT);
  const [deleteContentMut] = useMutation(DELETE_CONTENT);
  const [createReplyMut]   = useMutation(CREATE_REPLY);
  const [deleteReplyMut]   = useMutation(DELETE_REPLY);

  // ============ 새글 모달 ============
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [newType,  setNewType]  = useState(0);
  const [newTitle, setNewTitle] = useState('');
  const [newDelta, setNewDelta] = useState(null); // Delta

  // ============ 상세/수정 모달 ============
  const [showDetailModal, setShowDetailModal] = useState(false);
  const [detailItem,      setDetailItem]      = useState(null);
  const [editMode,        setEditMode]        = useState(false);

  // 수정 시
  const [editType,   setEditType]   = useState(0);
  const [editTitle,  setEditTitle]  = useState('');
  const editQuillRef = useRef(null);

  // 댓글
  const [replyText, setReplyText] = useState('');

  // ============ 목록 로딩 ============
  useEffect(() => {
    if (data?.getContents) {
      setList(data.getContents);
      if (gridRef.current) {
        gridRef.current.dataSource = data.getContents;
        gridRef.current.refresh();
      }
    }
  }, [data]);

  // ============ 상세 로딩 ============
  useEffect(() => {
    if (singleData?.getSingleContent) {
      const item = singleData.getSingleContent;
      setDetailItem(item);
      setShowDetailModal(true);
      setEditMode(false);

      // 초기값
      setReplyText('');
      setEditTitle(item.title || '');
      setEditType(item.type || 0);
    }
  }, [singleData]);

  // ============ 목록 필터 ============
  const handleTypeChange = (e) => {
    const val = parseInt(e.target.value, 10);
    setTypeFilter(val);
    refetch({ type: val });
  };

  // ============ 새글 ============
  const handleCreateClick = () => {
    setNewType(typeFilter);
    setNewTitle('');
    setNewDelta({ ops: [] });
    setShowCreateModal(true);
  };

  const handleCreateSubmit = async () => {
    try {
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

  const handleCloseCreate = () => {
    setShowCreateModal(false);
  };

  // ============ 상세 열기 ============
  const handleDetailOpen = async (row) => {
    try {
      await getSingleLazy({ variables: { contentId: row.id, _ts: Date.now() } });
    } catch (err) {
      alert(err.message);
    }
  };

  // 닫기
  const handleCloseDetail = () => {
    setShowDetailModal(false);
    setDetailItem(null);
  };

  // 삭제
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

  // ============ 댓글 ============
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

  const handleDeleteReply = async (idx) => {
    if (!detailItem) return;
    if (!window.confirm('댓글 삭제?')) return;
    try {
      const res = await deleteReplyMut({
        variables: { contentId: detailItem.id, index: idx },
      });
      if (res.data.deleteReply) {
        const arr = [...detailItem.comments];
        arr.splice(idx, 1);
        setDetailItem({ ...detailItem, comments: arr });
      }
    } catch (err) {
      alert(err.message);
    }
  };

  // ============ 수정 모드 ============
  const handleUpdateSubmit = async () => {
    if (!detailItem) return;
    let finalDelta = { ops: [] };
    if (editQuillRef.current) {
      const editor = editQuillRef.current.getEditor();
      finalDelta = editor.getContents();
    }

    try {
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

  return (
    <div className="m-2 md:m-2 p-2 md:p-5 bg-white rounded-2xl shadow-xl">
      <Header category="Page" title="게시판" />

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

      {/* 목록 */}
      <GridComponent
        ref={gridRef}
        dataSource={list}
        allowPaging
        pageSettings={{ pageSize: PAGE_SIZE }}
        allowSorting
      >
        <ColumnsDirective>
          <ColumnDirective field="id" headerText="ID" width="80" />
          <ColumnDirective field="userId" headerText="UserId" width="100" />
          <ColumnDirective field="userName" headerText="UserName" width="120" />
          <ColumnDirective field="userRegion" headerText="Region" width="100" />
          <ColumnDirective field="title" headerText="Title" width="150" />
          <ColumnDirective field="type" headerText="Type" width="60" textAlign="Center" />
          <ColumnDirective
            field="createdAt"
            headerText="Created"
            width="130"
            textAlign="Center"
            template={(row) => <span>{formatDate(row.createdAt)}</span>}
          />
          <ColumnDirective
            headerText="Detail"
            width="80"
            textAlign="Center"
            template={(row) => (
              <button
                className="bg-green-500 text-white px-2 py-1 rounded"
                onClick={() => handleDetailOpen(row)}
              >
                열기
              </button>
            )}
          />
          <ColumnDirective
            headerText="Del"
            width="80"
            textAlign="Center"
            template={(row) => (
              <button
                className="bg-red-500 text-white px-2 py-1 rounded"
                onClick={() => handleDeleteContent(row)}
              >
                삭제
              </button>
            )}
          />
        </ColumnsDirective>
        <Inject services={[Page, Sort, Filter]} />
      </GridComponent>

      {/* ========== CREATE MODAL ========== */}
      {showCreateModal && (
        <div className="fixed inset-0 bg-black bg-opacity-40 flex justify-center items-center z-50">
          <div
            className="bg-white rounded shadow-2xl p-4 overflow-hidden flex flex-col"
            style={{ width: '80%', height: '80%' }}
          >
            <h2 className="text-xl font-bold mb-2">새글 작성</h2>

            <div className="flex-none mb-2">
              <label>Type:</label>
              <select
                className="border p-1 rounded w-32 ml-1 mr-2"
                value={newType}
                onChange={(e) => setNewType(parseInt(e.target.value, 10))}
              >
                <option value={0}>CONTENT_0</option>
                <option value={1}>CONTENT_1</option>
                <option value={2}>CONTENT_2</option>
              </select>

              <label>Title:</label>
              <input
                className="border p-1 ml-1"
                value={newTitle}
                onChange={(e) => setNewTitle(e.target.value)}
              />
            </div>

            <div className="flex-auto overflow-auto border mb-2">
              <ReactQuill
                modules={quillModules}
                formats={quillFormats}
                style={{ height: '100%' }}
                onChange={(html, delta, source, editor) => {
                  setNewDelta(editor.getContents());
                }}
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
                onClick={handleCloseCreate}
              >
                닫기
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ========== DETAIL MODAL ========== */}
      {showDetailModal && detailItem && (
        <div className="fixed inset-0 bg-black bg-opacity-40 flex justify-center items-center z-50">
          <div
            className="bg-white rounded shadow-2xl p-4 overflow-hidden flex flex-col"
            style={{ width: '80%', height: '80%' }}
          >
            {!editMode ? (
              // ===== VIEW MODE =====
              <>
                <h2 className="text-xl font-bold mb-2">상세 보기</h2>
                <div className="flex-none mb-2">
                  <p>ID: {detailItem.id}</p>
                  <p>UserId: {detailItem.userId}</p>
                  <p>UserName: {detailItem.userName}</p>
                  <p>UserRegion: {detailItem.userRegion}</p>
                  <p>Type: {detailItem.type}</p>
                  <p>Title: {detailItem.title}</p>
                  <p>CreatedAt: {formatDate(detailItem.createdAt)}</p>
                </div>

                <div className="flex-auto border overflow-auto mb-2 p-2">
                  {/* 
                    변경된 부분: .ql-snow .ql-editor 로 감싸서
                    Quill CSS 클래스들이 적용되도록 함 
                  */}
                  <div className="ql-snow">
                    <div
                      className="ql-editor"
                      dangerouslySetInnerHTML={{
                        __html: deltaToHtml(detailItem.content),
                      }}
                    />
                  </div>
                </div>

                {/* 댓글 */}
                <div className="flex-none border p-2 mb-2 overflow-auto" style={{ maxHeight: '150px' }}>
                  <h3>댓글 ({detailItem.comments.length})</h3>
                  {detailItem.comments.map((c, idx) => (
                    <div key={idx} className="border p-1 my-1">
                      <p>작성자: {c.userName} ({c.userRegion})</p>
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
                      setEditMode(true);
                      setEditTitle(detailItem.title);
                      setEditType(detailItem.type);
                    }}
                  >
                    수정
                  </button>
                  <button
                    className="bg-gray-300 px-3 py-1 rounded"
                    onClick={handleCloseDetail}
                  >
                    닫기
                  </button>
                </div>
              </>
            ) : (
              // ===== EDIT MODE =====
              <>
                <h2 className="text-xl font-bold mb-2">글 수정</h2>
                <div className="flex-none mb-2">
                  <label>Type:</label>
                  <select
                    className="border p-1 rounded w-32 ml-1 mr-3"
                    value={editType}
                    onChange={(e) => setEditType(parseInt(e.target.value, 10))}
                  >
                    <option value={0}>CONTENT_0</option>
                    <option value={1}>CONTENT_1</option>
                    <option value={2}>CONTENT_2</option>
                  </select>

                  <label>Title:</label>
                  <input
                    className="border p-1 ml-1"
                    value={editTitle}
                    onChange={(e) => setEditTitle(e.target.value)}
                  />
                </div>

                <div className="flex-auto border overflow-auto mb-2 p-2">
                  <ReactQuill
                    ref={editQuillRef}
                    modules={quillModules}
                    formats={quillFormats}
                    style={{ height: '100%' }}
                    defaultValue={detailItem.content}
                    onChange={(html, delta, source, editor) => {
                      // console.log(editor.getContents());
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

export default Contents;
