import re
import requests
import json
import time
import os
import pytz
from datetime import datetime
import csv
import io

# 📌 설정값
CSV_FILE_PATH = "./db 5.csv"  # CSV 파일 경로
BATCH_SIZE = 2000  # 한 번에 보낼 레코드 개수 (조절 가능)
GRAPHQL_ENDPOINT = "http://localhost:4000/graphql"
ADMIN_CREDENTIALS = {
    "username": "admin",
    "password": "1234"
}
# PROGRESS_FILE = "uploaded_count.txt"  # 삭제: 파일별로 관리하도록 변경

# 📌 컬럼 키 이름 (JSON 데이터 기준) - 참고용 (직접 사용 X)
# PHONE_KEY = "phoneNumber"
# MEMO_KEY = "Memo"
# COMPANY_INFO_KEY = "CompanyInfo"
# UPDATED_DATE_KEY = "UpdatedDate"
# ACTION_TYPE_KEY = "ActionType"

# 📌 userType 매핑
# USER_TYPE_MAPPING = {
#     256: "오피",
#     257: "1인샵",
#     258: "휴게텔",
#     260: "키스방",
#     261: "아로마",
#     262: "출장",
#     263: "1인샵",
#     264: "아로마",
#     265: "스마",
#     266: "오피",
#     267: "노래방",
#     268: "키스방"
# }

### 1️⃣ 로그인해서 토큰 받아오기 ###
def get_access_token():
    login_query = {
        "query": """ 
        mutation AdminLogin($username: String!, $password: String!) {
          adminLogin(username: $username, password: $password) {
            accessToken
          }
        }
        """,
        "variables": ADMIN_CREDENTIALS
    }

    try:
        response = requests.post(GRAPHQL_ENDPOINT, json=login_query, timeout=10) # 타임아웃 추가
        response.raise_for_status() # 200 외 상태코드에 대해 예외 발생
    except requests.exceptions.RequestException as e:
        print(f"❌ 로그인 요청 실패 (네트워크 오류): {e}")
        return None
    except Exception as e:
        print(f"❌ 로그인 중 예상치 못한 오류: {e}")
        return None


    if response.status_code != 200:
        print(f"❌ 로그인 요청 실패 (HTTP {response.status_code}): {response.text}")
        return None

    try:
        data = response.json()
    except json.JSONDecodeError:
        print(f"❌ 로그인 응답 JSON 파싱 실패: {response.text}")
        return None

    if "errors" in data:
        print(f"❌ GraphQL 오류: {data['errors']}")
        return None

    try:
        return data["data"]["adminLogin"]["accessToken"]
    except (KeyError, TypeError):
        print(f"❌ 예상치 못한 응답 형식: {data}")
        return None

### 2️⃣ CSV 파일 파싱해서 데이터 변환 (수정됨) ###
def parse_csv_file(csv_file_path):
    records = []
    # 제외 카운터 초기화
    dropped_by_missing_data = 0 # 필수 데이터 부족/형식 오류 통합
    dropped_by_phone_format = 0
    dropped_by_all_empty = 0
    processed_records = 0
    initial_row_count = 0 # 실제 데이터 행 수 (헤더 없음)
    parsing_error_details = []

    csv_base_name = os.path.splitext(os.path.basename(csv_file_path))[0]
    useless_log_path = f"{csv_base_name}_useless.txt"
    error_log_path = f"{csv_base_name}_parsing_errors.log"

    try:
        with open(csv_file_path, 'r', encoding='utf-8-sig', newline='') as f:
            # <<< 표준 csv.reader 사용 >>>
            reader = csv.reader(f, quotechar='\"', quoting=csv.QUOTE_MINIMAL, skipinitialspace=True)

            # 헤더 없음으로 가정 (필요 시 헤더 건너뛰기 로직 추가)
            # header = next(reader) # 헤더 라인 건너뛰기

            for row in reader:
                initial_row_count += 1
                line_num = reader.line_num # 현재 파일 라인 번호

                # --- 데이터 추출 (인덱스 기반) ---
                try:
                    # 최소 5개 컬럼이 있는지 확인
                    if len(row) < 5:
                        dropped_by_missing_data += 1
                        error_info = { "line_num": line_num, "original_row": row, "error_message": "컬럼 개수 부족 (최소 5개 필요)"}
                        parsing_error_details.append(error_info)
                        continue

                    # 각 컬럼 데이터 추출
                    user_type = row[0].strip()          # 첫 번째 컬럼: 유저타입
                    user_name = row[1].strip()          # 두 번째 컬럼: 유저네임
                    phone_number = row[2].strip()       # 세 번째 컬럼: 폰넘버
                    name = row[3].strip()               # 네 번째 컬럼: 네임
                    updated_date_str = row[4].strip()   # 다섯 번째 컬럼: 크리에이티드앳

                except IndexError: # 혹시 모를 인덱스 에러
                    dropped_by_missing_data += 1
                    error_info = { "line_num": line_num, "original_row": row, "error_message": "데이터 추출 중 인덱스 오류"}
                    parsing_error_details.append(error_info)
                    continue
                except Exception as e: # 예상치 못한 오류
                    dropped_by_missing_data += 1
                    error_info = { "line_num": line_num, "original_row": row, "error_message": f"데이터 추출 중 오류: {e}"}
                    parsing_error_details.append(error_info)
                    continue

                # --- 전화번호 전처리 및 검증 ---
                # '#' 문자 제거 (앞뒤 모두)
                phone_number = phone_number.strip('#')
                # 작은따옴표 제거
                phone_number = phone_number.strip("'")
                # '*77' 또는 '*281' 제거
                if phone_number.startswith('*77'):
                    phone_number = phone_number[3:]
                elif phone_number.startswith('*281'):
                    phone_number = phone_number[4:]
                
                # 해외번호(+82)를 국내번호(0)로 변환
                if phone_number.startswith('+82'):
                    phone_number = '0' + phone_number[3:]
                
                if phone_number.startswith('10') and len(phone_number) == 10:
                    phone_number = '0' + phone_number

                # 전화번호 패턴 검사
                is_valid = False
                
                # 1. 일반 휴대폰 번호 (010, 011, 016, 017, 018, 019)
                if re.match(r'^01([0|1|6|7|8|9])-?([0-9]{3,4})-?([0-9]{4})$', phone_number):
                    is_valid = True
                
                # 2. 지역번호 (051, 055, 054, 02, 070) + 7자리
                elif re.match(r'^(051|055|054|02|070)-?([0-9]{3,4})-?([0-9]{4})$', phone_number):
                    is_valid = True
                
                # 3. 특수번호 (1588, 1544, 1688, 1644) + 4자리
                elif re.match(r'^(1588|1544|1688|1644)-?([0-9]{4})$', phone_number):
                    is_valid = True

                if not is_valid:
                    dropped_by_phone_format += 1
                    continue
                    
                if not phone_number or phone_number == "-1": # 전화번호 필수 체크
                    dropped_by_missing_data += 1 # 통합 카운트
                    continue

                # --- 시간 처리 (기존 로직 유지) ---
                created_at = "2020-01-01T00:00:00+00:00" # 기본값
                parsed_time = None
                formats_to_try = ['%Y-%m-%d %H:%M:%S', '%Y.%m.%d %H:%M']
                for fmt in formats_to_try:
                    try:
                        parsed_time = datetime.strptime(updated_date_str, fmt)
                        if parsed_time: break
                    except ValueError: continue
                    except Exception as e: print(f"⚠️ 시간 파싱 중 오류 (라인 {line_num}, 형식: {fmt}): {e}"); continue
                if parsed_time:
                    try:
                        kst = pytz.timezone('Asia/Seoul'); utc = pytz.UTC
                        if parsed_time.tzinfo is None or parsed_time.tzinfo.utcoffset(parsed_time) is None:
                            kst_time = kst.localize(parsed_time)
                        else: kst_time = parsed_time
                        utc_time = kst_time.astimezone(utc)
                        created_at = utc_time.isoformat()
                    except Exception as tz_e: print(f"⚠️ 타임존 변환 중 오류 (라인 {line_num}): {tz_e}"); created_at = "2020-01-01T00:00:00+00:00"

                # --- 최종 레코드 생성 ---
                final_record = {
                    "name": name if name and name != "-1" else None,         # 네 번째 컬럼 -> name
                    "phoneNumber": phone_number,                           # 세 번째 컬럼
                    "userName": user_name if user_name and user_name != "\\\\N" and user_name != "-1" else None, # 두 번째 컬럼 -> userName
                    "userType": user_type,                                  # 첫 번째 컬럼 -> userType
                    "createdAt": created_at,
                }

                # 디버깅을 위한 로그 추가
                # print(f"Debug - Record created: userType={user_type}, userName={user_name}, name={name}")

                # 빈 레코드 필터링 (name과 userName 모두 비어있을 경우 제외)
                if all(value is None or value == "" for value in [final_record["name"], final_record["userName"]]):
                     dropped_by_all_empty += 1
                     continue

                records.append(final_record)
                processed_records += 1 # 최종 레코드 추가 시 카운트

    except FileNotFoundError: print(f"❌ CSV 파일을 찾을 수 없습니다: {csv_file_path}"); return []
    except Exception as e: print(f"❌ CSV 파일 처리 중 예외 발생 (라인 {line_num if 'line_num' in locals() else 'N/A'} 근처): {e}"); pass

    # --- 파싱 완료 후 결과 출력 및 저장 (수정됨) ---
    final_record_count = len(records)
    total_dropped = dropped_by_missing_data + dropped_by_phone_format + dropped_by_all_empty

    print(f"🔍 CSV 파싱 결과 ({csv_file_path}):")
    print(f"  - 파일 내 총 데이터 행 수: {initial_row_count}")
    print(f"  - 최종 변환된 레코드 수: {final_record_count}")
    print(f"  - --- 제외 상세 ---")
    print(f"  - 데이터 부족/추출 오류: {dropped_by_missing_data}")
    print(f"  - 전화번호 형식 오류로 제외: {dropped_by_phone_format}")
    print(f"  - 주요 필드(name, userName) 모두 비어서 제외: {dropped_by_all_empty}")
    print(f"  - 총 제외된 레코드 수: {total_dropped}")

    print(f"💾 제외 카운터 값과 상세 정보를 {useless_log_path} 에 저장 시도 중...")
    try:
        with open(useless_log_path, "w", encoding='utf-8') as f:
            f.write(f"CSV 파싱 결과 ({csv_file_path}):\n")
            f.write(f"  - 파일 내 총 데이터 행 수: {initial_row_count}\n")
            f.write(f"  - 최종 변환된 레코드 수: {final_record_count}\n")
            f.write(f"  - --- 제외 상세 ---\n")
            f.write(f"  - 데이터 부족/추출 오류: {dropped_by_missing_data}\n")
            f.write(f"  - 전화번호 형식 오류로 제외: {dropped_by_phone_format}\n")
            f.write(f"  - 주요 필드(name, userName) 모두 비어서 제외: {dropped_by_all_empty}\n")
            f.write(f"  - 총 제외된 레코드 수: {total_dropped}\n\n")
            
            # 제외된 데이터 상세 정보 저장
            f.write("=== 제외된 데이터 상세 정보 ===\n\n")
            
            # 데이터 부족/추출 오류 데이터
            if parsing_error_details:
                f.write("1. 데이터 부족/추출 오류 데이터:\n")
                for error in parsing_error_details:
                    f.write(f"  - 라인 {error['line_num']}: {error['error_message']}\n")
                    f.write(f"    원본 데이터: {error['original_row']}\n\n")
            
            # 전화번호 형식 오류 데이터 저장을 위한 리스트
            phone_format_errors = []
            
            # 주요 필드 비어있는 데이터 저장을 위한 리스트
            empty_fields_data = []
            
            # 원본 데이터를 다시 읽어서 제외된 데이터 상세 정보 수집
            with open(csv_file_path, 'r', encoding='utf-8-sig', newline='') as csv_file:
                reader = csv.reader(csv_file, quotechar='\"', quoting=csv.QUOTE_MINIMAL, skipinitialspace=True)
                for line_num, row in enumerate(reader, 1):
                    try:
                        if len(row) < 5:
                            continue
                            
                        user_type = row[0].strip()
                        user_name = row[1].strip()
                        phone_number = row[2].strip().strip('#')  # '#' 문자 제거 (앞뒤 모두)
                        name = row[3].strip()
                        
                        # 전화번호 형식 검사
                        phone_number = row[2].strip().strip('#')  # '#' 문자 제거 (앞뒤 모두)
                        phone_number = phone_number.strip("'")    # 작은따옴표 제거
                        # '*77' 또는 '*281' 제거
                        if phone_number.startswith('*77'):
                            phone_number = phone_number[3:]
                        elif phone_number.startswith('*281'):
                            phone_number = phone_number[4:]
                            
                        # 해외번호(+82)를 국내번호(0)로 변환
                        if phone_number.startswith('+82'):
                            phone_number = '0' + phone_number[3:]
                            
                        if phone_number.startswith('10') and len(phone_number) == 10:
                            phone_number = '0' + phone_number

                        # 전화번호 패턴 검사
                        is_valid = False
                        
                        # 1. 일반 휴대폰 번호 (010, 011, 016, 017, 018, 019)
                        if re.match(r'^01([0|1|6|7|8|9])-?([0-9]{3,4})-?([0-9]{4})$', phone_number):
                            is_valid = True
                        
                        # 2. 지역번호 (051, 055, 054, 02, 070) + 7자리
                        elif re.match(r'^(051|055|054|02|070)-?([0-9]{3,4})-?([0-9]{4})$', phone_number):
                            is_valid = True
                        
                        # 3. 특수번호 (1588, 1544, 1688, 1644) + 4자리
                        elif re.match(r'^(1588|1544|1688|1644)-?([0-9]{4})$', phone_number):
                            is_valid = True

                        if not is_valid:
                            phone_format_errors.append({
                                "line_num": line_num,
                                "data": row,
                                "phone": phone_number
                            })
                            continue
                            
                        # 주요 필드 비어있는지 검사
                        if all(value is None or value == "" or value == "-1" for value in [name, user_name]):
                            empty_fields_data.append({
                                "line_num": line_num,
                                "data": row
                            })
                            
                    except Exception:
                        continue
            
            # 전화번호 형식 오류 데이터 저장
            if phone_format_errors:
                f.write("\n2. 전화번호 형식 오류 데이터:\n")
                for error in phone_format_errors:
                    f.write(f"  - 라인 {error['line_num']}: 잘못된 전화번호 형식 ({error['phone']})\n")
                    f.write(f"    원본 데이터: {error['data']}\n\n")
            
            # 주요 필드 비어있는 데이터 저장
            if empty_fields_data:
                f.write("\n3. 주요 필드(name, userName) 모두 비어있는 데이터:\n")
                for data in empty_fields_data:
                    f.write(f"  - 라인 {data['line_num']}:\n")
                    f.write(f"    원본 데이터: {data['data']}\n\n")
            
            f.flush()
        print(f"✅ 제외된 데이터 상세 정보가 {os.path.abspath(useless_log_path)} 에 저장되었습니다.")
    except IOError as e: print(f"❌ {useless_log_path} 파일 저장 중 오류 발생: {e}")

    if parsing_error_details:
        print(f"💾 파싱 오류 데이터({len(parsing_error_details)}건)를 {error_log_path} 에 저장 중...")
        try:
            with open(error_log_path, "w", encoding='utf-8') as f:
                json.dump(parsing_error_details, f, ensure_ascii=False, indent=2)
            print(f"✅ 파싱 오류 데이터가 {os.path.abspath(error_log_path)} 에 저장되었습니다.")
        except IOError as e: print(f"❌ {error_log_path} 파일 저장 중 오류 발생: {e}")
        except Exception as e: print(f"❌ 파싱 오류 로그 저장 중 예외 발생: {e}")
    else:
        print(f"ℹ️ 데이터 부족 또는 추출 오류 등으로 제외된 데이터는 없습니다.")

    return records

### 3️⃣ 업로드된 개수를 저장하는 함수 (중간 재시작 가능) ###
def save_progress(uploaded_count, base_name):
    progress_file_path = f"{base_name}_uploaded_count.txt"
    try:
        with open(progress_file_path, "w") as f:
            f.write(str(uploaded_count))
    except IOError as e:
        print(f"❌ 진행 상태 파일({progress_file_path}) 저장 중 오류 발생: {e}")

def load_progress(base_name):
    progress_file_path = f"{base_name}_uploaded_count.txt"
    if os.path.exists(progress_file_path):
        try:
            with open(progress_file_path, "r") as f:
                content = f.read().strip()
                if content:
                    return int(content)
                else:
                    print(f"⚠️ 진행 상태 파일({progress_file_path})이 비어있습니다. 0부터 시작합니다.")
                    return 0
        except ValueError:
            print(f"❌ 진행 상태 파일({progress_file_path})의 내용을 숫자로 변환할 수 없습니다. 0부터 시작합니다.")
            return 0
        except IOError as e:
            print(f"❌ 진행 상태 파일({progress_file_path}) 읽기 중 오류 발생: {e}. 0부터 시작합니다.")
            return 0
    return 0

### 3.5️⃣ 업로드 오류 로깅 함수 ###
def log_upload_error(base_name, batch_data, error_response_text, batch_start_index):
    error_log_path = f"{base_name}_upload_errors.log"
    timestamp = datetime.now(pytz.timezone('Asia/Seoul')).isoformat()
    problematic_records = []
    try:
        error_json = json.loads(error_response_text)
        if isinstance(error_json.get('errors'), list):
            for error in error_json['errors']:
                if isinstance(error.get('message'), str):
                    match = re.search(r'records\\\[(\d+)\\\]\.(\w+)', error['message'])
                    if match:
                        try:
                            index_in_batch = int(match.group(1))
                            field_name = match.group(2)
                            if 0 <= index_in_batch < len(batch_data):
                                problematic_records.append({
                                    "index_in_batch": index_in_batch,
                                    "field_name": field_name,
                                    "record_data": batch_data[index_in_batch]
                                })
                        except (ValueError, IndexError): pass
    except json.JSONDecodeError: pass
    error_entry = {
        "timestamp": timestamp,
        "batch_start_index": batch_start_index,
        "error_response_text": error_response_text,
        "identified_problematic_records": problematic_records,
        "full_failed_batch_data": batch_data
    }
    try:
        with open(error_log_path, "a", encoding='utf-8') as f:
            f.write(json.dumps(error_entry, ensure_ascii=False, indent=2) + "\n")
        print(f"🔴 업로드 오류 발생: 상세 정보가 {error_log_path} 에 기록되었습니다.")
    except IOError as e: print(f"❌ 업로드 오류 로그 파일({error_log_path}) 쓰기 중 오류 발생: {e}")
    except Exception as e: print(f"❌ 업로드 오류 로그 저장 중 예외 발생: {e}")

### 4️⃣ 데이터 업로드 (배치 처리 + 재시도) ###
def upload_records(access_token, records, base_name):
    headers = { "Authorization": f"Bearer {access_token}", "Content-Type": "application/json" }
    mutation_query = { "query": """ 
        mutation UpsertPhoneRecords($records: [PhoneRecordInput!]!) {
          upsertPhoneRecords(records: $records)
        }
        """ }
    total_records = len(records)
    uploaded_count = load_progress(base_name)
    print(f"📤 총 {total_records}개의 레코드 중 {uploaded_count}개까지 업로드됨. 이어서 진행.")
    success = False # 최종 성공 여부 플래그

    for i in range(uploaded_count, total_records, BATCH_SIZE):
        batch = records[i:i + BATCH_SIZE]
        mutation_query["variables"] = {"records": batch}
        retries = 3
        batch_success = False # 배치 성공 여부
        response_text = ""
        while retries > 0:
            try:
                response = requests.post(GRAPHQL_ENDPOINT, json=mutation_query, headers=headers, timeout=30)
                response_text = response.text
                response.raise_for_status()
                response_json = response.json()
                if "errors" in response_json:
                    print(f"❌ GraphQL 오류 발생: {response_text}")
                    retries -= 1
                    if retries > 0: time.sleep(2)
                    continue
                else:
                     uploaded_count = i + len(batch)
                     save_progress(uploaded_count, base_name)
                     print(f"✅ {uploaded_count} / {total_records} 개 완료 ({uploaded_count/total_records*100:.2f}%)")
                     batch_success = True
                     success = True # 한 배치라도 성공하면 전체 성공 플래그 업데이트
                     break
            except requests.exceptions.Timeout:
                print(f"❌ 요청 시간 초과 (재시도 {4 - retries}/3)"); response_text = "Request Timeout"
                retries -= 1; time.sleep(5)
            except requests.exceptions.RequestException as e:
                print(f"❌ 네트워크 오류 발생 (재시도 {4 - retries}/3): {e}"); response_text = str(e)
                retries -= 1; time.sleep(5)
            except json.JSONDecodeError:
                print(f"❌ 응답 JSON 파싱 실패 (재시도 {4-retries}/3): {response_text}"); retries -= 1; time.sleep(2)
            except Exception as e:
                print(f"❌ 업로드 중 예상치 못한 오류 (재시도 {4-retries}/3): {e}"); response_text = str(e)
                retries -= 1; time.sleep(2)

        if not batch_success:
            log_upload_error(base_name, batch, response_text, i)
            print(f"🔴 배치 {i} ~ {i+len(batch)-1} 업로드 최종 실패. 다음 배치로 진행.")
            success = False # 한 배치라도 실패하면 전체 성공 플래그 false

    error_log_path = f"{base_name}_upload_errors.log"
    if os.path.exists(error_log_path):
        try:
            with open(error_log_path, 'rb+') as f:
                f.seek(0, os.SEEK_END)
                if f.tell() > 3:
                    f.seek(-3, os.SEEK_END)
                    if f.read(3) == b'\n,\n':
                        f.seek(-3, os.SEEK_END)
                        f.truncate()
                    else:
                         f.seek(-2, os.SEEK_END)
                         if f.read(2) == b',\n':
                              f.seek(-2, os.SEEK_END)
                              f.truncate()
            with open(error_log_path, 'r', encoding='utf-8') as f:
                content = f.read().strip()
                if content:
                     error_entries_str = '[' + content.rstrip(',') + ']'
                     with open(error_log_path, 'w', encoding='utf-8') as wf:
                          parsed_entries = json.loads(error_entries_str)
                          json.dump(parsed_entries, wf, ensure_ascii=False, indent=2)
                     print(f"ℹ️ 업로드 오류 로그 파일({error_log_path})을 JSON 배열 형식으로 업데이트했습니다.")
                else: print(f"ℹ️ 업로드 오류 로그 파일({error_log_path})이 비어있어 후처리를 건너니다.")
        except Exception as e: print(f"⚠️ 업로드 오류 로그 파일({error_log_path}) 후처리 중 오류: {e}")

    print("✅ 모든 데이터 업로드 완료!" if success else "⚠️ 업로드 중 일부 배치가 실패했습니다.")

### 실행 ###
if __name__ == "__main__":
    print("🔑 로그인 중...")
    token = get_access_token()

    if token:
        print(f"📂 CSV 파일({CSV_FILE_PATH}) 파싱 중...")
        csv_base_name = os.path.splitext(os.path.basename(CSV_FILE_PATH))[0]
        records = parse_csv_file(CSV_FILE_PATH)

        if records:
            print(f"📄 {len(records)}개의 데이터 변환 완료.")
            print("\n✨ 첫 번째 레코드 미리보기:")
            try:
                print(json.dumps(records[0], indent=2, ensure_ascii=False))
            except Exception as e:
                 print(f"첫 번째 레코드 표시에 오류 발생: {e}")
                 print(records[0])

            while True:
                confirm = input("\n❓ 업로드를 시작하시겠습니까? (y/n): ").lower().strip()
                if confirm == 'y':
                    print("🚀 업로드를 시작합니다...")
                    upload_records(token, records, csv_base_name)
                    break
                elif confirm == 'n':
                    print("✋ 업로드를 취소했습니다.")
                    break
                else: print("⚠️ 'y' 또는 'n'을 입력해주세요.")
        else: print("❌ 변환된 데이터가 없습니다. 업로드를 건너니다.")
    else: print("❌ 로그인 실패로 종료합니다.")
