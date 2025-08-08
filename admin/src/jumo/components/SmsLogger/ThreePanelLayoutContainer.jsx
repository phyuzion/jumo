import React, { useEffect, useRef } from 'react';
import { GridComponent, ColumnsDirective, ColumnDirective, Resize, Sort, Page, Inject, ExcelExport } from '@syncfusion/ej2-react-grids';
import usePanelState from './utils/usePanelState';
import UserPanel from './panels/UserPanel';
import PhonePanel from './panels/PhonePanel';
import ConversationPanel from './panels/ConversationPanel';
import { exportPhoneConversations, exportUserConversations, mapConversationToRows, sanitizeFileName, sanitizeString } from './utils/ExcelExporter';

const ThreePanelLayoutContainer = ({ cache, currentColor }) => {
  const {
    // 데이터
    usersData,
    phonesData,
    smsLogsData,
    isLoading,
    // 선택 상태/활성화
    selectedUser,
    selectedPhone,
    userActiveState,
    phoneActiveState,
    // 검색
    userSearch,
    setUserSearch,
    phoneSearch,
    setPhoneSearch,
    contentSearch,
    setContentSearch,
    // 핸들러
    handleUserSelect,
    handlePhoneSelect,
    handleInactiveUserSelect,
    handleReset,
    getConversationBetween,
    // 필터 결과
    filteredUsers,
    filteredPhones,
    filteredConversations,
  } = usePanelState(cache);

  // 스크롤 컨테이너
  const userScrollContainerRef = useRef(null);
  const phoneScrollContainerRef = useRef(null);

  const scrollToSelected = (container, itemId, attr) => {
    if (!container?.current || !itemId) return;
    setTimeout(() => {
      const el = container.current.querySelector(`[data-${attr}="${itemId}"]`);
      if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }, 150);
  };

  useEffect(() => {
    if (selectedUser) scrollToSelected(userScrollContainerRef, selectedUser.id, 'user');
  }, [selectedUser]);

  useEffect(() => {
    if (selectedPhone) scrollToSelected(phoneScrollContainerRef, selectedPhone, 'phone');
  }, [selectedPhone]);

  // 사용자 선택이 바뀌어 전화번호 목록의 정렬/위치가 변할 때도, 선택된 전화번호로 스크롤
  // (요구사항: 1) 전화번호 선택 → 2) 사용자 선택 → 3) 다른 사용자 선택 시 모두 전화번호 패널 중앙으로 스크롤)
  useEffect(() => {
    if (selectedUser && selectedPhone) {
      scrollToSelected(phoneScrollContainerRef, selectedPhone, 'phone');
    }
    // filteredPhones가 변경되면 리스트 DOM이 재배치되므로 함께 의존
  }, [selectedUser, selectedPhone, filteredPhones]);

  // 숨김 그리드 (단일 대화 엑셀)
  const excelGridRef = useRef(null);

  // 단일 대화내역 저장
  const handleSingleConversationExport = () => {
    try {
      if (!excelGridRef.current || !filteredConversations || filteredConversations.length === 0) {
        alert('다운로드할 대화 내역이 없습니다.');
        return;
      }
      let fileName = 'SMS_대화내역';
      if (selectedUser) fileName += `_${sanitizeFileName(selectedUser.name || selectedUser.loginId || '')}`;
      if (selectedPhone) fileName += `_${sanitizeString(selectedPhone)}`;
      fileName += `_${new Date().toISOString().slice(0, 10)}`;

      const exportProperties = {
        fileName: `${fileName}.xlsx`,
        header: {
          headerRows: 1,
          rows: [
            { cells: [{ colSpan: 4, value: '대화 내역', style: { fontSize: 12, hAlign: 'Center', bold: true } }] },
          ]
        },
        footer: {
          footerRows: 1,
          rows: [{ cells: [{ colSpan: 4, value: '출력일: ' + new Date().toLocaleString(), style: { fontSize: 10 } }] }]
        },
        workbook: { worksheets: [{ worksheetName: '대화내역' }] },
        enableFilter: false,
        encodeHtml: false,
        exportType: 'xlsx',
        dataSource: mapConversationToRows(filteredConversations),
        columns: [
          { field: 'phoneNumber', width: 120 },
          { field: 'time', width: 150, wrapText: true },
          { field: 'smsType', width: 80 },
          { field: 'content', width: 400, wrapText: true }
        ]
      };
      excelGridRef.current.excelExport(exportProperties);
    } catch (error) {
      console.error('엑셀 내보내기 중 오류:', error);
      alert('엑셀 파일 생성 중 오류가 발생했습니다.');
    }
  };

  const handlePhoneExcelDownload = () => {
    try {
      if (!selectedPhone) {
        alert('선택된 전화번호가 없습니다.');
        return;
      }
      const phoneSmslogs = smsLogsData.filter(log => log.phoneNumber === selectedPhone);
      const userIdsWithPhone = [...new Set(phoneSmslogs.filter(log => log.userId).map(log => log.userId))];
      const usersWithPhone = usersData.filter(user => userIdsWithPhone.includes(user.id));
      if (usersWithPhone.length === 0) {
        alert('이 전화번호와 대화한 사용자가 없습니다.');
        return;
      }
      const allConversations = [];
      const userInfos = [];
      const userSummaryData = usersWithPhone.map(user => ({
        name: sanitizeString(user.name || '이름 없음'),
        phoneNumber: sanitizeString(user.phoneNumber || ''),
        id: user.id,
        messageCount: phoneSmslogs.filter(log => log.userId === user.id).length,
      }));
      usersWithPhone.forEach(user => {
        const conversation = getConversationBetween(user.id, selectedPhone) || [];
        const formatted = mapConversationToRows(conversation);
        if (formatted.length > 0) {
          allConversations.push(formatted);
          userInfos.push({ id: user.id, name: user.name || '이름 없음', phoneNumber: user.phoneNumber || '' });
        }
      });
      if (!allConversations.length) {
        alert('내보낼 대화 내역이 없습니다.');
        return;
      }
      exportPhoneConversations({
        selectedPhone,
        usersWithPhone: userInfos,
        userSummaryData,
        conversationsPerUser: allConversations,
      });
      alert('모든 대화 내역이 성공적으로 저장되었습니다.');
    } catch (e) {
      console.error(e);
      alert('엑셀 파일 생성 중 오류가 발생했습니다.');
    }
  };

  // 사용자 전체 대화내역 저장
  const handleUserExcelDownload = () => {
    try {
      if (!selectedUser) {
        alert('선택된 사용자가 없습니다.');
        return;
      }
      // 이 사용자가 대화한 전화번호 목록 추출
      const userSmsLogs = smsLogsData.filter(log => log.userId === selectedUser.id);
      const uniquePhones = [...new Set(userSmsLogs.map(log => log.phoneNumber))];
      if (!uniquePhones.length) {
        alert('이 사용자의 대화내역이 없습니다.');
        return;
      }
      // 각 전화번호별 대화 rows
      const conversationsPerPhone = uniquePhones.map(phone => mapConversationToRows(
        (smsLogsData
          .filter(log => log.userId === selectedUser.id && log.phoneNumber === phone)
          .sort((a, b) => new Date(a.time) - new Date(b.time)))
      ));
      // 요약 시트 데이터 (전화번호 | 메시지 수)
      const phoneSummaryData = uniquePhones.map((phone, idx) => ({
        phoneNumber: phone,
        messageCount: conversationsPerPhone[idx].length,
      }));
      exportUserConversations({
        selectedUserName: selectedUser.name || selectedUser.loginId,
        selectedUserPhone: selectedUser.phoneNumber || '',
        phoneNumbers: uniquePhones,
        phoneSummaryData,
        conversationsPerPhone,
      });
      alert('사용자 전체 대화내역이 저장되었습니다.');
    } catch (e) {
      console.error(e);
      alert('엑셀 파일 생성 중 오류가 발생했습니다.');
    }
  };

  return (
    <div>
      {/* 컨트롤 */}
      <div className="flex justify-between items-center mb-6">
        <div className="flex items-center">
          <button className="px-4 py-2 mr-4 text-white rounded-md" style={{ backgroundColor: currentColor }} onClick={handleReset}>리셋</button>
        </div>
        <div className="flex space-x-2">
          <button className="px-4 py-2 text-white rounded-md" style={{ backgroundColor: currentColor }} onClick={handleUserExcelDownload} disabled={!selectedUser}>사용자 전체 대화내역 저장</button>
          <button className="px-4 py-2 text-white rounded-md" style={{ backgroundColor: currentColor }} onClick={handlePhoneExcelDownload} disabled={!selectedPhone}>전화번호 전체 대화내역 저장</button>
          <button className="px-4 py-2 text-white rounded-md" style={{ backgroundColor: currentColor }} onClick={handleSingleConversationExport} disabled={!selectedUser || !selectedPhone}>단일 대화내역 저장</button>
        </div>
      </div>

      {/* 로딩 */}
      {isLoading && (
        <div className="flex justify-center items-center h-64">
          <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2" style={{ borderColor: currentColor }}></div>
        </div>
      )}

      {/* 숨김 엑셀 그리드 */}
      <div style={{ display: 'none' }}>
        <GridComponent ref={excelGridRef} dataSource={filteredConversations} allowExcelExport={true}>
          <ColumnsDirective>
            <ColumnDirective field="phoneNumber" headerText="전화번호" width="150" />
            <ColumnDirective field="time" headerText="시간" width="200" />
            <ColumnDirective field="smsType" headerText="유형" width="100" />
            <ColumnDirective field="content" headerText="내용" width="400" />
          </ColumnsDirective>
          <Inject services={[Resize, Sort, Page, ExcelExport]} />
        </GridComponent>
      </div>

      {/* 본문 */}
      {!isLoading && (
        <div className="grid grid-cols-12 gap-4">
          <div className="col-span-12 md:col-span-3">
            <UserPanel
              ref={userScrollContainerRef}
              users={filteredUsers}
              activeState={userActiveState}
              search={userSearch}
              onSearch={setUserSearch}
              onSelect={handleUserSelect}
              onSelectInactive={handleInactiveUserSelect}
              currentColor={currentColor}
            />
          </div>

          <div className="col-span-12 md:col-span-3">
            <PhonePanel
              ref={phoneScrollContainerRef}
              phones={filteredPhones}
              activeState={phoneActiveState}
              search={phoneSearch}
              onSearch={setPhoneSearch}
              onSelect={handlePhoneSelect}
              currentColor={currentColor}
            />
          </div>

          <div className="col-span-12 md:col-span-6">
            <ConversationPanel
              selectedUser={selectedUser}
              selectedPhone={selectedPhone}
              items={filteredConversations}
              search={contentSearch}
              onSearch={setContentSearch}
              currentColor={currentColor}
            />
          </div>
        </div>
      )}
    </div>
  );
};

export default ThreePanelLayoutContainer;


