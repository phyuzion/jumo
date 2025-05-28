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
SQL_FILE_PATH = "./faker_07.sql"  # SQL 파일 경로
BATCH_SIZE = 500  # 한 번에 보낼 레코드 개수 (조절 가능)
GRAPHQL_ENDPOINT = "https://jumo-vs8e.onrender.com/graphql"
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

### 2️⃣ SQL 파일 파싱해서 데이터 변환 ###
def parse_sql_file(sql_file_path):
    records = []
    # 제외 카운터 초기화
    dropped_by_missing_data = 0 # 필수 데이터 부족/형식 오류 통합
    dropped_by_phone_format = 0
    dropped_by_all_empty = 0
    processed_records = 0
    initial_row_count = 0 # 실제 데이터 행 수
    parsing_error_details = []

    sql_base_name = os.path.splitext(os.path.basename(sql_file_path))[0]
    useless_log_path = f"{sql_base_name}_useless.txt"
    error_log_path = f"{sql_base_name}_parsing_errors.log"

    try:
        with open(sql_file_path, 'r', encoding='utf-8') as f:
            content = f.read()
            
            # 모든 VALUES 그룹을 찾습니다
            values_pattern = r"\(([\d]+,\s*'[^']*',\s*'[^']*',\s*'[^']*',\s*'[^']*',\s*'[^']*',\s*'[^']*',\s*'[^']*',\s*'[^']*',\s*'[^']*')\)"
            matches = re.finditer(values_pattern, content)
            
            for match in matches:
                initial_row_count += 1
                try:
                    # 값들을 파싱합니다
                    values_str = match.group(1)
                    values = re.findall(r"'([^']*)'|(\d+)", values_str)
                    values = [v[0] if v[0] else v[1] for v in values]
                    
                    if len(values) < 10:  # contact 테이블의 모든 필드가 있는지 확인
                        dropped_by_missing_data += 1
                        error_info = {"line_num": initial_row_count, "original_row": values, "error_message": "필드 개수 부족"}
                        parsing_error_details.append(error_info)
                        continue

                    # 데이터 추출
                    phone_number = values[3].strip()  # phoneNumber 필드
                    memo = values[4].strip()         # Memo 필드
                    company_info = values[6].strip() # CompanyInfo 필드
                    updated_date_str = values[7].strip() # UpdatedDate 필드

                    # 전화번호 전처리 및 검증
                    phone_number = phone_number.strip('#')
                    phone_number = phone_number.strip("'")
                    if phone_number.startswith('*77'):
                        phone_number = phone_number[3:]
                    elif phone_number.startswith('*281'):
                        phone_number = phone_number[4:]
                    
                    if phone_number.startswith('+82'):
                        phone_number = '0' + phone_number[3:]
                    
                    if phone_number.startswith('10') and len(phone_number) == 10:
                        phone_number = '0' + phone_number

                    # 전화번호 패턴 검사
                    is_valid = False
                    if re.match(r'^01([0|1|6|7|8|9])-?([0-9]{3,4})-?([0-9]{4})$', phone_number):
                        is_valid = True
                    elif re.match(r'^(051|055|054|02|070)-?([0-9]{3,4})-?([0-9]{4})$', phone_number):
                        is_valid = True
                    elif re.match(r'^(1588|1544|1688|1644)-?([0-9]{4})$', phone_number):
                        is_valid = True

                    if not is_valid:
                        dropped_by_phone_format += 1
                        continue
                        
                    if not phone_number or phone_number == "-1":
                        dropped_by_missing_data += 1
                        continue

                    # CompanyInfo에서 유저타입과 유저네임 추출
                    company_parts = company_info.split()
                    if len(company_parts) > 1:
                        user_type = company_parts[-1]  # 마지막 단어를 유저타입으로
                        user_name = company_info  # CompanyInfo 전체를 userName으로
                    else:
                        user_type = company_info  # 한 단어면 그대로 사용
                        user_name = company_info

                    # 시간 처리
                    created_at = "2020-01-01T00:00:00+00:00"  # 기본값
                    try:
                        parsed_time = datetime.strptime(updated_date_str, '%Y-%m-%d %H:%M:%S')
                        if parsed_time:
                            kst = pytz.timezone('Asia/Seoul')
                            utc = pytz.UTC
                            if parsed_time.tzinfo is None:
                                kst_time = kst.localize(parsed_time)
                            else:
                                kst_time = parsed_time
                            utc_time = kst_time.astimezone(utc)
                            created_at = utc_time.isoformat()
                    except Exception as e:
                        print(f"⚠️ 시간 파싱 중 오류 (행 {initial_row_count}): {e}")

                    # 최종 레코드 생성
                    final_record = {
                        "name": memo if memo and memo != "-1" else None,  # Memo 필드 전체를 name으로 사용
                        "phoneNumber": phone_number,
                        "userName": user_name if user_name and user_name != "\\\\N" and user_name != "-1" else None,
                        "userType": user_type,
                        "createdAt": created_at,
                    }

                    # 필수 필드 유효성 검사
                    required_fields = ["name", "phoneNumber", "userName", "userType"]
                    is_valid = True
                    for field in required_fields:
                        if final_record[field] is None or final_record[field] == "" or final_record[field] == "-1":
                            is_valid = False
                            error_info = {
                                "line_num": initial_row_count,
                                "original_row": values,
                                "error_message": f"필수 필드 '{field}' 누락 또는 유효하지 않은 값"
                            }
                            parsing_error_details.append(error_info)
                            break
                    
                    if not is_valid:
                        dropped_by_missing_data += 1
                        continue

                    records.append(final_record)
                    processed_records += 1

                except Exception as e:
                    dropped_by_missing_data += 1
                    error_info = {"line_num": initial_row_count, "original_row": values if 'values' in locals() else None, 
                                "error_message": f"데이터 처리 중 오류: {str(e)}"}
                    parsing_error_details.append(error_info)
                    continue

    except FileNotFoundError:
        print(f"❌ SQL 파일을 찾을 수 없습니다: {sql_file_path}")
        return []
    except Exception as e:
        print(f"❌ SQL 파일 처리 중 예외 발생: {e}")
        return []

    # 파싱 결과 출력 및 저장
    final_record_count = len(records)
    total_dropped = dropped_by_missing_data + dropped_by_phone_format + dropped_by_all_empty

    print(f"🔍 SQL 파싱 결과 ({sql_file_path}):")
    print(f"  - 파일 내 총 데이터 행 수: {initial_row_count}")
    print(f"  - 최종 변환된 레코드 수: {final_record_count}")
    print(f"  - --- 제외 상세 ---")
    print(f"  - 데이터 부족/추출 오류: {dropped_by_missing_data}")
    print(f"  - 전화번호 형식 오류로 제외: {dropped_by_phone_format}")
    print(f"  - 주요 필드(name, userName) 모두 비어서 제외: {dropped_by_all_empty}")
    print(f"  - 총 제외된 레코드 수: {total_dropped}")

    # 로그 파일 저장
    try:
        with open(useless_log_path, "w", encoding='utf-8') as f:
            f.write(f"SQL 파싱 결과 ({sql_file_path}):\n")
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
            with open(sql_file_path, 'r', encoding='utf-8') as sql_file:
                content = sql_file.read()
                # INSERT INTO 문장들을 찾습니다
                insert_pattern = r"INSERT INTO `contact` \([^)]+\) VALUES\s*\((.*?)\);"
                matches = re.finditer(insert_pattern, content, re.DOTALL)
                
                for line_num, match in enumerate(matches, 1):
                    try:
                        values = re.findall(r"'([^']*)'|(\d+)", match.group(1))
                        values = [v[0] if v[0] else v[1] for v in values]
                        
                        if len(values) < 10:
                            continue
                            
                        phone_number = values[3].strip()  # phoneNumber 필드
                        memo = values[4].strip()         # Memo 필드
                        company_info = values[6].strip() # CompanyInfo 필드
                        
                        # 전화번호 형식 검사
                        phone_number = phone_number.strip('#').strip("'")
                        if phone_number.startswith('*77'):
                            phone_number = phone_number[3:]
                        elif phone_number.startswith('*281'):
                            phone_number = phone_number[4:]
                            
                        if phone_number.startswith('+82'):
                            phone_number = '0' + phone_number[3:]
                            
                        if phone_number.startswith('10') and len(phone_number) == 10:
                            phone_number = '0' + phone_number

                        # 전화번호 패턴 검사
                        is_valid = False
                        if re.match(r'^01([0|1|6|7|8|9])-?([0-9]{3,4})-?([0-9]{4})$', phone_number):
                            is_valid = True
                        elif re.match(r'^(051|055|054|02|070)-?([0-9]{3,4})-?([0-9]{4})$', phone_number):
                            is_valid = True
                        elif re.match(r'^(1588|1544|1688|1644)-?([0-9]{4})$', phone_number):
                            is_valid = True

                        if not is_valid:
                            phone_format_errors.append({
                                "line_num": line_num,
                                "data": values,
                                "phone": phone_number
                            })
                            continue
                            
                        # 주요 필드 비어있는지 검사
                        if all(value is None or value == "" or value == "-1" for value in [memo, company_info]):
                            empty_fields_data.append({
                                "line_num": line_num,
                                "data": values
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
    except IOError as e:
        print(f"❌ {useless_log_path} 파일 저장 중 오류 발생: {e}")

    if parsing_error_details:
        try:
            with open(error_log_path, "w", encoding='utf-8') as f:
                json.dump(parsing_error_details, f, ensure_ascii=False, indent=2)
            print(f"✅ 파싱 오류 데이터가 {os.path.abspath(error_log_path)} 에 저장되었습니다.")
        except IOError as e:
            print(f"❌ {error_log_path} 파일 저장 중 오류 발생: {e}")

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
        
        # 첫 번째 배치의 경우 상세 정보 출력
        if i == 0:
            print("\n첫 번째 배치의 첫 번째 레코드:")
            print(json.dumps(batch[0], ensure_ascii=False, indent=2))
            print("\n전체 mutation query:")
            print(json.dumps(mutation_query, ensure_ascii=False, indent=2))
            
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
        print(f"📂 SQL 파일({SQL_FILE_PATH}) 파싱 중...")
        sql_base_name = os.path.splitext(os.path.basename(SQL_FILE_PATH))[0]
        records = parse_sql_file(SQL_FILE_PATH)

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
                    upload_records(token, records, sql_base_name)
                    break
                elif confirm == 'n':
                    print("✋ 업로드를 취소했습니다.")
                    break
                else:
                    print("⚠️ 'y' 또는 'n'을 입력해주세요.")
        else:
            print("❌ 변환된 데이터가 없습니다. 업로드를 건너니다.")
    else:
        print("❌ 로그인 실패로 종료합니다.")
