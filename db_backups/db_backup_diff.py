import os
import bson
import pymongo
import certifi
from pymongo import MongoClient

OLD_BACKUP = "jumo_backup"
NEW_BACKUP = "jumo_backup_02"
OUTPUT_FILE = "db_backup_diff.txt"

MONGO_URI = "mongodb+srv://jumo_dev:JumoDev09!!@jumo-serverless.9ld8d7m.mongodb.net/"
DB_NAME = "jumo"

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

def load_bson_docs(path):
    docs = {}
    if not os.path.exists(path):
        return docs
    with open(path, "rb") as f:
        while True:
            length_bytes = f.read(4)
            if not length_bytes or len(length_bytes) < 4:
                break
            length = int.from_bytes(length_bytes, byteorder='little')
            doc_bytes = length_bytes + f.read(length - 4)
            try:
                doc = bson.BSON(doc_bytes).decode()
                docs[str(doc["_id"])] = doc
            except Exception:
                break
    return docs

# 1. 새 백업 폴더 생성 및 백업
if not os.path.exists(NEW_BACKUP):
    os.makedirs(NEW_BACKUP)
backup_db(MONGO_URI, DB_NAME, NEW_BACKUP)

# 2. diff 비교
result_lines = []

for file in os.listdir(NEW_BACKUP):
    if not file.endswith(".bson"):
        continue
    col_name = file.replace(".bson", "")
    old_path = os.path.join(OLD_BACKUP, file)
    new_path = os.path.join(NEW_BACKUP, file)
    old_docs = load_bson_docs(old_path)
    new_docs = load_bson_docs(new_path)

    added = [doc for _id, doc in new_docs.items() if _id not in old_docs]
    deleted = [doc for _id, doc in old_docs.items() if _id not in new_docs]
    modified = [
        (old_docs[_id], new_docs[_id])
        for _id in set(old_docs) & set(new_docs)
        if old_docs[_id] != new_docs[_id]
    ]

    result_lines.append(f"=== {col_name} ===")
    result_lines.append(f"추가된 문서: {len(added)}")
    for doc in added:
        result_lines.append(f"  + {doc}")
    result_lines.append(f"삭제된 문서: {len(deleted)}")
    for doc in deleted:
        result_lines.append(f"  - {doc}")
    result_lines.append(f"수정된 문서: {len(modified)}")
    for old, new in modified:
        result_lines.append(f"  * old: {old}")
        result_lines.append(f"    new: {new}")
    result_lines.append("")

with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
    for line in result_lines:
        f.write(str(line) + "\n")

print(f"백업 및 차이 결과를 '{OUTPUT_FILE}' 파일로 저장했습니다.") 