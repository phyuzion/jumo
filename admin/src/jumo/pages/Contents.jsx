import React, { useState, useEffect, useRef } from 'react';
import { useQuery, useLazyQuery, useMutation } from '@apollo/client';
import { loadErrorMessages, loadDevMessages } from "@apollo/client/dev";
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
import Quill from 'quill'; // Delta -> HTML 변환용

import { Header } from '../components';
import {
  GET_CONTENTS,
  GET_SINGLE_CONTENT,
  GET_ALL_REGIONS
} from '../graphql/queries';
import {
  CREATE_CONTENT,
  UPDATE_CONTENT,
  DELETE_CONTENT,
  CREATE_REPLY,
  DELETE_REPLY,
  UPLOAD_CONTENT_IMAGE,
} from '../graphql/mutations';

// 개발 환경에서 에러 메시지 로드
if (process.env.NODE_ENV !== "production") {
  loadDevMessages();
  loadErrorMessages();
}

// Quill 이미지 모듈 등록
const Image = Quill.import('formats/image');
Image.sanitize = (url) => url; // URL sanitize 비활성화
Quill.register(Image, true);

// Quill 설정
const quillModules = {
  toolbar: [
    [{ size: [] }],
    ['bold', 'italic', 'underline'],
    [{ color: [] }, { background: [] }],
    [{ align: [] }],
    ['image'],
    ['clean'],
  ],
};
const quillFormats = [
  'size',
  'bold', 'italic', 'underline',
  'color', 'background',
  'align',
  'image',
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
  
  // 이미지 URL에 서버 주소 추가
  const html = tempQuill.root.innerHTML;
  const modifiedHtml = html.replace(
    /src="(\/contents\/images\/[^"]+)"/g,
    'src="https://jumo-vs8e.onrender.com$1"'
  );
  
  return modifiedHtml;
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
  const quillRef = useRef(null);

  // ============ 목록 필터 ============
  const [typeFilter, setTypeFilter] = useState('공지사항');

  // ============ 이미지 업로드 테스트 ============
  const [uploadImageMut] = useMutation(UPLOAD_CONTENT_IMAGE);


  // ============ 지역 목록 ============
  const { data: regionsData } = useQuery(GET_ALL_REGIONS);
  const [regions, setRegions] = useState([]);

  useEffect(() => {
    if (regionsData?.getRegions) {
      setRegions(regionsData.getRegions);
    }
  }, [regionsData]);

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
  const [newType,  setNewType]  = useState('공지사항');
  const [newTitle, setNewTitle] = useState('');
  const [newDelta, setNewDelta] = useState(null); // Delta

  // ============ 상세/수정 모달 ============
  const [showDetailModal, setShowDetailModal] = useState(false);
  const [detailItem,      setDetailItem]      = useState(null);
  const [editMode,        setEditMode]        = useState(false);

  // 수정 시
  const [editType,   setEditType]   = useState('공지사항');
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
      setEditType(item.type || '공지사항');
    }
  }, [singleData]);

  // ============ 목록 필터 ============
  const handleTypeChange = (e) => {
    const val = e.target.value;
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

  // base64 데이터를 File 객체로 변환
  const dataURLtoFile = (dataurl, filename) => {
    let arr = dataurl.split(','),
        mime = arr[0].match(/:(.*?);/)[1],
        bstr = atob(arr[1]), 
        n = bstr.length, 
        u8arr = new Uint8Array(n);
    while(n--) {
        u8arr[n] = bstr.charCodeAt(n);
    }
    // File 객체를 생성할 때 필요한 속성들을 포함
    return new File([u8arr], filename, {
      type: mime,
      lastModified: new Date().getTime(),
      name: filename
    });
  };

  const handleCreateSubmit = async () => {
    try {
      let finalDelta = newDelta || { ops: [] };
      
      // Delta 데이터 로깅
      console.log('=== Delta Data ===');
      console.log(JSON.stringify(finalDelta, null, 2));
      console.log('Delta size:', JSON.stringify(finalDelta).length);
      console.log('=================');

      // Delta 데이터를 간단하게 만들기
      if (finalDelta.ops && finalDelta.ops.length > 0) {
        // 이미지 업로드 Promise 배열
        const uploadPromises = finalDelta.ops.map(async op => {
          // base64 이미지 데이터가 있는 경우
          if (op.insert && typeof op.insert === 'object' && op.insert.image) {
            const imageData = op.insert.image;
            if (imageData.startsWith('data:image')) {
              // 이미지 데이터를 서버에 업로드하고 URL로 치환
              const file = dataURLtoFile(imageData, 'image.png');
              const result = await uploadImageMut({
                variables: { file }
              });
              return {
                insert: { image: result.data.uploadContentImage },
                attributes: op.attributes
              };
            }
          }
          return {
            insert: op.insert,
            attributes: op.attributes
          };
        });

        // 모든 이미지 업로드가 완료될 때까지 대기
        const processedOps = await Promise.all(uploadPromises);
        finalDelta = { ops: processedOps };
      }

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
      // Delta 데이터의 이미지 URL에 서버 주소 추가
      if (finalDelta.ops && finalDelta.ops.length > 0) {
        finalDelta = {
          ops: finalDelta.ops.map(op => {
            if (op.insert && typeof op.insert === 'object' && op.insert.image) {
              const imageUrl = op.insert.image;
              if (imageUrl.startsWith('/contents/images/')) {
                return {
                  insert: { image: `https://jumo-vs8e.onrender.com${imageUrl}` },
                  attributes: op.attributes
                };
              }
            }
            return op;
          })
        };
      }

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

  // Quill 이미지 핸들러
  const handleImageUpload = async () => {
    const input = document.createElement('input');
    input.setAttribute('type', 'file');
    input.setAttribute('accept', 'image/*');
    input.click();

    input.onchange = async () => {
      const file = input.files[0];
      try {
        const result = await uploadImageMut({
          variables: {
            file,
          },
        });
        const url = result.data.uploadContentImage;
        const quill = quillRef.current.getEditor();
        const range = quill.getSelection(true);
        
        // 서버 주소를 포함한 전체 URL 생성
        const fullUrl = `https://jumo-vs8e.onrender.com${url}`;
        quill.insertText(range.index, '\n', { 'image': fullUrl });
        quill.setSelection(range.index + 1);
      } catch (err) {
        console.error('이미지 업로드 실패:', err);
        alert('이미지 업로드에 실패했습니다.');
      }
    };
  };

  return (
    <div className="m-2 md:m-2 p-2 md:p-5 bg-white rounded-2xl shadow-xl">
      <Header category="Page" title="게시판" />


      {/* Filter */}
      <div className="flex gap-2 mb-4">
        <select value={typeFilter} onChange={handleTypeChange} className="border p-1 rounded">
          <option value="공지사항">공지사항</option>
            {regions.map((region, index) => (
              <option key={index} value={region.name}>{region.name}</option>
            ))}
          <option value="익명">익명</option>
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
                onChange={(e) => setNewType(e.target.value)}
              >

                <option value="공지사항">공지사항</option>
                  {regions.map((region, index) => (
                    <option key={index} value={region.name}>{region.name}</option>
                  ))}
                <option value="익명">익명</option>

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
                ref={quillRef}
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
                    onChange={(e) => setEditType(e.target.value)}
                  >
                    <option value="공지사항">공지사항</option>
                    {regions.map((region, index) => (
                      <option key={index} value={region.name}>{region.name}</option>
                    ))}
                    <option value="익명">익명</option>
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
