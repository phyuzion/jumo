import * as XLSX from 'xlsx';
import { parseServerTimeToLocal } from '../../../../utils/dateUtils';

// 문자열 정제
export const sanitizeString = (str) => {
  if (!str) return '';
  let result = str.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '');
  result = result
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
  return result;
};

export const sanitizeFileName = (name) => name.replace(/[\\/:*?"<>|]/g, '_');

// Excel 시트명 정제 (금지문자 및 길이 제한 31자)
export const sanitizeSheetName = (name) => {
  const base = (name || '').toString().replace(/[:\\\/\?\*\[\]]/g, '_').trim();
  const trimmed = base.length === 0 ? 'Sheet' : base;
  return trimmed.substring(0, 31);
};

// 단일 대화 엑셀 데이터 변환
export const mapConversationToRows = (items) => {
  if (!items || !Array.isArray(items)) return [];
  return items.map(item => ({
    phoneNumber: sanitizeString(item.phoneNumber),
    time: parseServerTimeToLocal(item.time),
    smsType: item.smsType,
    content: sanitizeString(item.content || ''),
  }));
};

// 전화번호 전체 대화 내보내기 (멀티시트)
export const exportPhoneConversations = ({
  selectedPhone,
  usersWithPhone,
  userSummaryData,
  conversationsPerUser,
}) => {
  const workbook = XLSX.utils.book_new();

  // 1) 사용자 목록 시트
  const userHeaders = ['이름', '전화번호', '메시지 수'];
  const userData = userSummaryData.map(u => [u.name, u.phoneNumber, u.messageCount]);
  const userSheetData = [userHeaders, ...userData];
  const userSheet = XLSX.utils.aoa_to_sheet(userSheetData);
  userSheet['!cols'] = [{ wch: 20 }, { wch: 15 }, { wch: 10 }];
  XLSX.utils.book_append_sheet(workbook, userSheet, sanitizeSheetName('사용자 목록'));

  // 2) 사용자별 대화 시트들
  usersWithPhone.forEach((user, index) => {
    const rows = conversationsPerUser[index] || [];
    if (!rows.length) return;

    const userInfoRow1 = ['사용자 이름', '전화번호', '메시지 수', ''];
    const userInfoRow2 = [user.name || '이름 없음', user.phoneNumber || '', rows.length.toString(), ''];
    const emptyRow = ['', '', '', ''];
    const convHeaders = ['전화번호', '시간', '유형', '내용'];
    const convData = rows.map(r => [r.phoneNumber, r.time, r.smsType, r.content]);

    const sheetData = [userInfoRow1, userInfoRow2, emptyRow, convHeaders, ...convData];
    const sheet = XLSX.utils.aoa_to_sheet(sheetData);
    sheet['!cols'] = [{ wch: 15 }, { wch: 20 }, { wch: 10 }, { wch: 50 }];

    const rawName = `${index + 1}_${sanitizeString((user.name || '').toString()).substring(0, 20)}`;
    XLSX.utils.book_append_sheet(workbook, sheet, sanitizeSheetName(rawName));
  });

  const fileName = `전화번호_${sanitizeFileName(sanitizeString(selectedPhone))}_대화내역_${new Date().toISOString().slice(0, 10)}.xlsx`;
  XLSX.writeFile(workbook, fileName);
};

// 사용자 전체 대화 내보내기 (멀티시트)
export const exportUserConversations = ({
  selectedUserName,
  selectedUserPhone,
  phoneNumbers,
  phoneSummaryData,
  conversationsPerPhone,
}) => {
  const workbook = XLSX.utils.book_new();

  // 1) 전화번호 요약 시트
  const headers = ['전화번호', '메시지 수'];
  const summaryRows = phoneSummaryData.map(p => [p.phoneNumber, p.messageCount]);
  const summarySheetData = [headers, ...summaryRows];
  const summarySheet = XLSX.utils.aoa_to_sheet(summarySheetData);
  summarySheet['!cols'] = [{ wch: 18 }, { wch: 10 }];
  XLSX.utils.book_append_sheet(workbook, summarySheet, sanitizeSheetName('전화번호 목록'));

  // 2) 전화번호별 대화 시트들
  phoneNumbers.forEach((phone, index) => {
    const rows = conversationsPerPhone[index] || [];
    if (!rows.length) return;

    const header1 = ['전화번호', '메시지 수'];
    const header2 = [phone, rows.length.toString()];
    const empty = ['', ''];
    const convHeaders = ['전화번호', '시간', '유형', '내용'];
    const convData = rows.map(r => [r.phoneNumber, r.time, r.smsType, r.content]);

    const sheetData = [header1, header2, empty, convHeaders, ...convData];
    const sheet = XLSX.utils.aoa_to_sheet(sheetData);
    sheet['!cols'] = [{ wch: 15 }, { wch: 20 }, { wch: 10 }, { wch: 50 }];

    const rawName = `${index + 1}_${sanitizeString(phone).substring(0, 20)}`;
    XLSX.utils.book_append_sheet(workbook, sheet, sanitizeSheetName(rawName));
  });

  const fileName = `${sanitizeFileName(sanitizeString(selectedUserName || '사용자'))}_${sanitizeFileName(sanitizeString(selectedUserPhone || ''))}_대화내역_${new Date().toISOString().slice(0, 10)}.xlsx`;
  XLSX.writeFile(workbook, fileName);
};


