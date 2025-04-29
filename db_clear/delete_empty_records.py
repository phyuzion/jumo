import pymongo
import argparse
import sys
import json
from bson import ObjectId
import os
import certifi

# --- 설정 ---
# 환경 변수 또는 직접 입력 중 선택
MONGO_URI = os.getenv("MONGO_URI", "mongodb+srv://jumo_dev:JumoDev09!!@jumo-serverless.9ld8d7m.mongodb.net/")
DATABASE_NAME = "jumo" # 사용할 데이터베이스 이름
COLLECTION_NAME = "phonenumbers" # 사용할 컬렉션 이름
OUTPUT_FILENAME = "empty_records_result.txt" # 결과 저장 파일 이름
# --- 설정 끝 ---

# ObjectId를 문자열로 변환하는 JSON 인코더 (userclear.py와 동일)
class JSONEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, ObjectId):
            return str(o)
        # 날짜/시간도 처리하려면 추가 (선택 사항)
        # if isinstance(o, datetime.datetime):
        #     return o.isoformat()
        return json.JSONEncoder.default(self, o)

def connect_db():
    """MongoDB에 연결하고 클라이언트 객체를 반환합니다."""
    try:
        client = pymongo.MongoClient(MONGO_URI, tlsCAFile=certifi.where())
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

def find_and_save_empty_records(db):
    """records 배열이 비어있는 문서를 찾아 개수 반환 및 파일 저장"""
    collection = db[COLLECTION_NAME]
    empty_record_docs = []
    document_count = 0

    # 1. records 배열이 비어있는 문서 찾기
    # $size: 0 연산자는 배열 필드가 존재하고 그 크기가 0인 문서를 찾음
    query_filter = {"records": {"$size": 0}}
    # 또는 필드가 아예 없거나 빈 배열인 경우:
    # query_filter = {"$or": [{"records": {"$exists": false}}, {"records": []}]}

    try:
        document_count = collection.count_documents(query_filter)
        print(f"\n`records` 배열이 비어있는 문서는 총 {document_count}개 입니다.")

        if document_count == 0:
            return 0 # 찾은 문서 없음

        # 2. 해당 문서 정보 가져오기 (phoneNumber와 _id만)
        cursor = collection.find(query_filter, {"phoneNumber": 1, "_id": 1})
        # ObjectId 포함 저장을 위해 json.dump 사용
        docs_to_save = list(cursor)


        # 3. 파일에 저장
        try:
            with open(OUTPUT_FILENAME, 'w', encoding='utf-8') as f:
                 f.write(f"`records` 배열이 비어있는 문서 목록 ({document_count}개):\n\n")
                 json.dump(docs_to_save, f, ensure_ascii=False, indent=2, cls=JSONEncoder)
                 print(f"검색된 문서 정보를 '{OUTPUT_FILENAME}' 파일에 저장했습니다.")
        except IOError as e:
            print(f"'{OUTPUT_FILENAME}' 파일 저장 중 오류 발생: {e}")

    except Exception as e:
        print(f"데이터 검색 중 오류 발생: {e}")
        return 0 # 오류 시 0개 반환

    return document_count

def delete_empty_records(db):
    """records 배열이 비어있는 문서를 삭제합니다."""
    collection = db[COLLECTION_NAME]
    query_filter = {"records": {"$size": 0}}
    # 또는 필드가 아예 없거나 빈 배열인 경우:
    # query_filter = {"$or": [{"records": {"$exists": false}}, {"records": []}]}

    try:
        result = collection.delete_many(query_filter)
        print(f"\n삭제 작업 완료:")
        print(f" - 삭제된 문서 수: {result.deleted_count}")
    except Exception as e:
        print(f"데이터 삭제 중 오류 발생: {e}")

def main():
    print(f"'{COLLECTION_NAME}' 컬렉션에서 `records` 배열이 비어있는 문서를 검색 및 삭제합니다.")

    client = None
    try:
        client = connect_db()
        db = client[DATABASE_NAME]

        document_count = find_and_save_empty_records(db)

        if document_count > 0:
            while True:
                confirm = input(f"\n총 {document_count}개의 문서를 삭제하시겠습니까? (y/n): ").lower()
                if confirm == 'y':
                    delete_empty_records(db)
                    break
                elif confirm == 'n':
                    print("삭제 작업을 취소했습니다.")
                    break
                else:
                    print("y 또는 n을 입력해주세요.")
        else:
            print("삭제할 문서가 없습니다.")

    finally:
        if client:
            client.close()
            print("\nMongoDB 연결 종료.")

if __name__ == "__main__":
    main()
