import React, { useState, useEffect, useRef } from 'react';
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
  ExcelExport
} from "@syncfusion/ej2-react-grids";
import { parseServerTimeToLocal } from '../../utils/dateUtils';

/**
 * 사용자의 통화 및 문자 로그를 표시하는 다이얼로그
 * @param {Object} props - 컴포넌트 속성
 * @param {boolean} props.isOpen - 다이얼로그 표시 여부
 * @param {Function} props.onClose - 닫기 버튼 클릭 핸들러
 * @param {Object} props.user - 사용자 객체
 * @param {Array} props.callLogs - 통화 로그 배열
 * @param {Array} props.smsLogs - 문자 로그 배열
 * @param {Function} props.onTabChange - 탭 변경 핸들러
 */
const UsersLogsDialog = ({ 
  isOpen, 
  onClose, 
  user, 
  callLogs, 
  smsLogs, 
  onTabChange 
}) => {
  // 탭 상태 (callLogs, smsLogs)
  const [activeTab, setActiveTab] = useState('callLogs');
  // 그리드 참조
  const callLogsGridRef = useRef(null);
  const smsLogsGridRef = useRef(null);
  
  // 내보낼 로그 데이터 생성 (특수문자 처리)
  const [processedCallLogs, setProcessedCallLogs] = useState([]);
  const [processedSmsLogs, setProcessedSmsLogs] = useState([]);

  // 데이터 처리하여 특수문자 등으로 인한 XML 오류 방지
  useEffect(() => {
    if (callLogs) {
      const processed = callLogs.map(log => ({
        ...log,
        phoneNumber: sanitizeString(log.phoneNumber),
        // callType은 이미 제한된 값이므로 정제 불필요
      }));
      setProcessedCallLogs(processed);
    }
    
    if (smsLogs) {
      const processed = smsLogs.map(log => ({
        ...log,
        phoneNumber: sanitizeString(log.phoneNumber),
        // 특수문자나 XML과 충돌할 수 있는 문자 처리
        content: sanitizeString(log.content),
        // smsType은 이미 제한된 값이므로 정제 불필요
      }));
      setProcessedSmsLogs(processed);
    }
  }, [callLogs, smsLogs]);

  // 다이얼로그가 열리거나 닫힐 때 body 스크롤 제어
  useEffect(() => {
    if (isOpen) {
      // 다이얼로그가 열릴 때 body 스크롤 비활성화
      document.body.style.overflow = 'hidden';
    } else {
      // 다이얼로그가 닫힐 때 body 스크롤 활성화
      document.body.style.overflow = 'auto';
    }
    
    // 컴포넌트 언마운트 시 스크롤 상태 원복
    return () => {
      document.body.style.overflow = 'auto';
    };
  }, [isOpen]);

  if (!isOpen) return null;

  // 문자열 정제 함수 - XML과 호환되지 않는 문자 제거/치환
  const sanitizeString = (str) => {
    if (!str) return '';
    
    // XML에서 허용되지 않는 문자 제거 (ASCII 제어 문자)
    let result = str.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '');
    
    // XML 특수문자 치환
    result = result
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&apos;');
      
    return result;
  };

  // 탭 변경 핸들러
  const handleTabChange = (tab) => {
    setActiveTab(tab);
    if (onTabChange) {
      onTabChange(tab);
    }
  };

  // 시간 변환 헬퍼
  const timeAccessor = (field, data) => {
    if (!data[field]) return '';
    return parseServerTimeToLocal(data[field]);
  };

  // 파일명 특수문자 정제
  const sanitizeFileName = (name) => {
    return name.replace(/[\\/:*?"<>|]/g, '_');
  };

  // 엑셀용 데이터 생성 (시간을 KST로 변환)
  const prepareDataForExport = (data) => {
    if (!data || !Array.isArray(data)) return [];
    
    return data.map(item => {
      const newItem = { ...item };
      
      // time 필드가 있으면 KST로 변환하여 저장
      if (newItem.time) {
        newItem.time = parseServerTimeToLocal(newItem.time);
      }
      
      return newItem;
    });
  };

  // 콜백으로 엑셀 내보내기 처리
  const toolbarClick = (args) => {
    try {
      // 사용자 정보가 포함된 파일명 생성 (파일명에 사용 불가능한 특수문자 제거)
      const userInfo = sanitizeFileName(
        `${user?.name || 'Unknown'}_${user?.loginId || 'Unknown'}_${user?.phoneNumber || 'Unknown'}_${user?.userType || 'Unknown'}_${user?.region || 'Unknown'}`
      );
      
      if (args.item.id.includes('excelexport')) {
        // 현재 활성화된 그리드 참조 가져오기
        let currentGrid;
        let title = '';
        let worksheetName = '';
        let colSpan = 3;
        let dataToExport = [];
        
        if (activeTab === 'callLogs' && callLogsGridRef.current) {
          currentGrid = callLogsGridRef.current;
          title = '통화 로그';
          worksheetName = '통화 로그';
          // 시간을 KST로 변환한 데이터 생성
          dataToExport = prepareDataForExport(processedCallLogs);
        } else if (activeTab === 'smsLogs' && smsLogsGridRef.current) {
          currentGrid = smsLogsGridRef.current;
          title = '문자 로그';
          worksheetName = '문자 로그';
          colSpan = 4;
          // 시간을 KST로 변환한 데이터 생성
          dataToExport = prepareDataForExport(processedSmsLogs);
        }

        if (currentGrid) {
          const exportProperties = {
            fileName: `${userInfo}_${title}.xlsx`,
            header: {
              headerRows: 2,
              rows: [
                { cells: [{ colSpan: colSpan, value: `${userInfo} - 사용자 기록`, style: { fontSize: 12, hAlign: 'Center', bold: true } }] },
                { cells: [{ colSpan: colSpan, value: title, style: { fontSize: 11, bold: true, hAlign: 'Center' } }] }
              ]
            },
            footer: {
              footerRows: 1,
              rows: [{ cells: [{ colSpan: colSpan, value: '출력일: ' + new Date().toLocaleString(), style: { fontSize: 10 } }] }]
            },
            workbook: {
              worksheets: [
                { worksheetName: worksheetName }
              ]
            },
            // 유니코드 지원 및 안전한 내보내기 설정
            enableFilter: false,
            encodeHtml: false,
            exportType: 'xlsx',
            dataSource: dataToExport // 변환된 시간 데이터를 사용
          };

          // 문자 로그인 경우 content 열에 자동 줄바꿈 설정
          if (activeTab === 'smsLogs') {
            exportProperties.columns = [
              { field: 'phoneNumber', width: 120 },
              { field: 'time', width: 120, wrapText: true },
              { field: 'smsType', width: 80 },
              { field: 'content', width: 400, wrapText: true }
            ];
          } else {
            exportProperties.columns = [
              { field: 'phoneNumber', width: 120 },
              { field: 'time', width: 150, wrapText: true },
              { field: 'callType', width: 80 }
            ];
          }
          
          currentGrid.excelExport(exportProperties);
        }
      }
    } catch (error) {
      console.error("엑셀 내보내기 중 오류:", error);
      alert("엑셀 파일 생성 중 오류가 발생했습니다.");
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50 p-4" onClick={(e) => e.stopPropagation()}>
      <div className="bg-white rounded-lg shadow-xl w-full max-w-4xl max-h-[90vh] flex flex-col" onClick={(e) => e.stopPropagation()}>
        {/* 헤더 */}
        <div className="flex justify-between items-center p-4 border-b">
          <h2 className="text-xl font-semibold">
            {user?.name || 'Unknown'}|{user?.loginId || 'Unknown'}|{user?.phoneNumber || 'Unknown'}|{user?.userType || 'Unknown'}|{user?.region || 'Unknown'}  - 사용자 기록
          </h2>
          <button
            onClick={onClose}
            className="text-gray-500 hover:text-gray-700"
          >
            <svg
              className="w-6 h-6"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth="2"
                d="M6 18L18 6M6 6l12 12"
              />
            </svg>
          </button>
        </div>

        {/* 탭 선택 */}
        <div className="flex border-b">
          <button
            className={`px-4 py-2 font-medium ${
              activeTab === 'callLogs'
                ? 'text-blue-600 border-b-2 border-blue-600'
                : 'text-gray-500 hover:text-gray-700'
            }`}
            onClick={() => handleTabChange('callLogs')}
          >
            통화 로그
          </button>
          <button
            className={`px-4 py-2 font-medium ${
              activeTab === 'smsLogs'
                ? 'text-blue-600 border-b-2 border-blue-600'
                : 'text-gray-500 hover:text-gray-700'
            }`}
            onClick={() => handleTabChange('smsLogs')}
          >
            문자 로그
          </button>
        </div>

        {/* 콘텐츠 */}
        <div className="flex-1 overflow-auto p-4">
          <div style={{ display: activeTab === 'callLogs' ? 'block' : 'none' }}>
            <GridComponent
              ref={callLogsGridRef}
              dataSource={processedCallLogs}
              allowPaging={true}
              pageSettings={{ pageSize: 10 }}
              toolbar={['Search', 'ExcelExport']}
              allowExcelExport={true}
              allowSorting={true}
              toolbarClick={toolbarClick}
              id="callLogs"
            >
              <ColumnsDirective>
                <ColumnDirective
                  field="phoneNumber"
                  headerText="전화번호"
                  width="150"
                />
                <ColumnDirective
                  field="time"
                  headerText="시간"
                  width="150"
                  wrapMode="Normal"
                  textAlign="Center"
                  valueAccessor={timeAccessor}
                />
                <ColumnDirective
                  field="callType"
                  headerText="유형"
                  width="100"
                  textAlign="Center"
                  template={(log) => {
                    switch (log.callType) {
                      case 'INCOMING':
                        return <span className="text-blue-600">수신</span>;
                      case 'OUTGOING':
                        return <span className="text-green-600">발신</span>;
                      case 'MISSED':
                        return <span className="text-red-600">부재중</span>;
                      case 'REJECTED':
                        return <span className="text-orange-600">거부</span>;
                      default:
                        return <span>{log.callType}</span>;
                    }
                  }}
                />
              </ColumnsDirective>
              <Inject services={[Resize, Sort, Filter, Page, Toolbar, Search, ExcelExport]} />
            </GridComponent>
          </div>

          <div style={{ display: activeTab === 'smsLogs' ? 'block' : 'none' }}>
            <GridComponent
              ref={smsLogsGridRef}
              dataSource={processedSmsLogs}
              allowPaging={true}
              pageSettings={{ pageSize: 10 }}
              toolbar={['Search', 'ExcelExport']}
              allowExcelExport={true}
              allowSorting={true}
              toolbarClick={toolbarClick}
              id="smsLogs"
              rowHeight={60}
            >
              <ColumnsDirective>
                <ColumnDirective
                  field="phoneNumber"
                  headerText="전화번호"
                  width="150"
                />
                <ColumnDirective
                  field="time"
                  headerText="시간"
                  width="250"
                  wrapMode="Normal"
                  textAlign="Center"
                  valueAccessor={timeAccessor}
                />
                <ColumnDirective
                  field="smsType"
                  headerText="유형"
                  width="80"
                  textAlign="Center"
                  template={(log) => {
                    switch (log.smsType) {
                      case 'RECEIVED':
                        return <span className="text-blue-600">수신</span>;
                      case 'SENT':
                        return <span className="text-green-600">발신</span>;
                      default:
                        return <span>{log.smsType}</span>;
                    }
                  }}
                />
                <ColumnDirective
                  field="content"
                  headerText="내용"
                  width="400"
                  wrapMode="Normal"
                  clipMode="EllipsisWithTooltip"
                  textAlign="Left"
                  template={(log) => (
                    <div style={{ whiteSpace: 'pre-wrap', wordBreak: 'break-all', maxWidth: '100%', overflowWrap: 'break-word' }}>
                      {log.content}
                    </div>
                  )}
                />
              </ColumnsDirective>
              <Inject services={[Resize, Sort, Filter, Page, Toolbar, Search, ExcelExport]} />
            </GridComponent>
          </div>
        </div>

        {/* 푸터 */}
        <div className="p-4 border-t flex justify-end">
          <button
            onClick={onClose}
            className="bg-gray-500 text-white px-4 py-2 rounded hover:bg-gray-600"
          >
            닫기
          </button>
        </div>
      </div>
    </div>
  );
};

export default UsersLogsDialog; 