import React, { useState, useEffect } from "react";
import { useQuery } from "@apollo/client";
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

import { GET_CALL_LOGS } from "../graphql/queries";
import { Header } from "../components";

const PAGE_SIZE = 20; // 한 페이지당 표시할 로우 수

// 임시로 총개수를 200 으로 잡지만, 필요하면 서버에 getCallLogsCount 쿼리로 real값 가능
const TOTAL_COUNT = 200; 

const CallLogs = () => {

  // 1) Apollo useQuery(기본 1페이지: 1~20)
  const { loading, error, data, refetch } = useQuery(GET_CALL_LOGS, {
    variables: { start: 1, end: PAGE_SIZE },
    fetchPolicy: 'network-only',
  });

  // 2) 콜로그 배열 (state)
  const [logs, setLogs] = useState([]);

  // 3) 서버 응답이 바뀔 때 logs 업데이트 + 로컬 스토리지 저장
  useEffect(() => {
    if (data && data.getCallLogs) {
      setLogs(data.getCallLogs);
      localStorage.setItem('callLogs', JSON.stringify(data.getCallLogs));
    }
  }, [data]);

  // 4) Syncfusion 페이지네이션 이벤트
  const handleActionBegin = async (args) => {
    if (args.requestType === 'paging') {
      const currentPage = args.currentPage;
      const start = (currentPage - 1) * PAGE_SIZE + 1;
      const end   = currentPage * PAGE_SIZE;

      args.cancel = true; // 클라이언트 페이징 중단

      try {
        const res = await refetch({ start, end });
        if (res.data && res.data.getCallLogs) {
          setLogs(res.data.getCallLogs);
          localStorage.setItem('callLogs', JSON.stringify(res.data.getCallLogs));
        }
      } catch (err) {
        console.error('Paging refetch error:', err);
      }
    }
  };

  return (
    <div className="m-2 md:m-10 p-2 md:p-10 bg-white rounded-3xl shadow-2xl">
      <Header category="Page" title="수신내역 (서버 페이징)" />

      {loading && <p>Loading call logs...</p>}
      {error && <p className="text-red-500">Error: {error.message}</p>}

      {!loading && !error && (
        <GridComponent
          id="gridComp"
          dataSource={logs}
          allowPaging={true}
          allowSorting={true}
          toolbar={['Search']}
          pageSettings={{
            pageSize: PAGE_SIZE,
            totalRecordsCount: TOTAL_COUNT,
            pageCount: 5,
          }}
          actionBegin={handleActionBegin}
        >
          <ColumnsDirective>
            <ColumnDirective field="_id" headerText="LogID" width="80" textAlign="Center" />
            <ColumnDirective field="timestamp" headerText="Timestamp" width="150" textAlign="Center" />
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
