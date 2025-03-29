import re
import requests
import json
import time
import os
import pytz
from datetime import datetime

# 📌 설정값
SQL_FILE_PATH = "./faker20241122.sql"  # SQL 파일 경로
BATCH_SIZE = 500  # 한 번에 보낼 레코드 개수 (조절 가능)
GRAPHQL_ENDPOINT = "https://jumo-vs8e.onrender.com/graphql"
ADMIN_CREDENTIALS = {
    "username": "admin",
    "password": "1234"
}
PROGRESS_FILE = "uploaded_count.txt"  # 중간 저장 파일

# 📌 컬럼 인덱스 (INSERT INTO 기준)
PHONE_IDX = 3
MEMO_IDX = 4
COMPANY_INFO_IDX = 6
UPDATED_DATE_IDX = 7
ACTION_TYPE_IDX = 8

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
    265: "스웨디시",
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
    
    response = requests.post(GRAPHQL_ENDPOINT, json=login_query)

    if response.status_code != 200:
        print(f"❌ 로그인 요청 실패 (HTTP {response.status_code}): {response.text}")
        return None

    data = response.json()
    if "errors" in data:
        print(f"❌ GraphQL 오류: {data['errors']}")
        return None

    try:
        return data["data"]["adminLogin"]["accessToken"]
    except (KeyError, TypeError):
        print(f"❌ 예상치 못한 응답 형식: {data}")
        return None

### 2️⃣ SQL 파일 파싱해서 JSON 데이터 변환 ###
def parse_sql_file(sql_file_path):
    with open(sql_file_path, 'r', encoding='utf-8') as f:
        data = f.read()

    pattern = re.compile(r"\((.*?)\)", re.DOTALL)
    matches = pattern.findall(data)

    records = []
    for match in matches:
        columns = re.split(r",(?=(?:[^']*'[^']*')*[^']*$)", match)
        columns = [col.strip().strip("'") for col in columns]
        
        if len(columns) < 10:
            continue

        # 컬럼명이 들어간 잘못된 데이터 제거
        if columns[PHONE_IDX].lower() in ["phonenumber", "phone_number"] or columns[UPDATED_DATE_IDX].lower() in ["updateddate", "updated_date"]:
            print(f"⚠️ 잘못된 데이터 스킵: {columns}")
            continue

        # userType 변환
        try:
            user_type_num = int(columns[ACTION_TYPE_IDX]) if columns[ACTION_TYPE_IDX] not in ["-1", "", "null", None] else 0
            user_type = USER_TYPE_MAPPING.get(user_type_num, "일반")
        except ValueError:
            user_type = "일반"

        # 시간 처리
        try:
            # 시간 형식이 맞는 경우 UTC로 변환
            if re.match(r'\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}', columns[UPDATED_DATE_IDX]):
                kst = pytz.timezone('Asia/Seoul')
                utc = pytz.UTC
                kst_time = datetime.strptime(columns[UPDATED_DATE_IDX], '%Y-%m-%d %H:%M:%S')
                kst_time = kst.localize(kst_time)
                utc_time = kst_time.astimezone(utc)
                created_at = utc_time.isoformat()
            else:
                # 형식이 맞지 않는 경우 기본값 사용
                created_at = "2020-01-01T00:00:00+00:00"
        except Exception as e:
            print(f"⚠️ 시간 처리 실패: {e}")
            created_at = "2020-01-01T00:00:00+00:00"

        record = {
            "name": columns[MEMO_IDX] if columns[MEMO_IDX] != "-1" else None,
            "phoneNumber": columns[PHONE_IDX],
            "userName": columns[COMPANY_INFO_IDX] if columns[COMPANY_INFO_IDX] != "-1" else None,
            "userType": user_type,
            "createdAt": created_at
        }
        records.append(record)

    return records

### 3️⃣ 업로드된 개수를 저장하는 함수 (중간 재시작 가능) ###
def save_progress(uploaded_count):
    with open(PROGRESS_FILE, "w") as f:
        f.write(str(uploaded_count))

def load_progress():
    if os.path.exists(PROGRESS_FILE):
        with open(PROGRESS_FILE, "r") as f:
            return int(f.read().strip())
    return 0

### 4️⃣ 데이터 업로드 (배치 처리 + 재시도) ###
def upload_records(access_token, records):
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
    uploaded_count = load_progress()  # 업로드된 개수 불러오기
    print(f"📤 총 {total_records}개의 레코드 중 {uploaded_count}개까지 업로드됨. 이어서 진행.")

    for i in range(uploaded_count, total_records, BATCH_SIZE):
        batch = records[i:i + BATCH_SIZE]
        mutation_query["variables"] = {"records": batch}
        
        retries = 3  # 재시도 횟수
        while retries > 0:
            response = requests.post(GRAPHQL_ENDPOINT, json=mutation_query, headers=headers)
            if response.status_code == 200:
                uploaded_count = i + len(batch)
                save_progress(uploaded_count)  # 업로드 개수 저장
                print(f"✅ {uploaded_count} / {total_records} 개 완료 ({uploaded_count/total_records*100:.2f}%)")
                break
            else:
                print(f"❌ 오류 발생 (재시도 {4 - retries}/3): {response.text}")
                retries -= 1
                time.sleep(2)  # 2초 대기 후 재시도

    print("🚀 모든 데이터 업로드 완료!")

### 실행 ###
if __name__ == "__main__":
    print("🔑 로그인 중...")
    token = get_access_token()
    
    if token:
        print("📂 SQL 파일 파싱 중...")
        records = parse_sql_file(SQL_FILE_PATH)
        
        if records:
            print(f"📄 {len(records)}개의 데이터 변환 완료. 업로드 시작!")
            upload_records(token, records)
            print("🎉 모든 데이터 업로드 완료!")
        else:
            print("❌ 변환된 데이터가 없습니다.")
    else:
        print("❌ 로그인 실패로 종료합니다.")
