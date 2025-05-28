import os
import pymongo
import bson
from pymongo import MongoClient
import certifi

# 1. 백업
def backup_db(uri, db_name, backup_dir):
    print(f"[백업 시작] DB: {db_name}, URI: {uri}, 디렉토리: {backup_dir}")
    client = MongoClient(uri, tlsCAFile=certifi.where())
    db = client[db_name]
    os.makedirs(backup_dir, exist_ok=True)
    for col_name in db.list_collection_names():
        print(f"  - 컬렉션 백업 중: {col_name}")
        data = list(db[col_name].find())
        with open(f"{backup_dir}/{col_name}.bson", "wb") as f:
            for doc in data:
                f.write(bson.BSON.encode(doc))
        print(f"    -> {len(data)}개 문서 저장 완료")
    print("[백업 완료!]")

# 2. 복원
def restore_db(uri, db_name, backup_dir):
    print(f"[복원 시작] DB: {db_name}, URI: {uri}, 디렉토리: {backup_dir}")
    client = MongoClient(uri, tlsCAFile=certifi.where())
    db = client[db_name]
    for file in os.listdir(backup_dir):
        if file.endswith(".bson"):
            col_name = file.replace(".bson", "")
            print(f"  - 컬렉션 복원 중: {col_name}")
            docs = []
            with open(f"{backup_dir}/{file}", "rb") as f:
                while True:
                    length_bytes = f.read(4)
                    if not length_bytes or len(length_bytes) < 4:
                        break
                    length = int.from_bytes(length_bytes, byteorder='little')
                    doc_bytes = length_bytes + f.read(length - 4)
                    try:
                        doc = bson.BSON(doc_bytes).decode()
                        docs.append(doc)
                    except Exception:
                        break
            if docs:
                db[col_name].delete_many({})
                db[col_name].insert_many(docs)
                print(f"    -> {len(docs)}개 문서 복원 완료")
            else:
                print(f"    -> 복원할 문서 없음")
    print("[복원 완료!]")

if __name__ == "__main__":
    print("==== MongoDB 백업/복원 도구 ====")
    mode = input("1: 백업, 2: 복원, 3: 둘 다 (1/2/3) 중 선택: ").strip()
    backup_dir = "jumo_backup"
    db_name = "jumo"
    uri_backup = "mongodb+srv://jumo_dev:JumoDev09!!@jumo-serverless.9ld8d7m.mongodb.net/"
    uri_restore = "mongodb+srv://jumo_dev:JumoDev09!!@jumo-dedicate.bt2k0.mongodb.net/"
    if mode == '1':
        backup_db(uri_backup, db_name, backup_dir)
    elif mode == '2':
        restore_db(uri_restore, db_name, backup_dir)
    elif mode == '3':
        backup_db(uri_backup, db_name, backup_dir)
        restore_db(uri_restore, db_name, backup_dir)
    else:
        print("잘못된 입력입니다. 프로그램을 종료합니다.")
