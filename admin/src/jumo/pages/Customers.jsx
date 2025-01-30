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

import { GET_CUSTOMERS } from "../graphql/queries"; // ★ GET_CUSTOMERS
import { Header } from "../components";

const PAGE_SIZE = 10; // 페이지당 보여줄 고객 수
const TOTAL_COUNT = 200; // 임시 or 별도 query for real count

const Customers = () => {
  // 1) GET_CUSTOMERS
  const { loading, error, data, refetch } = useQuery(GET_CUSTOMERS, {
    variables: { start: 1, end: PAGE_SIZE },
    fetchPolicy: 'network-only',
  });

  // 2) State
  const [customers, setCustomers] = useState([]);

  // 3) data -> setCustomers + localStorage
  useEffect(() => {
    if (data && data.getCustomers) {
      setCustomers(data.getCustomers);
      localStorage.setItem('customers', JSON.stringify(data.getCustomers));
    }
  }, [data]);

  // 4) actionBegin => 서버 페이징
  const handleActionBegin = async (args) => {
    if (args.requestType === 'paging') {
      args.cancel = true;
      const currentPage = args.currentPage;
      const start = (currentPage - 1) * PAGE_SIZE + 1;
      const end = currentPage * PAGE_SIZE;

      try {
        const res = await refetch({ start, end });
        if (res.data && res.data.getCustomers) {
          setCustomers(res.data.getCustomers);
          localStorage.setItem('customers', JSON.stringify(res.data.getCustomers));
        }
      } catch (err) {
        console.error(err);
      }
    }
  };

  return (
    <div className="m-2 md:m-10 p-2 md:p-10 bg-white rounded-3xl shadow-2xl">
      <Header category="Page" title="고객 목록 (서버 페이징)" />

      {loading && <p>Loading customers...</p>}
      {error && <p className="text-red-500">Error: {error.message}</p>}

      {!loading && !error && (
        <GridComponent
          id="gridComp"
          dataSource={customers}
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
