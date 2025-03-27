import React, { useState, useEffect, useRef } from 'react';
import { useMutation, useQuery } from '@apollo/client';
import { GET_ALL_GRADES, GET_ALL_REGIONS } from '../graphql/queries';
import { ADD_GRADE, ADD_REGION } from '../graphql/mutations';
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
} from '@syncfusion/ej2-react-grids';

const PAGE_SIZE = 10;

const CommonSettings = () => {
  // Grid refs
  const gradeGridRef = useRef(null);
  const regionGridRef = useRef(null);

  // Grade 관련 상태
  const [grades, setGrades] = useState([]);
  const [newGradeName, setNewGradeName] = useState('');
  const [newGradeLimit, setNewGradeLimit] = useState('');
  const [gradeStatus, setGradeStatus] = useState(null);

  // Region 관련 상태
  const [regions, setRegions] = useState([]);
  const [newRegionName, setNewRegionName] = useState('');
  const [regionStatus, setRegionStatus] = useState(null);

  // Grade 관련 쿼리/뮤테이션
  const { data: gradesData, loading: gradesLoading, error: gradesError, refetch: refetchGrades } = useQuery(GET_ALL_GRADES, {
    fetchPolicy: 'network-only',
  });

  useEffect(() => {
    if (gradesData?.getGrades) {
      setGrades(gradesData.getGrades);
      if (gradeGridRef.current) {
        gradeGridRef.current.dataSource = gradesData.getGrades;
        gradeGridRef.current.refresh();
      }
    }
  }, [gradesData]);

  const [addGrade] = useMutation(ADD_GRADE, {
    onCompleted: async () => {
      setNewGradeName('');
      setNewGradeLimit('');
      setGradeStatus('success');
      await refetchGrades();
      setTimeout(() => setGradeStatus(null), 2000);
    },
  });

  // Region 관련 쿼리/뮤테이션
  const { data: regionsData, loading: regionsLoading, error: regionsError, refetch: refetchRegions } = useQuery(GET_ALL_REGIONS, {
    fetchPolicy: 'network-only',
  });

  useEffect(() => {
    if (regionsData?.getRegions) {
      setRegions(regionsData.getRegions);
      if (regionGridRef.current) {
        regionGridRef.current.dataSource = regionsData.getRegions;
        regionGridRef.current.refresh();
      }
    }
  }, [regionsData]);

  const [addRegion] = useMutation(ADD_REGION, {
    onCompleted: async () => {
      setNewRegionName('');
      setRegionStatus('success');
      await refetchRegions();
      setTimeout(() => setRegionStatus(null), 2000);
    },
  });

  // Grade 추가 핸들러
  const handleAddGrade = async (e) => {
    e.preventDefault();
    if (!newGradeName || !newGradeLimit) return;

    try {
      await addGrade({
        variables: {
          name: newGradeName,
          limit: parseInt(newGradeLimit),
        },
      });
    } catch (error) {
      console.error('Error adding grade:', error);
      setGradeStatus('error');
      setTimeout(() => setGradeStatus(null), 2000);
    }
  };

  // Region 추가 핸들러
  const handleAddRegion = async (e) => {
    e.preventDefault();
    if (!newRegionName) return;

    try {
      await addRegion({
        variables: {
          name: newRegionName,
        },
      });
    } catch (error) {
      console.error('Error adding region:', error);
      setRegionStatus('error');
      setTimeout(() => setRegionStatus(null), 2000);
    }
  };

  if (gradesLoading || regionsLoading) return <div>Loading...</div>;
  if (gradesError) return <div>Error loading grades: {gradesError.message}</div>;
  if (regionsError) return <div>Error loading regions: {regionsError.message}</div>;

  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold mb-6">공통설정</h1>

      {/* Grade 섹션 */}
      <div className="bg-white rounded-lg shadow-md p-6 mb-8">
        <h2 className="text-xl font-semibold mb-4">등급 관리</h2>
        <form onSubmit={handleAddGrade} className="mb-4 flex gap-4 items-center">
          <input
            type="text"
            value={newGradeName}
            onChange={(e) => setNewGradeName(e.target.value)}
            placeholder="등급 이름"
            className="border p-2 rounded"
          />
          <input
            type="number"
            value={newGradeLimit}
            onChange={(e) => setNewGradeLimit(e.target.value)}
            placeholder="제한 횟수"
            className="border p-2 rounded"
          />
          <button
            type="submit"
            className="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600"
          >
            등급 추가
          </button>
          {gradeStatus === 'success' && (
            <span className="text-green-600 font-medium">[성공]</span>
          )}
          {gradeStatus === 'error' && (
            <span className="text-red-600 font-medium">[실패]</span>
          )}
        </form>

        <div className="rounded-lg overflow-hidden">
          <GridComponent
            ref={gradeGridRef}
            dataSource={grades}
            enableHover={true}
            allowPaging={true}
            pageSettings={{ pageSize: PAGE_SIZE }}
            allowSorting={true}
            allowResizing={true}
            allowAdding={false}
          >
            <ColumnsDirective>
              <ColumnDirective field="name" headerText="등급" width="150" />
              <ColumnDirective field="limit" headerText="제한 횟수" width="150" />
            </ColumnsDirective>
            <Inject services={[Resize, Sort, Page]} />
          </GridComponent>
        </div>
      </div>

      {/* Region 섹션 */}
      <div className="bg-white rounded-lg shadow-md p-6">
        <h2 className="text-xl font-semibold mb-4">지역 관리</h2>
        <form onSubmit={handleAddRegion} className="mb-4 flex gap-4 items-center">
          <input
            type="text"
            value={newRegionName}
            onChange={(e) => setNewRegionName(e.target.value)}
            placeholder="지역 이름"
            className="border p-2 rounded"
          />
          <button
            type="submit"
            className="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600"
          >
            지역 추가
          </button>
          {regionStatus === 'success' && (
            <span className="text-green-600 font-medium">[성공]</span>
          )}
          {regionStatus === 'error' && (
            <span className="text-red-600 font-medium">[실패]</span>
          )}
        </form>

        <div className="rounded-lg overflow-hidden">
          <GridComponent
            ref={regionGridRef}
            dataSource={regions}
            enableHover={true}
            allowPaging={true}
            pageSettings={{ pageSize: PAGE_SIZE }}
            allowSorting={true}
            allowResizing={true}
            allowAdding={false}
          >
            <ColumnsDirective>
              <ColumnDirective field="name" headerText="지역" width="150" />
            </ColumnsDirective>
            <Inject services={[Resize, Sort, Page]} />
          </GridComponent>
        </div>
      </div>
    </div>
  );
};

export default CommonSettings; 