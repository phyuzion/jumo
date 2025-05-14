package com.jumo.mobile

import android.content.ContentResolver
import android.content.ContentValues
import android.content.Context
import android.provider.ContactsContract
import android.util.Log

object ContactManager {
    // 기존 getContacts 함수는 삭제합니다.

    // 스트리밍 방식으로 연락처 정보를 처리하는 함수
    fun processContactsStreamed(
        context: Context,
        lastSyncTimestampEpochMillis: Long?, // Long? 타입으로 변경, null 가능
        chunkSize: Int = 50, // 한 번에 처리할 청크 크기
        onChunkProcessed: (List<Map<String, Any?>>) -> Unit, // 각 청크 처리 후 호출될 콜백
        onFinished: () -> Unit, // 모든 데이터 처리 후 호출될 콜백
        onError: (Exception) -> Unit // 에러 발생 시 호출될 콜백
    ) {
        if (lastSyncTimestampEpochMillis != null && lastSyncTimestampEpochMillis > 0) {
            Log.d("ContactManager", "processContactsStreamed: Starting to stream UPDATED contacts since ${lastSyncTimestampEpochMillis}...")
        } else {
            Log.d("ContactManager", "processContactsStreamed: Starting to stream ALL contacts...")
        }
        val contentResolver: ContentResolver = context.contentResolver
        
        // 필요한 모든 필드를 포함하는 프로젝션 정의
        val projection = arrayOf(
            ContactsContract.Data.CONTACT_ID,
            ContactsContract.Data.RAW_CONTACT_ID,
            ContactsContract.Data.MIMETYPE,
            ContactsContract.Data.DISPLAY_NAME, // Data 테이블의 DISPLAY_NAME
            ContactsContract.Contacts.CONTACT_LAST_UPDATED_TIMESTAMP,
            ContactsContract.CommonDataKinds.StructuredName.GIVEN_NAME,
            ContactsContract.CommonDataKinds.StructuredName.MIDDLE_NAME,
            ContactsContract.CommonDataKinds.StructuredName.FAMILY_NAME,
            ContactsContract.CommonDataKinds.Phone.NUMBER
        )

        var selection = "(${ContactsContract.Data.MIMETYPE} = ? OR ${ContactsContract.Data.MIMETYPE} = ?)"
        val selectionArgsList = mutableListOf<String>(
            ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE,
            ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE
        )

        if (lastSyncTimestampEpochMillis != null && lastSyncTimestampEpochMillis > 0) {
            selection += " AND ${ContactsContract.Contacts.CONTACT_LAST_UPDATED_TIMESTAMP} > ?"
            selectionArgsList.add(lastSyncTimestampEpochMillis.toString())
        }

        val sortOrder = ContactsContract.Data.CONTACT_ID // CONTACT_ID로 정렬하여 그룹핑 용이하게

        var cursor: android.database.Cursor? = null
        try {
            cursor = contentResolver.query(
                ContactsContract.Data.CONTENT_URI,
                projection,
                selection,
                selectionArgsList.toTypedArray(),
                sortOrder
            )

            cursor?.use { it -> // 'it'으로 명시적 이름 사용
                val contactIdCol = it.getColumnIndexOrThrow(ContactsContract.Data.CONTACT_ID)
                val rawContactIdCol = it.getColumnIndexOrThrow(ContactsContract.Data.RAW_CONTACT_ID)
                val mimeTypeCol = it.getColumnIndexOrThrow(ContactsContract.Data.MIMETYPE)
                val displayNameCol = it.getColumnIndexOrThrow(ContactsContract.Data.DISPLAY_NAME)
                val lastUpdatedCol = it.getColumnIndexOrThrow(ContactsContract.Contacts.CONTACT_LAST_UPDATED_TIMESTAMP)
                val givenNameCol = it.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.StructuredName.GIVEN_NAME)
                val middleNameCol = it.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.StructuredName.MIDDLE_NAME)
                val familyNameCol = it.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.StructuredName.FAMILY_NAME)
                val phoneNumberCol = it.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.NUMBER)

                val currentChunkContacts = mutableListOf<Map<String, Any?>>()
                val contactsAggregator = mutableMapOf<String, MutableMap<String, Any?>>() // 현재 CONTACT_ID의 데이터를 모으는 맵
                var currentProcessingContactId: String? = null

                while (it.moveToNext()) {
                    val contactId = it.getString(contactIdCol)

                    if (currentProcessingContactId != null && contactId != currentProcessingContactId) {
                        // 이전 Contact ID의 데이터 처리가 완료되었으므로 청크에 추가
                        contactsAggregator[currentProcessingContactId]?.let {
                            currentChunkContacts.add(HashMap(it)) // 방어적 복사
                        }
                        contactsAggregator.remove(currentProcessingContactId)
                        
                        if (currentChunkContacts.size >= chunkSize) {
                            onChunkProcessed(ArrayList(currentChunkContacts)) // 방어적 복사
                            currentChunkContacts.clear()
                        }
                    }
                    
                    currentProcessingContactId = contactId // 현재 처리 중인 Contact ID 업데이트

                    val contactEntry = contactsAggregator.getOrPut(contactId) {
                        mutableMapOf(
                            "id" to contactId,
                            "rawId" to it.getString(rawContactIdCol), // 해당 Data row의 rawId
                            "displayName" to (it.getString(displayNameCol) ?: ""),
                            "firstName" to "",
                            "middleName" to "",
                            "lastName" to "",
                            "phoneNumber" to "",
                            "lastUpdated" to it.getLong(lastUpdatedCol)
                        )
                    }

                    when (it.getString(mimeTypeCol)) {
                        ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE -> {
                            contactEntry["firstName"] = it.getString(givenNameCol) ?: ""
                            contactEntry["middleName"] = it.getString(middleNameCol) ?: ""
                            contactEntry["lastName"] = it.getString(familyNameCol) ?: ""
                            // StructuredName 행의 DISPLAY_NAME을 사용할 경우 여기서 displayName을 업데이트 할 수 있음
                            // val structuredDisplayName = it.getString(displayNameCol)
                            // if (!structuredDisplayName.isNullOrEmpty()) contactEntry["displayName"] = structuredDisplayName
                        }
                        ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE -> {
                            val number = it.getString(phoneNumberCol) ?: ""
                            if (contactEntry["phoneNumber"] == "" && number.isNotEmpty()) { // 첫 번째 유효한 번호만 저장
                                contactEntry["phoneNumber"] = number
                            }
                        }
                    }
                }

                // 루프 종료 후 마지막으로 처리 중이던 연락처 데이터가 있다면 청크에 추가
                currentProcessingContactId?.let {
                    contactsAggregator[it]?.let {
                        currentChunkContacts.add(HashMap(it))
                    }
                }
                contactsAggregator.clear()

                // 남은 청크가 있다면 마지막으로 전달
                if (currentChunkContacts.isNotEmpty()) {
                    onChunkProcessed(ArrayList(currentChunkContacts))
                    currentChunkContacts.clear()
                }
                
                onFinished()
            } ?: run {
                Log.e("ContactManager", "Cursor is null in processContactsStreamed")
                onError(Exception("Failed to query contacts: cursor is null"))
            }
        } catch (e: Exception) {
            Log.e("ContactManager", "Error in processContactsStreamed: ${e.message}", e)
            onError(e)
        }
    }

    // upsertContact 및 deleteContact 함수는 일단 유지 (추후 검토 필요)
    fun upsertContact(
        context: Context,
        rawContactId: String?,
        displayName: String,
        firstName: String,
        middleName: String,
        lastName: String,
        phoneNumber: String
    ): String {
        val contentResolver: ContentResolver = context.contentResolver
        lateinit var contactIdToUse: String
        lateinit var currentRawContactId : String

        if (rawContactId != null && rawContactId.isNotEmpty()) {
            currentRawContactId = rawContactId
            var resolvedContactIdLocal: String? = null
            val rawCursor = contentResolver.query(
                ContactsContract.RawContacts.CONTENT_URI,
                arrayOf(ContactsContract.RawContacts.CONTACT_ID),
                "${ContactsContract.RawContacts._ID} = ?",
                arrayOf(rawContactId),
                null
            )
            rawCursor?.use { cur -> // 'it' 대신 'cur' 사용
                if (cur.moveToFirst()) {
                    resolvedContactIdLocal = cur.getString(cur.getColumnIndexOrThrow(ContactsContract.RawContacts.CONTACT_ID))
                }
            }
            if (resolvedContactIdLocal == null) {
                 throw Exception("Failed to resolve contact_id from rawContactId: $rawContactId for update")
            }
            contactIdToUse = resolvedContactIdLocal!!
        } else {
            val rawContactValues = ContentValues()
            val rawContactUri = contentResolver.insert(ContactsContract.RawContacts.CONTENT_URI, rawContactValues)
            currentRawContactId = rawContactUri?.lastPathSegment ?: throw Exception("Failed to create raw contact")
            var resolvedContactIdLocal: String? = null
            val rawCursor = contentResolver.query(
                ContactsContract.RawContacts.CONTENT_URI,
                arrayOf(ContactsContract.RawContacts.CONTACT_ID),
                "${ContactsContract.RawContacts._ID} = ?",
                arrayOf(currentRawContactId),
                null
            )
            rawCursor?.use { cur -> // 'it' 대신 'cur' 사용
                if (cur.moveToFirst()) {
                    resolvedContactIdLocal = cur.getString(cur.getColumnIndexOrThrow(ContactsContract.RawContacts.CONTACT_ID))
                }
            }
            if (resolvedContactIdLocal == null) {
                 throw Exception("Failed to get contact_id for new raw_contact_id: $currentRawContactId")
            }
            contactIdToUse = resolvedContactIdLocal!!
        }
        
        val nameValues = ContentValues().apply {
            put(ContactsContract.Data.RAW_CONTACT_ID, currentRawContactId)
            put(ContactsContract.Data.MIMETYPE, ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE)
            put(ContactsContract.CommonDataKinds.StructuredName.GIVEN_NAME, firstName)
            put(ContactsContract.CommonDataKinds.StructuredName.MIDDLE_NAME, middleName)
            put(ContactsContract.CommonDataKinds.StructuredName.FAMILY_NAME, lastName)
            put(ContactsContract.CommonDataKinds.StructuredName.DISPLAY_NAME, displayName)
        }
        var updatedRows = contentResolver.update(
            ContactsContract.Data.CONTENT_URI,
            nameValues,
            "${ContactsContract.Data.RAW_CONTACT_ID} = ? AND ${ContactsContract.Data.MIMETYPE} = ?",
            arrayOf(currentRawContactId, ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE)
        )
        if (updatedRows == 0) { 
            contentResolver.insert(ContactsContract.Data.CONTENT_URI, nameValues)
        }

        val phoneValues = ContentValues().apply {
            put(ContactsContract.Data.RAW_CONTACT_ID, currentRawContactId) 
            put(ContactsContract.Data.MIMETYPE, ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE)
            put(ContactsContract.CommonDataKinds.Phone.NUMBER, phoneNumber)
            put(ContactsContract.CommonDataKinds.Phone.TYPE, ContactsContract.CommonDataKinds.Phone.TYPE_MOBILE)
        }
        updatedRows = contentResolver.update(
            ContactsContract.Data.CONTENT_URI,
            phoneValues,
            "${ContactsContract.Data.RAW_CONTACT_ID} = ? AND ${ContactsContract.Data.MIMETYPE} = ? AND ${ContactsContract.CommonDataKinds.Phone.NUMBER} = ?", 
            arrayOf(currentRawContactId, ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE, phoneNumber)
        )
        if (updatedRows == 0) { 
            contentResolver.insert(ContactsContract.Data.CONTENT_URI, phoneValues)
        }
        
        return contactIdToUse
    }

    fun deleteContact(context: Context, id: String): Boolean {
        val contentResolver: ContentResolver = context.contentResolver
        val deleted = contentResolver.delete(
            ContactsContract.Contacts.CONTENT_URI, 
            "${ContactsContract.Contacts._ID} = ?", 
            arrayOf(id) 
        )
        return deleted > 0
    }
} 