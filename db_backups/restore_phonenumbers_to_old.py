import os
import bson
import pymongo
import certifi
import re
from bson import ObjectId
import datetime
import pprint

DIFF_FILE = "db_backup_diff.txt"
MONGO_URI = "mongodb+srv://jumo_dev:JumoDev09!!@jumo-serverless.9ld8d7m.mongodb.net/"
DB_NAME = "jumo"
COLLECTION = "phonenumbers"

# 1. diff 파일에서 phonenumbers old 문서 파싱
def extract_old_docs(diff_path):
    docs = []
    in_phonenumbers = False
    in_old = False
    current_doc = ''
    with open(diff_path, "r", encoding="utf-8") as f:
        for line in f:
            if line.startswith("=== phonenumbers ==="):
                in_phonenumbers = True
            elif line.startswith("===") and in_phonenumbers:
                break  # phonenumbers 블록 끝
            if in_phonenumbers:
                if line.strip().startswith("* old:"):
                    in_old = True
                    current_doc = line.split(":",1)[1].strip()
                elif line.strip().startswith("new:") and in_old:
                    in_old = False
                    try:
                        doc = eval(current_doc, {"ObjectId": ObjectId, "datetime": datetime})
                        docs.append(doc)
                    except Exception as e:
                        print(f"파싱 오류: {e}\n{current_doc}")
                elif in_old:
                    current_doc += line
    return docs

def main():
    old_docs = extract_old_docs(DIFF_FILE)
    print(f"old 문서 {len(old_docs)}개 추출됨.")
    client = pymongo.MongoClient(MONGO_URI, tlsCAFile=certifi.where())
    db = client[DB_NAME]
    col = db[COLLECTION]
    for idx, doc in enumerate(old_docs, 1):
        _id = doc["_id"]
        if not isinstance(_id, ObjectId):
            _id = ObjectId(str(_id))
        print(f"\n[{idx}] _id: {_id}")
        current = col.find_one({"_id": _id})
        print("[현재 DB 상태]")
        pprint.pprint(current)
        print("[old로 변경할 내용]")
        pprint.pprint(doc)
        ans = input("이것을 old로 변경하시겠습니까? (y/n): ").strip().lower()
        if ans == 'y':
            update_doc = doc.copy()
            del update_doc["_id"]
            result = col.update_one({"_id": _id}, {"$set": update_doc})
            print(f"-> 업데이트 완료! matched: {result.matched_count}, modified: {result.modified_count}")
        else:
            print("-> 건너뜀.")

if __name__ == "__main__":
    main() 