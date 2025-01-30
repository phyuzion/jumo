import React from "react";
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

import { transactionsData, transactionsGrid } from "../data/dummy";
import { Header } from "../components";

const CallLogs = () => {
  return (
    <div className="m-2 md:m-10 p-2 md:p-10 bg-white rounded-3xl shadow-2xl">
      <Header category="Page" title="Transactions" />
      <GridComponent
        id="gridComp"
        dataSource={transactionsData}
        allowPaging={true}
        allowSorting={true}
        toolbar={['Search']}
      >
        <ColumnsDirective>
          {transactionsGrid.map((item, index) => (
            <ColumnDirective key={index} {...item} />
          ))}
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
    </div>
  );
};
export default CallLogs;
