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

import { GET_USER_LIST } from "../graphql/queries"; // ★ 변경: GET_USER_LIST
import { Header } from "../components";

const PAGE_SIZE = 10; // 페이지 당 표시할 유저 수
const TOTAL_COUNT = 200; // 실제로는 별도 쿼리나 임시값

const Users = () => {
  // 1) useQuery로 GET_USER_LIST (기본: 1 ~ 10)
  const { loading, error, data, refetch } = useQuery(GET_USER_LIST, {
    variables: { start: 1, end: PAGE_SIZE },
    fetchPolicy: 'network-only',
  });

  // 2) State
  const [users, setUsers] = useState([]);

  // 3) data 변경 시 users 업데이트 + localStorage 저장
  useEffect(() => {
    if (data && data.getUserList) {
      setUsers(data.getUserList);
      localStorage.setItem('users', JSON.stringify(data.getUserList));
    }
  }, [data]);

  // 4) actionBegin: 페이징 이벤트 → refetch
  const handleActionBegin = async (args) => {
    if (args.requestType === 'paging') {
      args.cancel = true; 
      const currentPage = args.currentPage;
      const start = (currentPage - 1) * PAGE_SIZE + 1;
      const end = currentPage * PAGE_SIZE;

      try {
        const res = await refetch({ start, end });
        if (res.data && res.data.getUserList) {
          setUsers(res.data.getUserList);
          localStorage.setItem('users', JSON.stringify(res.data.getUserList));
        }
      } catch (err) {
        console.error(err);
      }
    }
  };

  return (
    <div className="m-2 md:m-10 p-2 md:p-10 bg-white rounded-3xl shadow-2xl">
      <Header category="Page" title="유저 목록 (서버 페이징)" />

      {loading && <p>Loading users...</p>}
      {error && <p className="text-red-500">Error: {error.message}</p>}

      {!loading && !error && (
        <GridComponent
          id="gridComp"
          dataSource={users}
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
            <ColumnDirective field="_id" headerText="ID" width="90" textAlign="Center" />
            <ColumnDirective field="userId" headerText="UserID" width="100" textAlign="Center" />
            <ColumnDirective field="name" headerText="Name" width="100" />
            <ColumnDirective field="phone" headerText="Phone" width="120" />
            <ColumnDirective field="memo" headerText="Memo" width="120" />
            <ColumnDirective field="validUntil" headerText="ValidUntil" width="130" textAlign="Center" />
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

export default Users;
