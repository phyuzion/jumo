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

def find_and_save_records(db, user_name_to_find):
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

def delete_user_records(db, user_name_to_delete):
    """지정된 userName을 가진 레코드를 삭제합니다."""
    collection = db[COLLECTION_NAME]
    query_filter = {"records.userName": user_name_to_delete}
    update_operation = {"$pull": {"records": {"userName": user_name_to_delete}}}

    try:
        result = collection.update_many(query_filter, update_operation)
        print(f"\n삭제 작업 완료:")
        print(f" - 필터와 일치하는 문서 수: {result.matched_count}")
        print(f" - 실제 레코드가 삭제된 문서 수: {result.modified_count}")
    except Exception as e:
        print(f"데이터 삭제 중 오류 발생: {e}")

def main():
    parser = argparse.ArgumentParser(description="MongoDB에서 특정 userName의 레코드를 검색하고 삭제합니다.")
    parser.add_argument("username", help="검색 및 삭제할 userName")
    args = parser.parse_args()

    user_name = args.username
    print(f"대상 userName: {user_name}")

    client = None
    try:
        client = connect_db()
        db = client[DATABASE_NAME]

        matching_records, document_count = find_and_save_records(db, user_name)

        if document_count > 0: # 문서는 찾았지만 실제 레코드가 없을 수도 있음(이론상)
                           # 또는 삭제할 레코드가 없을 수도 있음 (이전 작업 등으로)
            while True:
                confirm = input(f"userName '{user_name}'의 레코드를 삭제하시겠습니까? (y/n): ").lower()
                if confirm == 'y':
                    delete_user_records(db, user_name)
                    break
                elif confirm == 'n':
                    print("삭제 작업을 취소했습니다.")
                    break
                else:
                    print("y 또는 n을 입력해주세요.")
        else:
            print(f"userName '{user_name}'를 포함하는 문서가 없어 삭제할 내용이 없습니다.")

    finally:
        if client:
            client.close()
            print("\nMongoDB 연결 종료.")

if __name__ == "__main__":
    main()