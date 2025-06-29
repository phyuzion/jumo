import pymongo
import argparse
import sys
import json
from bson import ObjectId
import os
import certifi
from datetime import datetime

# --- 설정 ---
# 환경 변수 또는 직접 입력 중 선택
MONGO_URI = os.getenv("MONGO_URI", "mongodb+srv://jumo_dev:JumoDev09!!@jumo-serverless.9ld8d7m.mongodb.net/")
DATABASE_NAME = "jumo" # 사용할 데이터베이스 이름
COLLECTION_NAME = "users" # 사용할 컬렉션 이름
TARGET_DATE = datetime.fromisoformat("2025-09-29T15:00:00.000Z".replace('Z', '+00:00'))
# --- 설정 끝 ---

# ObjectId를 문자열로 변환하는 JSON 인코더
class JSONEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, ObjectId):
            return str(o)
        if isinstance(o, datetime):
            return o.isoformat()
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

def get_users(db):
    """사용자 목록을 가져옵니다."""
    collection = db[COLLECTION_NAME]
    try:
        # 모든 사용자 검색
        users = list(collection.find())
        print(f"\n총 {len(users)}명의 사용자를 찾았습니다.")
        return users
    except Exception as e:
        print(f"사용자 검색 중 오류 발생: {e}")
        return []

def update_valid_until(db, user_id):
    """특정 사용자의 validUntil 필드를 업데이트합니다."""
    collection = db[COLLECTION_NAME]
    try:
        result = collection.update_one(
            {"_id": user_id},
            {"$set": {"validUntil": TARGET_DATE}}
        )
        return result.modified_count > 0
    except Exception as e:
        print(f"사용자 업데이트 중 오류 발생: {e}")
        return False

def display_user_info(user):
    """사용자 정보를 보기 좋게 출력합니다."""
    print("\n" + "-" * 50)
    print(f"이름: {user.get('name', '이름 없음')}")
    print(f"로그인 ID: {user.get('loginId', '정보 없음')}")
    print(f"전화번호: {user.get('phoneNumber', '정보 없음')}")
    print(f"사용자 타입: {user.get('userType', '정보 없음')}")
    
    valid_until = user.get('validUntil')
    if valid_until:
        if isinstance(valid_until, dict) and "$date" in valid_until:
            valid_str = valid_until["$date"]
        else:
            valid_str = str(valid_until)
        print(f"현재 만료일: {valid_str}")
    else:
        print("만료일: 설정되지 않음")
        
    print(f"지역: {user.get('region', '정보 없음')}")
    print(f"등급: {user.get('grade', '정보 없음')}")
    print("-" * 50)
    print(f"새 만료일로 변경: 2025-09-29T15:00:00.000Z")
    print("-" * 50)

def main():
    print(f"'{COLLECTION_NAME}' 컬렉션의 사용자 만료일(validUntil)을 2025-09-29T15:00:00.000Z로 업데이트합니다.")

    client = None
    try:
        client = connect_db()
        db = client[DATABASE_NAME]

        users = get_users(db)
        
        if not users:
            print("업데이트할 사용자가 없습니다.")
            return

        updated_count = 0
        skipped_count = 0

        for user in users:
            display_user_info(user)
            
            while True:
                confirm = input(f"이 사용자의 만료일을 업데이트하시겠습니까? (y/n): ").lower()
                if confirm == 'y':
                    success = update_valid_until(db, user["_id"])
                    if success:
                        print("✓ 만료일이 업데이트되었습니다.")
                        updated_count += 1
                    else:
                        print("✗ 만료일 업데이트에 실패했습니다.")
                    break
                elif confirm == 'n':
                    print("이 사용자는 건너뜁니다.")
                    skipped_count += 1
                    break
                else:
                    print("y 또는 n을 입력해주세요.")

        print("\n" + "=" * 50)
        print(f"작업 완료: {updated_count}명 업데이트됨, {skipped_count}명 건너뜀")
        print("=" * 50)

    finally:
        if client:
            client.close()
            print("\nMongoDB 연결 종료.")

if __name__ == "__main__":
    main() 