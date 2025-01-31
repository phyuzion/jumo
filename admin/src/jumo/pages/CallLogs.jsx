import React, { useState, useEffect, useRef } from "react";
import { useQuery, useLazyQuery } from "@apollo/client";
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

import { GET_CALL_LOGS, GET_CALL_LOGS_BY_PHONE } from "../graphql/queries";
import { Header } from "../components";

const PAGE_SIZE = 20;

const CallLogs = () => {
  const gridRef = useRef(null);

  // 1) summaryData 로컬 스토리지에서 읽기
  const summaryDataStr = localStorage.getItem('summaryData');
  let totalCount = 200; // 디폴트
  if (summaryDataStr) {
    try {
      const parsed = JSON.parse(summaryDataStr);
      // parsed = { callLogsCount, usersCount, customersCount }
      if (parsed?.callLogsCount) {
        totalCount = parseInt(parsed.callLogsCount, 10) || 200;
      }
    } catch (err) {
      // parse 실패 시 그냥 200 유지
    }
  }

  // Main list (admin callLogs)
  const { loading, error, data, refetch } = useQuery(GET_CALL_LOGS, {
    variables: { start: 1, end: PAGE_SIZE },
    fetchPolicy: 'network-only',
  });

  // lazy query for searching by phone
  const [getLogsByPhoneLazy, { data: phoneData }] = useLazyQuery(GET_CALL_LOGS_BY_PHONE, {
    fetchPolicy: 'network-only',
  });

  const [logs, setLogs] = useState([]);
  const [searchValue, setSearchValue] = useState('');

  // on data
  useEffect(() => {
    if (data?.getCallLogs) {
      setLogs(data.getCallLogs);
      localStorage.setItem('callLogs', JSON.stringify(data.getCallLogs));
    }
  }, [data]);

  // on phoneData
  useEffect(() => {
    if (phoneData?.getCallLogByPhone) {
      setLogs(phoneData.getCallLogByPhone);
      localStorage.setItem('callLogs', JSON.stringify(phoneData.getCallLogByPhone));
    }
  }, [phoneData]);

  // force grid refresh if logs changes
  useEffect(() => {
    if (gridRef.current) {
      gridRef.current.dataSource = logs;
      gridRef.current.refresh();
    }
  }, [logs]);

  // paging
  const handleActionBegin = async (args) => {
    if (args.requestType === 'paging') {
      args.cancel = true;
      const currentPage = args.currentPage;
      const start = (currentPage - 1) * PAGE_SIZE + 1;
      const end   = currentPage * PAGE_SIZE;
      try {
        const res = await refetch({ start, end });
        if (res.data?.getCallLogs) {
          setLogs(res.data.getCallLogs);
          localStorage.setItem('callLogs', JSON.stringify(res.data.getCallLogs));
        }
      } catch (err) {
        console.error('Paging refetch error:', err);
      }
    }
  };

  // search
  const handleSearch = async () => {
    if (!searchValue) {
      // empty => refetch main
      refetch({ start:1, end: PAGE_SIZE });
      return;
    }
    try {
      // if admin: no userId, userPhone needed
      // if user: pass userId, userPhone
      await getLogsByPhoneLazy({
        variables: {
          customerPhone: searchValue,
          // userId: 'U123', userPhone: '010-xxx' if user
        }
      });
    } catch (err) {
      alert(err.message);
    }
  };

  // format timestamp => "YYYY-MM-DD HH:mm:ss"
  const timestampAccessor = (field, data) => {
    if (!data.timestamp) return '';
    const ms = parseInt(data.timestamp); // if stored as millisecond number
    const d = new Date(ms);
    if (isNaN(d.getTime())) return data.timestamp;

    // e.g. "YYYY-MM-DD HH:mm:ss"
    const year = d.getFullYear();
    const month = String(d.getMonth()+1).padStart(2,'0');
    const day = String(d.getDate()).padStart(2,'0');
    const hours = String(d.getHours()).padStart(2,'0');
    const mins = String(d.getMinutes()).padStart(2,'0');
    const secs = String(d.getSeconds()).padStart(2,'0');
    return `${year}-${month}-${day} ${hours}:${mins}:${secs}`;
  };

  return (
    <div className="m-2 md:m-10 p-2 md:p-10 bg-white rounded-3xl shadow-2xl">
      <Header category="Page" title="수신내역 (서버 페이징)" />

      <div className="flex gap-2 mb-4">
        <input
          type="text"
          placeholder="고객 전화번호 검색"
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

      {loading && <p>Loading call logs...</p>}
      {error && <p className="text-red-500">Error: {error.message}</p>}

      {!loading && !error && (
        <GridComponent
          ref={gridRef}
          id="gridComp"
          dataSource={logs}
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
            <ColumnDirective field="_id" headerText="LogID" width="80" textAlign="Center" />
            
            <ColumnDirective 
              field="timestamp" 
              headerText="Timestamp" 
              width="150" 
              textAlign="Center"
              valueAccessor={timestampAccessor}
            />
            
            <ColumnDirective field="userId.name" headerText="User Name" width="100" textAlign="Center" />
            <ColumnDirective field="userId.phone" headerText="User Phone" width="120" textAlign="Center" />
            <ColumnDirective field="customerId.phone" headerText="Customer" width="110" textAlign="Center" />
            <ColumnDirective field="customerId.averageScore" headerText="AvgScore" width="90" textAlign="Center" />
            <ColumnDirective field="score" headerText="Score" width="70" textAlign="Center" />
            <ColumnDirective field="memo" headerText="Memo" width="150" />
          </ColumnsDirective>

          <Inject
            services={[
              Resize,
              Sort,
              ContextMenu,
              Filter,
              Page,
              Toolbar,
              ExcelExport,
              PdfExport,
            ]}
          />
        </GridComponent>
      )}
    </div>
  );
};

export default CallLogs;
