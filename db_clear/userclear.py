import pymongo
import argparse
import sys
import json
from bson import ObjectId
import os
import certifi
import datetime


# --- 설정 ---
# 환경 변수 또는 직접 입력 중 선택
MONGO_URI = os.getenv("MONGO_URI", "mongodb+srv://jumo_dev:JumoDev09!!@jumo-serverless.9ld8d7m.mongodb.net/")
DATABASE_NAME = "jumo" # 사용할 데이터베이스 이름 (기본값 'test')
COLLECTION_NAME = "phonenumbers" # 사용할 컬렉션 이름
OUTPUT_FILENAME = "result.txt"
WANT_DELETE_FILENAME = "want_delete_record.txt"
# --- 설정 끝 ---

# ObjectId 및 datetime을 문자열로 변환하는 JSON 인코더
class JSONEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, ObjectId):
            return str(o)
        if isinstance(o, datetime.datetime):
            return o.isoformat()
        return json.JSONEncoder.default(self, o)

def connect_db():
    """MongoDB에 연결하고 클라이언트 객체를 반환합니다."""
    try:
        client = pymongo.MongoClient(MONGO_URI, tlsCAFile=certifi.where())
        # 연결 테스트 (선택 사항)
        client.admin.command('ping')
        print("MongoDB 연결 성공!")
        return client
    except pymongo.errors.ConfigurationError as e:
        print(f"MongoDB 연결 설정 오류: {e}")
        sys.exit(1)
    except pymongo.errors.ConnectionFailure as e:
        print(f"MongoDB 연결 실패: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"알 수 없는 연결 오류: {e}")
        sys.exit(1)

def find_records_by_username(db, user_name_to_find):
    """지정된 userName을 가진 레코드를 찾아 개수 반환 및 파일 저장"""
    collection = db[COLLECTION_NAME]
    matching_records = []
    document_count = 0

    # 1. 조건에 맞는 문서 개수 세기
    query_filter = {"records.userName": user_name_to_find}
    try:
        document_count = collection.count_documents(query_filter)
        print(f"\nuserName '{user_name_to_find}'를 포함하는 문서는 총 {document_count}개 입니다.")

        if document_count == 0:
            return [], document_count # 찾은 레코드는 없고 문서 개수만 반환

        # 2. Aggregation Pipeline을 사용하여 해당 userName의 레코드만 추출
        pipeline = [
            {"$match": query_filter},
            {"$unwind": "$records"}, # records 배열을 개별 문서로 분리
            {"$match": {"records.userName": user_name_to_find}}, # 분리된 것 중 userName 일치하는 것만 필터링
            {"$project": { # 필요한 필드만 선택 (결과 파일 내용)
                "_id": 0, # 문서 ID는 제외
                "phoneNumber": "$phoneNumber", # 부모 문서의 전화번호
                "documentId": "$_id", # 부모 문서의 ID
                "record": "$records" # 일치하는 레코드 객체
            }}
        ]
        cursor = collection.aggregate(pipeline)
        matching_records = list(cursor)

        # 3. 파일에 저장
        try:
            with open(OUTPUT_FILENAME, 'w', encoding='utf-8') as f:
                f.write(f"userName '{user_name_to_find}'를 포함하는 문서 {document_count}개에서 찾은 레코드:\n\n")
                if matching_records:
                    # JSONEncoder를 사용하여 ObjectId를 문자열로 변환하여 저장
                    json.dump(matching_records, f, ensure_ascii=False, indent=2, cls=JSONEncoder)
                    print(f"검색된 레코드 {len(matching_records)}개를 '{OUTPUT_FILENAME}' 파일에 저장했습니다.")
                else:
                     # 이 경우는 document_count > 0 이지만 실제 레코드 추출이 안된 경우 (이론상 발생 어려움)
                    f.write("일치하는 레코드를 찾지 못했습니다 (문서는 존재하나 레코드 추출 실패).\n")
                    print(f"'{OUTPUT_FILENAME}' 파일에 저장할 레코드가 없습니다 (문서는 존재하나 레코드 추출 실패).")

        except IOError as e:
            print(f"'{OUTPUT_FILENAME}' 파일 저장 중 오류 발생: {e}")

    except Exception as e:
        print(f"데이터 검색 중 오류 발생: {e}")

    return matching_records, document_count

def display_records_with_userid(records):
    """userId별로 레코드를 표시하고 선택 옵션을 제공합니다."""
    if not records:
        print("표시할 레코드가 없습니다.")
        return None
    
    # userId별로 레코드 그룹화 (None값은 "없음"으로 표시)
    user_id_groups = {}
    for idx, record_data in enumerate(records, start=1):
        record = record_data.get("record", {})
        user_id = record.get("userId", "없음")
        if user_id is None:
            user_id = "없음"
        elif isinstance(user_id, dict) and "$oid" in user_id:
            user_id = user_id["$oid"]
            
        if user_id not in user_id_groups:
            user_id_groups[user_id] = []
        
        # 각 레코드에 선택용 번호 추가
        record_with_index = record_data.copy()
        record_with_index["index"] = idx
        user_id_groups[user_id].append(record_with_index)
    
    # 그룹화된 레코드 표시
    print("\n=== userId별 레코드 목록 ===")
    option_number = 1
    options_map = {}
    
    for user_id, records_list in user_id_groups.items():
        print(f"\n[{option_number}] userId: {user_id} - {len(records_list)}개 레코드")
        options_map[str(option_number)] = {
            "user_id": user_id,
            "records": records_list
        }
        
        # 이 userId의 레코드 샘플 표시 (최대 2개)
        for i, record_data in enumerate(records_list[:2], start=1):
            record = record_data.get("record", {})
            phone = record_data.get("phoneNumber", "")
            created_data = record.get("createdAt", "")
            
            # datetime 형식 처리
            if isinstance(created_data, datetime.datetime):
                created = created_data.isoformat()[:10]  # YYYY-MM-DD 형식으로 변환
            elif isinstance(created_data, dict) and "$date" in created_data:
                created = created_data.get("$date", "")[:10]
            else:
                created = str(created_data)[:10] if created_data else ""
                
            print(f"   {i}. {record.get('userName', '')} - {phone} ({created})")
        
        if len(records_list) > 2:
            print(f"   ... 외 {len(records_list) - 2}개 더 있음")
        
        option_number += 1
    
    return options_map

def select_records_to_delete(options_map):
    """사용자가 삭제할 userId 그룹을 선택합니다."""
    if not options_map:
        return None
    
    while True:
        choice = input("\n삭제할 userId 그룹 번호를 선택하세요 (q를 입력하면 취소): ")
        if choice.lower() == 'q':
            return None
        
        if choice in options_map:
            return options_map[choice]
        else:
            print(f"잘못된 선택입니다. 1에서 {len(options_map)} 사이의 번호를 입력하세요.")

def confirm_records_deletion(selected_group):
    """삭제할 레코드 그룹의 상세 정보를 파일로 저장하고 확인을 요청합니다."""
    if not selected_group:
        return False
    
    user_id = selected_group["user_id"]
    records = selected_group["records"]
    
    print(f"\n선택한 userId '{user_id}'의 {len(records)}개 레코드를 삭제하시겠습니까?")
    
    # 상세 정보 파일로 저장
    try:
        with open(WANT_DELETE_FILENAME, 'w', encoding='utf-8') as f:
            f.write(f"삭제 예정인 userId '{user_id}'의 레코드 {len(records)}개:\n\n")
            json.dump(records, f, ensure_ascii=False, indent=2, cls=JSONEncoder)
        print(f"삭제 예정 레코드를 '{WANT_DELETE_FILENAME}' 파일에 저장했습니다. 확인해주세요.")
    except IOError as e:
        print(f"'{WANT_DELETE_FILENAME}' 파일 저장 중 오류 발생: {e}")
        return False
    
    # 사용자 확인
    while True:
        confirm = input("정말로 이 레코드들을 삭제하시겠습니까? (y/n): ").lower()
        if confirm == 'y':
            return True
        elif confirm == 'n':
            print("삭제를 취소했습니다.")
            return False
        else:
            print("y 또는 n을 입력해주세요.")

def delete_selected_records(db, selected_group):
    """선택된 userId의 레코드만 삭제합니다."""
    if not selected_group:
        return
    
    collection = db[COLLECTION_NAME]
    user_id = selected_group["user_id"]
    records = selected_group["records"]
    deleted_count = 0
    
    print(f"\n'{user_id}' userId를 가진 레코드 삭제 중...")
    
    # 레코드별로 개별 삭제 (각 문서에서 선택된 userId를 가진 특정 레코드만 제거)
    for record_data in records:
        document_id = record_data.get("documentId")
        record_obj = record_data.get("record", {})
        record_id = None
        
        # _id 필드 추출 (여러 가능한 형태 처리)
        if "_id" in record_obj:
            # ObjectId 객체인 경우
            if isinstance(record_obj["_id"], ObjectId):
                record_id = str(record_obj["_id"])
            # 딕셔너리이고 $oid 키가 있는 경우
            elif isinstance(record_obj["_id"], dict) and "$oid" in record_obj["_id"]:
                record_id = record_obj["_id"]["$oid"]
            # 그 외의 경우 (문자열 등)
            else:
                record_id = str(record_obj["_id"])
        
        if not document_id or not record_id:
            print(f"필요한 ID 정보가 누락되어 건너뜁니다.")
            continue
        
        try:
            # 특정 문서에서 특정 record._id를 가진 항목만 제거
            result = collection.update_one(
                {"_id": ObjectId(document_id)},
                {"$pull": {"records": {"_id": ObjectId(record_id)}}}
            )
            
            if result.modified_count > 0:
                deleted_count += 1
    except Exception as e:
            print(f"레코드 삭제 중 오류 발생: {e}")
    
    print(f"\n삭제 작업 완료: {deleted_count}/{len(records)}개 레코드가 삭제되었습니다.")

def main():
    parser = argparse.ArgumentParser(description="MongoDB에서 특정 userName의 레코드를 검색하고 선택적으로 삭제합니다.")
    parser.add_argument("username", help="검색할 userName")
    args = parser.parse_args()

    user_name = args.username
    print(f"대상 userName: {user_name}")

    client = None
    try:
        client = connect_db()
        db = client[DATABASE_NAME]

        # 1. 이름으로 레코드 검색
        matching_records, document_count = find_records_by_username(db, user_name)

        if document_count > 0 and matching_records:
            # 2. userId 별로 레코드 그룹화하여 표시하고 선택 옵션 제공
            options_map = display_records_with_userid(matching_records)
            
            if options_map:
                # 3. 삭제할 userId 그룹 선택
                selected_group = select_records_to_delete(options_map)
                
                if selected_group:
                    # 4. 삭제 확인 (want_delete_record.txt에 저장 후 확인)
                    if confirm_records_deletion(selected_group):
                        # 5. 선택된 레코드 삭제
                        delete_selected_records(db, selected_group)
                else:
                print("표시할 옵션이 없습니다.")
        else:
            print(f"userName '{user_name}'를 포함하는 레코드가 없어 삭제할 내용이 없습니다.")

    finally:
        if client:
            client.close()
            print("\nMongoDB 연결 종료.")

if __name__ == "__main__":
    main()