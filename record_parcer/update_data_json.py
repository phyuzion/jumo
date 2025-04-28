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
JSON_FILE_PATH = "./json_02.json"  # JSON 파일 경로
BATCH_SIZE = 1000  # 한 번에 보낼 레코드 개수 (조절 가능)
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
USER_TYPE_MAPPING = {
    256: "오피",
    257: "1인샵",
    258: "휴게텔",
    260: "키스방",
    261: "아로마",
    262: "출장",
    263: "1인샵",
    264: "아로마",
    265: "스마",
    266: "오피",
    267: "노래방",
    268: "키스방"
}

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

### 2️⃣ JSON 파일 파싱해서 데이터 변환 ###
def parse_json_file(json_file_path):
    records = []
    # 제외된 레코드 카운터 초기화
    dropped_by_missing_key = 0
    dropped_by_phone_format = 0
    dropped_by_phone_empty_or_minus_one = 0
    dropped_by_all_empty = 0
    processed_records = 0
    initial_record_count = 0
    parsing_error_details = [] # 파싱 오류 상세 데이터 저장 리스트

    # --- 로그 파일명 생성을 위한 기본 이름 추출 ---
    json_base_name = os.path.splitext(os.path.basename(json_file_path))[0]
    useless_log_path = f"{json_base_name}_useless.txt"
    error_log_path = f"{json_base_name}_parsing_errors.log"
    # -----------------------------------------

    total_records_in_file = 0 # 초기화

    try:
        with open(json_file_path, 'r', encoding='utf-8') as f:
            json_data = json.load(f) # JSON 파일 읽기

        # JSON 구조에서 실제 데이터 리스트 찾기
        data_list = []
        if isinstance(json_data, list):
             # 최상위가 리스트인 경우, 테이블 정보 객체 찾기
            for item in json_data:
                if isinstance(item, dict) and item.get("type") == "table" and item.get("name") == "contact":
                    if isinstance(item.get("data"), list):
                        data_list = item["data"]
                        break
            if not data_list and len(json_data) > 3 and isinstance(json_data[3], dict) and isinstance(json_data[3].get("data"), list):
                 # PHPMyAdmin export plugin의 특정 구조 대응 (헤더 3개 후 테이블 객체)
                 data_list = json_data[3]["data"]

        elif isinstance(json_data, dict) and isinstance(json_data.get("data"), list):
             # 최상위가 딕셔너리이고 'data' 키가 리스트인 경우
             data_list = json_data["data"]

        if not data_list:
             print(f"❌ JSON 파일({json_file_path})에서 'receive_contact' 테이블 데이터를 찾을 수 없습니다.")
             return []

        initial_record_count = len(data_list) # 전체 레코드 수

        # 레코드 딕셔너리 리스트 순회
        for idx, record_dict in enumerate(data_list):
            if not isinstance(record_dict, dict):
                 dropped_by_missing_key += 1 # Count as error
                 error_info = {
                     "index": idx,
                     "original_record": record_dict,
                     "error_message": "Record is not a dictionary.",
                 }
                 parsing_error_details.append(error_info)
                 continue

            # --- 필수 키 존재 및 데이터 추출 ---
            try:
                # 키를 사용하여 값 추출 (get 사용으로 안정성 확보)
                phone_number = record_dict.get("phoneNumber", "").strip()
                memo = record_dict.get("Memo", "").strip()
                company_info = record_dict.get("CompanyInfo", "").strip()
                updated_date_str = record_dict.get("UpdatedDate", "").strip()
                action_type_str = record_dict.get("ActionType", "").strip()

                # 필수 키 phoneNumber 존재 여부 확인
                # if "phoneNumber" not in record_dict: # .get 사용으로 이 검사는 생략 가능
                #      raise KeyError("Missing 'phoneNumber' key")

            except KeyError as e: # 실제로는 .get 때문에 발생 안 함
                dropped_by_missing_key += 1
                error_info = {
                    "index": idx,
                    "original_record": record_dict,
                    "error_message": f"Missing required key: {e}",
                }
                parsing_error_details.append(error_info)
                continue

            processed_records += 1 # 유효하게 키 접근 성공한 레코드 수

            # --- 이하 기존 검증 로직 적용 (값 접근 방식 변경) ---
            # 전화번호 형식 검증
            if not re.match(r'^01([0|1|6|7|8|9])-?([0-9]{3,4})-?([0-9]{4})$', phone_number):
                dropped_by_phone_format += 1
                continue

            # 필수 필드 검증 (비어있거나 "-1")
            if not phone_number or phone_number == "-1":
                dropped_by_phone_empty_or_minus_one += 1
                continue

            # userType 변환
            user_type = "일반" # 기본값
            try:
                # action_type_str이 유효한 숫자인지 먼저 확인
                if action_type_str and action_type_str != "-1" and action_type_str != "null":
                    user_type_num = int(action_type_str)
                    user_type = USER_TYPE_MAPPING.get(user_type_num, "일반")
            except ValueError:
                # 숫자로 변환 불가 시 기본값 "일반" 유지
                pass

            # 시간 처리
            created_at = "2020-01-01T00:00:00+00:00" # 기본값
            try:
                # 시간 형식이 맞는 경우 UTC로 변환
                if re.match(r'\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}', updated_date_str):
                    kst = pytz.timezone('Asia/Seoul')
                    utc = pytz.UTC
                    kst_time = datetime.strptime(updated_date_str, '%Y-%m-%d %H:%M:%S')
                    # Check if timezone-aware; if not, localize
                    if kst_time.tzinfo is None or kst_time.tzinfo.utcoffset(kst_time) is None:
                        kst_time = kst.localize(kst_time)
                    utc_time = kst_time.astimezone(utc)
                    created_at = utc_time.isoformat()
                # else: use default
            except Exception as e:
                 # Keep default on error
                 pass

            # 최종 레코드 생성 (GraphQL 스키마에 맞는 키 이름 사용)
            final_record = {
                "name": memo if memo != "-1" else None,
                "phoneNumber": phone_number,
                "userName": company_info if company_info != "-1" else None,
                "userType": user_type,
                "createdAt": created_at
            }

            # 빈 레코드 필터링 (name, phoneNumber, userName 모두 비어있거나 None)
            if all(value is None or value == "" for value in [final_record["name"], final_record["phoneNumber"], final_record["userName"]]):
                dropped_by_all_empty += 1
                continue

            records.append(final_record)

    except FileNotFoundError:
        print(f"❌ JSON 파일을 찾을 수 없습니다: {json_file_path}")
        return []
    except json.JSONDecodeError as e:
        print(f"❌ JSON 파일 파싱 오류: {e}")
        return []
    except Exception as e:
        print(f"❌ JSON 파일 처리 중 예외 발생: {e}")
        pass # 아래 finally 블록에서 처리

    # --- 파싱 완료 후 결과 출력 및 저장 ---
    final_record_count = len(records)
    total_dropped = dropped_by_missing_key + dropped_by_phone_format + dropped_by_phone_empty_or_minus_one + dropped_by_all_empty

    print(f"🔍 JSON 파싱 결과 ({json_file_path}):")
    print(f"  - 파일 내 총 레코드 수 (추정): {initial_record_count}")
    print(f"  - 최종 변환된 레코드 수: {final_record_count}")
    print(f"  - --- 제외 상세 ---")
    print(f"  - 필수 키 누락 또는 형식 오류: {dropped_by_missing_key}")
    print(f"  - 전화번호 형식 오류로 제외: {dropped_by_phone_format}")
    print(f"  - 전화번호 비어있거나 '-1'으로 제외: {dropped_by_phone_empty_or_minus_one}")
    print(f"  - 주요 필드(name, userName) 모두 비어서 제외: {dropped_by_all_empty}")
    print(f"  - 총 제외된 레코드 수: {total_dropped}")


    # useless.txt 파일에 결과 저장
    print(f"💾 제외 카운터 값을 {useless_log_path} 에 저장 시도 중...")
    try:
        with open(useless_log_path, "w", encoding='utf-8') as f:
            f.write(f"JSON 파싱 결과 ({json_file_path}):\\n")
            f.write(f"  - 파일 내 총 레코드 수 (추정): {initial_record_count}\\n")
            f.write(f"  - 최종 변환된 레코드 수: {final_record_count}\\n")
            f.write(f"  - --- 제외 상세 ---\\n")
            f.write(f"  - 필수 키 누락 또는 형식 오류: {dropped_by_missing_key}\\n")
            f.write(f"  - 전화번호 형식 오류로 제외: {dropped_by_phone_format}\\n")
            f.write(f"  - 전화번호 비어있거나 '-1'으로 제외: {dropped_by_phone_empty_or_minus_one}\\n")
            f.write(f"  - 주요 필드(name, userName) 모두 비어서 제외: {dropped_by_all_empty}\\n")
            f.write(f"  - 총 제외된 레코드 수: {total_dropped}\\n")
            f.flush()
        print(f"✅ 제외 카운터 값이 {os.path.abspath(useless_log_path)} 에 저장되었습니다.")
    except IOError as e:
        print(f"❌ {useless_log_path} 파일 저장 중 오류 발생: {e}")

    # 파싱 오류 로그 저장
    if parsing_error_details:
        print(f"💾 파싱 오류 데이터({len(parsing_error_details)}건)를 {error_log_path} 에 저장 중...")
        try:
            with open(error_log_path, "w", encoding='utf-8') as f:
                json.dump(parsing_error_details, f, ensure_ascii=False, indent=2)
            print(f"✅ 파싱 오류 데이터가 {os.path.abspath(error_log_path)} 에 저장되었습니다.")
        except IOError as e:
            print(f"❌ {error_log_path} 파일 저장 중 오류 발생: {e}")
        except Exception as e:
             print(f"❌ 파싱 오류 로그 저장 중 예외 발생: {e}")
    else:
        print(f"ℹ️ 필수 키 누락 또는 형식 오류로 제외된 데이터는 없습니다.")

    return records

### 3️⃣ 업로드된 개수를 저장하는 함수 (중간 재시작 가능) ###
def save_progress(uploaded_count, base_name): # sql_base_name -> base_name
    progress_file_path = f"{base_name}_uploaded_count.txt" # 변수명 변경 반영
    try:
        with open(progress_file_path, "w") as f:
            f.write(str(uploaded_count))
    except IOError as e:
        print(f"❌ 진행 상태 파일({progress_file_path}) 저장 중 오류 발생: {e}")

def load_progress(base_name): # sql_base_name -> base_name
    progress_file_path = f"{base_name}_uploaded_count.txt" # 변수명 변경 반영
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
def log_upload_error(base_name, batch_data, error_response_text, batch_start_index): # sql_base_name -> base_name
    error_log_path = f"{base_name}_upload_errors.log" # 변수명 변경 반영
    timestamp = datetime.now(pytz.timezone('Asia/Seoul')).isoformat()

    problematic_records = []
    try:
        error_json = json.loads(error_response_text)
        if isinstance(error_json.get('errors'), list):
            for error in error_json['errors']:
                if isinstance(error.get('message'), str):
                    match = re.search(r'records\\\[(\d+)\\\]\.(\w+)', error['message']) # 필드 이름도 캡처
                    if match:
                        try:
                            index_in_batch = int(match.group(1))
                            field_name = match.group(2) # 문제 필드 이름
                            if 0 <= index_in_batch < len(batch_data):
                                problematic_records.append({
                                    "index_in_batch": index_in_batch,
                                    "field_name": field_name, # 필드 이름 추가
                                    "record_data": batch_data[index_in_batch]
                                })
                        except (ValueError, IndexError):
                            pass
    except json.JSONDecodeError:
        pass

    error_entry = {
        "timestamp": timestamp,
        "batch_start_index": batch_start_index,
        "error_response_text": error_response_text,
        "identified_problematic_records": problematic_records,
        "full_failed_batch_data": batch_data
    }

    try:
        with open(error_log_path, "a", encoding='utf-8') as f:
            f.write(json.dumps(error_entry, ensure_ascii=False, indent=2) + "\\n,\\n") # 구분자 명확히 (쉼표와 개행 추가)
        print(f"🔴 업로드 오류 발생: 상세 정보가 {error_log_path} 에 기록되었습니다.")
    except IOError as e:
        print(f"❌ 업로드 오류 로그 파일({error_log_path}) 쓰기 중 오류 발생: {e}")
    except Exception as e:
        print(f"❌ 업로드 오류 로그 저장 중 예외 발생: {e}")


### 4️⃣ 데이터 업로드 (배치 처리 + 재시도) ###
def upload_records(access_token, records, base_name): # sql_base_name -> base_name
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }

    mutation_query = {
        "query": """ 
        mutation UpsertPhoneRecords($records: [PhoneRecordInput!]!) {
          upsertPhoneRecords(records: $records)
        }
        """
    }

    total_records = len(records)
    uploaded_count = load_progress(base_name) # 변수명 변경 반영
    print(f"📤 총 {total_records}개의 레코드 중 {uploaded_count}개까지 업로드됨. 이어서 진행.")

    for i in range(uploaded_count, total_records, BATCH_SIZE):
        batch = records[i:i + BATCH_SIZE]
        mutation_query["variables"] = {"records": batch}

        retries = 3
        success = False
        response_text = "" # 마지막 응답 저장용
        while retries > 0:
            try:
                response = requests.post(GRAPHQL_ENDPOINT, json=mutation_query, headers=headers, timeout=30) # 타임아웃 증가
                response_text = response.text # 마지막 응답 저장
                response.raise_for_status() # HTTP 오류 체크

                # GraphQL 오류 체크 (응답 본문에 errors 키가 있는지)
                response_json = response.json()
                if "errors" in response_json:
                    # GraphQL 오류가 있으면 실패로 간주하고 로그 기록 위해 루프 탈출 준비
                    print(f"❌ GraphQL 오류 발생: {response_text}")
                    retries -= 1
                    if retries > 0:
                        time.sleep(2)
                    continue # 다음 재시도
                else:
                     # 성공 시
                    uploaded_count = i + len(batch)
                    save_progress(uploaded_count, base_name) # 변수명 변경 반영
                    print(f"✅ {uploaded_count} / {total_records} 개 완료 ({uploaded_count/total_records*100:.2f}%)")
                    success = True
                    break # 성공했으므로 재시도 루프 탈출

            except requests.exceptions.Timeout:
                print(f"❌ 요청 시간 초과 (재시도 {4 - retries}/3)")
                response_text = "Request Timeout"
                retries -= 1
                if retries > 0: time.sleep(5) # 타임아웃 시 더 길게 대기
            except requests.exceptions.RequestException as e:
                print(f"❌ 네트워크 오류 발생 (재시도 {4 - retries}/3): {e}")
                response_text = str(e)
                retries -= 1
                if retries > 0: time.sleep(5) # 네트워크 오류 시 더 길게 대기
            except json.JSONDecodeError:
                print(f"❌ 응답 JSON 파싱 실패 (재시도 {4-retries}/3): {response_text}")
                retries -= 1
                if retries > 0: time.sleep(2)
            except Exception as e:
                print(f"❌ 업로드 중 예상치 못한 오류 (재시도 {4-retries}/3): {e}")
                response_text = str(e)
                retries -= 1
                if retries > 0: time.sleep(2)


        # 모든 재시도 실패 시 로그 기록
        if not success:
            log_upload_error(base_name, batch, response_text, i) # 변수명 변경 반영
            print(f"🔴 배치 {i} ~ {i+len(batch)-1} 업로드 최종 실패. 다음 배치로 진행.")

    # 업로드 루프 완료 후, 로그 파일 후처리
    error_log_path = f"{base_name}_upload_errors.log" # 변수명 변경 반영
    if os.path.exists(error_log_path):
        try:
            with open(error_log_path, 'rb+') as f:
                # 파일 끝으로 이동 후 마지막 3바이트('\n,\n') 확인 및 제거 시도
                f.seek(0, os.SEEK_END)
                if f.tell() > 3: # 파일 크기가 충분한지 확인
                    f.seek(-3, os.SEEK_END)
                    if f.read(3) == b'\\n,\\n':
                        f.seek(-3, os.SEEK_END)
                        f.truncate()
                    else:
                         # 마지막이 \n,\n 이 아니면 쉼표만 제거 시도 (예전 버전 호환)
                         f.seek(-2, os.SEEK_END)
                         if f.read(2) == b',\\n':
                              f.seek(-2, os.SEEK_END)
                              f.truncate()

            # 파일 앞뒤에 '[' 와 ']' 추가 - 안전한 방식으로 수정
            with open(error_log_path, 'r', encoding='utf-8') as f:
                # 각 JSON 객체를 로드 (쉼표로 끝나는 것 무시)
                # 각 객체를 파싱하여 리스트에 담기
                content = f.read().strip()
                # 비어있지 않은 경우에만 처리
                if content:
                     error_entries_str = '[' + content.rstrip(',') + ']' # 읽어서 강제로 배열 만들기
                     # 다시 쓰기 (indent 적용)
                     with open(error_log_path, 'w', encoding='utf-8') as wf:
                          parsed_entries = json.loads(error_entries_str)
                          json.dump(parsed_entries, wf, ensure_ascii=False, indent=2)
                     print(f"ℹ️ 업로드 오류 로그 파일({error_log_path})을 JSON 배열 형식으로 업데이트했습니다.")
                else:
                     # 파일이 비어있으면 그냥 둠 (혹은 삭제)
                     print(f"ℹ️ 업로드 오류 로그 파일({error_log_path})이 비어있어 후처리를 건너<0xEB><0x9C><0x95>니다.")

        except Exception as e:
            print(f"⚠️ 업로드 오류 로그 파일({error_log_path}) 후처리 중 오류: {e}")


    print("🚀 모든 데이터 업로드 완료!" if success else "⚠️ 업로드 중 일부 배치가 실패했습니다.") # 최종 메시지 수정

### 실행 ###
if __name__ == "__main__":
    print("🔑 로그인 중...")
    token = get_access_token()

    if token:
        print(f"📂 JSON 파일({JSON_FILE_PATH}) 파싱 중...")
        # json_base_name 계산
        json_base_name = os.path.splitext(os.path.basename(JSON_FILE_PATH))[0]
        records = parse_json_file(JSON_FILE_PATH) # 변경된 함수 호출

        if records:
            print(f"📄 {len(records)}개의 데이터 변환 완료.")

            # --- 사용자 확인 단계 추가 ---
            print("\\n✨ 첫 번째 레코드 미리보기:")
            try:
                # 첫 번째 레코드 예쁘게 출력
                print(json.dumps(records[0], indent=2, ensure_ascii=False))
            except Exception as e:
                 print(f"첫 번째 레코드 표시에 오류 발생: {e}")
                 print(records[0]) # 간단 출력

            while True:
                confirm = input("\\n❓ 업로드를 시작하시겠습니까? (y/n): ").lower().strip()
                if confirm == 'y':
                    print("🚀 업로드를 시작합니다...")
                    # upload_records 호출 시 json_base_name 전달
                    upload_records(token, records, json_base_name)
                    # print("🎉 모든 데이터 업로드 완료!") # upload_records 함수 끝에서 출력됨
                    break
                elif confirm == 'n':
                    print("✋ 업로드를 취소했습니다.")
                    break
                else:
                    print("⚠️ 'y' 또는 'n'을 입력해주세요.")
            # --- 사용자 확인 단계 끝 ---

        else:
            print("❌ 변환된 데이터가 없습니다. 업로드를 건너<0xEB><0x9C><0x95>니다.")
    else:
        print("❌ 로그인 실패로 종료합니다.")
