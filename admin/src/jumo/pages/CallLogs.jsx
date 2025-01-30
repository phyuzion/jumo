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

const PAGE_SIZE = 10;  // 한 페이지당 표시할 로우 수(동일하게 서버와 약속)

// (선택) 가령 서버에서 getCallLogsCount = 200 이라 가정
const TOTAL_COUNT = 200; // or use a separate query to get real total count

const CallLogs = () => {

  // 1) Apollo useQuery(기본 1페이지)
  const { loading, error, data, refetch } = useQuery(GET_CALL_LOGS, {
    variables: { start: 1, end: PAGE_SIZE },
    // fetchPolicy: 'network-only' (옵션) => 캐싱 제거
  });

  // 2) 콜로그 배열
  // data.getCallLogs 가 바뀔 때마다, Grid dataSource를 업데이트
  const [logs, setLogs] = useState([]);

  // 3) 서버 응답이 올 때마다 logs 업데이트
  useEffect(() => {
    if (data && data.getCallLogs) {
      setLogs(data.getCallLogs);
    }
  }, [data]);

  // 4) Syncfusion 페이지네이션 이벤트 (서버 사이드 페이징)
  const handleActionBegin = async (args) => {
    // 'paging' 이벤트 캐치
    if (args.requestType === 'paging') {
      // 현재 페이지
      const currentPage = args.currentPage;   // Syncfusion이 새로 바꿀 페이지
      // 예) 2페이지면 start=11, end=20
      const start = (currentPage - 1) * PAGE_SIZE + 1;
      const end   = currentPage * PAGE_SIZE;

      // 서버 재호출
      // cancel=true 로 Syncfusion의 기본 로직 중지 (client-side paging X)
      args.cancel = true;

      try {
        const res = await refetch({ start, end });
        if (res.data && res.data.getCallLogs) {
          setLogs(res.data.getCallLogs);
          // paging 완료되었으니, 그리드도 새 데이터로 갱신
          // Syncfusion은 우리가 args.cancel=true 로 막았으므로,
          // dataSource 직접 업데이트 + pageCurrent re-set 해줘야 할 수도 있음.
        }
      } catch (err) {
        console.error(err);
      }
    }
  };

  // 5) Grid pageSettings
  // pageSize: 한 페이지에 몇 개 표시할지
  // totalRecordsCount: 전체 데이터 개수(가짜 or 실제)
  // currentPage: 실제로는 Syncfusion이 내부적으로 관리, 
  //             처음엔 1로 시작

  return (
    <div className="m-2 md:m-10 p-2 md:p-10 bg-white rounded-3xl shadow-2xl">
      <Header category="Page" title="수신내역 (서버 페이징)" />

      {loading && <p>Loading call logs...</p>}
      {error && <p className="text-red-500">Error: {error.message}</p>}

      {!loading && !error && (
        <GridComponent
          id="gridComp"
          dataSource={logs}  // 우리가 state로 관리
          allowPaging={true}
          allowSorting={true}
          toolbar={['Search']}
          pageSettings={{
            pageSize: PAGE_SIZE,
            totalRecordsCount: TOTAL_COUNT,
            pageCount: 5,       // 페이지 버튼 몇 개 보일지
          }}
          actionBegin={handleActionBegin}  // 핵심: 페이징 시 refetch
        >
          <ColumnsDirective>
            <ColumnDirective field="_id" headerText="ID" width="80" textAlign="Center" />
            <ColumnDirective field="timestamp" headerText="Timestamp" width="140" textAlign="Center" />
            <ColumnDirective field="userId.name" headerText="User Name" width="100" />
            <ColumnDirective field="userId.phone" headerText="User Phone" width="120" />
            <ColumnDirective field="customerId.phone" headerText="Customer" width="100" />
            <ColumnDirective field="customerId.averageScore" headerText="AvgScore" width="90" textAlign="Center" />
            <ColumnDirective field="score" headerText="Score" width="70" textAlign="Center" />
            <ColumnDirective field="memo" headerText="Memo" width="120" />
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
