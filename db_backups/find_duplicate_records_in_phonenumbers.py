import pymongo
import certifi
from collections import defaultdict
from datetime import datetime
from pymongo import UpdateOne

MONGO_URI = "mongodb+srv://jumo_dev:JumoDev09!!@jumo-serverless.9ld8d7m.mongodb.net/"
DB_NAME = "jumo"
COLLECTION_NAME = "phonenumbers"
OUTPUT_FILE = "deleted_duplicate_records_in_phonenumbers.txt"

client = pymongo.MongoClient(MONGO_URI, tlsCAFile=certifi.where())
db = client[DB_NAME]
col = db[COLLECTION_NAME]

delete_targets = []
examples = []
example_count = 0

for doc in col.find({}, {"phoneNumber": 1, "records": 1}):
    phone = doc.get("phoneNumber")
    records = doc.get("records", [])
    counter = defaultdict(list)
    for rec in records:
        key = (
            rec.get("userName"),
            rec.get("name")
        )
        counter[key].append(rec)
    for key, recs in counter.items():
        if len(recs) > 1:
            # createdAt 기준 내림차순 정렬 (최신이 맨 앞)
            recs_sorted = sorted(
                recs,
                key=lambda r: r.get("createdAt") if r.get("createdAt") else "",
                reverse=True
            )
            # 최신 1개만 남기고 나머지 삭제 대상
            to_delete = recs_sorted[1:]
            if example_count < 3:
                examples.append({
                    "phoneNumber": phone,
                    "userName, name": key,
                    "keep": recs_sorted[0],
                    "delete": to_delete
                })
                example_count += 1
            for rec in to_delete:
                delete_targets.append({
                    "phoneNumber": phone,
                    "delete_record_id": rec.get("_id")
                })

# 예시 3건 콘솔 출력
print("중복 record 삭제 예시 (최신 1개만 남기고 삭제):")
for i, ex in enumerate(examples, 1):
    print(f"\n[{i}] phoneNumber: {ex['phoneNumber']}, userName, name: {ex['userName, name']}")
    print(f"  남길 record _id: {ex['keep'].get('_id')}, createdAt: {ex['keep'].get('createdAt')}")
    print(f"  삭제할 record _id 리스트: {[r.get('_id') for r in ex['delete']]}")
    print(f"  삭제할 createdAt 리스트: {[r.get('createdAt') for r in ex['delete']]}")

print(f"\n총 삭제 대상 record 수: {len(delete_targets)}")

# 삭제 여부 확인
confirm = input("\n정말 삭제하시겠습니까? (y/n): ").strip().lower()
if confirm != "y":
    print("삭제를 취소했습니다.")
    exit(0)

# 실제 삭제 (벌크 연산)
bulk_ops = []
phone_to_delete_ids = defaultdict(set)
for d in delete_targets:
    phone_to_delete_ids[d["phoneNumber"]].add(d["delete_record_id"])

for doc in col.find({}, {"_id": 1, "phoneNumber": 1, "records": 1}):
    phone = doc.get("phoneNumber")
    records = doc.get("records", [])
    to_delete_ids = phone_to_delete_ids.get(phone)
    if not to_delete_ids:
        continue
    new_records = [rec for rec in records if rec.get("_id") not in to_delete_ids]
    if len(new_records) != len(records):
        bulk_ops.append(
            UpdateOne({"_id": doc["_id"]}, {"$set": {"records": new_records}})
        )

if bulk_ops:
    result = col.bulk_write(bulk_ops)
    print(f"Bulk update 완료! 수정된 문서 수: {result.modified_count}")
else:
    print("수정할 문서가 없습니다.")

# 삭제 결과 저장
with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
    f.write(f"삭제된 중복 record 목록 (총 {len(delete_targets)}건):\n\n")
    for d in delete_targets:
        f.write(str(d) + "\n")

print(f"\n삭제 내역을 '{OUTPUT_FILE}' 파일로 저장했습니다.") 