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

import { GET_CUSTOMERS, GET_CUSTOMER_BY_PHONE } from "../graphql/queries";
import { Header } from "../components";

// 한 페이지 표시할 개수
const PAGE_SIZE = 10;


const Customers = () => {
  const gridRef = useRef(null);


  // 1) summaryData 로컬 스토리지에서 읽기
  const summaryDataStr = localStorage.getItem('summaryData');
  let totalCount = 200; // 디폴트
  if (summaryDataStr) {
    try {
      const parsed = JSON.parse(summaryDataStr);
      // parsed = { callLogsCount, usersCount, customersCount }
      if (parsed?.customersCount) {
        totalCount = parseInt(parsed.customersCount, 10) || 200;
      }
    } catch (err) {
      // parse 실패 시 그냥 200 유지
    }
  }


  // 1) MAIN QUERY: getCustomers
  const { loading, error, data, refetch } = useQuery(GET_CUSTOMERS, {
    variables: { start: 1, end: PAGE_SIZE },
    fetchPolicy: 'network-only',
  });

  // 2) LAZY QUERY: getCustomerByPhone
  const [getCustomerByPhoneLazy, { data: phoneData }] = useLazyQuery(GET_CUSTOMER_BY_PHONE, {
    fetchPolicy: 'network-only',
  });

  // STATE
  const [customers, setCustomers] = useState([]);
  const [searchPhone, setSearchPhone] = useState('');

  // ========== MAIN useEffect ==========
  useEffect(() => {
    if (data?.getCustomers) {
      setCustomers(data.getCustomers);
      localStorage.setItem('customers', JSON.stringify(data.getCustomers));
    }
  }, [data]);

  // ========== phoneData => setCustomers ==========
  useEffect(() => {
    if (phoneData?.getCustomerByPhone) {
      // getCustomerByPhone returns array of { customer, callLogs }
      // but we only want "customer" list to show in the grid
      const cList = phoneData.getCustomerByPhone.map((item) => item.customer);
      setCustomers(cList);
      localStorage.setItem('customers', JSON.stringify(cList));
    }
  }, [phoneData]);

  // ========== GRID REFRESH =============
  useEffect(() => {
    if (gridRef.current) {
      gridRef.current.dataSource = customers;
      gridRef.current.refresh();
    }
  }, [customers]);

  // ========== SERVER PAGING ==========
  const handleActionBegin = async (args) => {
    if (args.requestType === 'paging') {
      args.cancel = true;
      const currentPage = args.currentPage;
      const start = (currentPage - 1) * PAGE_SIZE + 1;
      const end = currentPage * PAGE_SIZE;
      try {
        const res = await refetch({ start, end });
        if (res.data?.getCustomers) {
          setCustomers(res.data.getCustomers);
          localStorage.setItem('customers', JSON.stringify(res.data.getCustomers));
        }
      } catch (err) {
        console.error(err);
      }
    }
  };

  // ========== SEARCH BUTTON ========== 
  const handleSearch = async () => {
    if (!searchPhone) {
      // empty => refetch main
      refetch({ start:1, end: PAGE_SIZE });
      return;
    }
    try {
      // if admin => no userId/phone needed
      // if user => pass userId, phone
      await getCustomerByPhoneLazy({
        variables: {
          searchPhone,
          // userId: 'U123', phone: '010-xxx' if user
        }
      });
    } catch (err) {
      alert(err.message);
    }
  };

  return (
    <div className="m-2 md:m-10 p-2 md:p-10 bg-white rounded-3xl shadow-2xl">
      <Header category="Page" title="고객 목록 (서버 페이징)" />

      <div className="flex gap-2 mb-4">
        <input
          type="text"
          placeholder="고객 전화번호 검색"
          value={searchPhone}
          onChange={(e) => setSearchPhone(e.target.value)}
          className="border p-1 rounded"
        />
        <button
          className="bg-gray-500 text-white px-4 py-2 rounded"
          onClick={handleSearch}
        >
          검색
        </button>
      </div>

      {loading && <p>Loading customers...</p>}
      {error && <p className="text-red-500">Error: {error.message}</p>}

      {!loading && !error && (
        <GridComponent
          ref={gridRef}
          id="gridComp"
          dataSource={customers}
          allowPaging={true}
          allowSorting={true}
          toolbar={['Search']}
          pageSettings={{
            pageSize: PAGE_SIZE,
            totalRecordsCount: totalCount,
            pageCount: 5,
          }}
          actionBegin={handleActionBegin}
        >
          <ColumnsDirective>
            <ColumnDirective field="_id" headerText="ID" width="100" textAlign="Center" />
            <ColumnDirective field="phone" headerText="Phone" width="120" textAlign="Center" />
            <ColumnDirective field="averageScore" headerText="AvgScore" width="100" textAlign="Center" />
            <ColumnDirective field="totalCalls" headerText="TotalCalls" width="100" textAlign="Center" />
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

export default Customers;
