package com.jumo.mobile

import android.content.ContentResolver
import android.content.ContentValues
import android.content.Context
import android.provider.ContactsContract
import android.util.Log

object ContactManager {
    fun getContacts(context: Context): List<Map<String, Any?>> {
        Log.d("ContactManager", "getContacts: Fetching contacts with all required name fields...")
        val contactsDataMap = mutableMapOf<String, MutableMap<String, Any?>>()
        val contentResolver: ContentResolver = context.contentResolver

        val projection = arrayOf(
            ContactsContract.Data.CONTACT_ID,
            ContactsContract.Data.RAW_CONTACT_ID,
            ContactsContract.Data.MIMETYPE,
            ContactsContract.Data.DISPLAY_NAME, // 기본 DISPLAY_NAME
            ContactsContract.Contacts.CONTACT_LAST_UPDATED_TIMESTAMP, // Data 테이블에도 이 컬럼이 있음
            ContactsContract.CommonDataKinds.StructuredName.GIVEN_NAME,
            ContactsContract.CommonDataKinds.StructuredName.MIDDLE_NAME,
            ContactsContract.CommonDataKinds.StructuredName.FAMILY_NAME,
            ContactsContract.CommonDataKinds.Phone.NUMBER
            // ContactsContract.CommonDataKinds.Phone.TYPE // 필요시 대표번호 선정을 위해 사용 가능
        )

        val selection = "${ContactsContract.Data.MIMETYPE} = ? OR ${ContactsContract.Data.MIMETYPE} = ?"
        val selectionArgs = arrayOf(
            ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE,
            ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE
        )

        val sortOrder = ContactsContract.Data.CONTACT_ID

        val cursor = contentResolver.query(
            ContactsContract.Data.CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            sortOrder
        )

        cursor?.use {
            val contactIdCol = it.getColumnIndexOrThrow(ContactsContract.Data.CONTACT_ID)
            val rawContactIdCol = it.getColumnIndexOrThrow(ContactsContract.Data.RAW_CONTACT_ID)
            val mimeTypeCol = it.getColumnIndexOrThrow(ContactsContract.Data.MIMETYPE)
            val displayNameCol = it.getColumnIndexOrThrow(ContactsContract.Data.DISPLAY_NAME)
            val lastUpdatedCol = it.getColumnIndexOrThrow(ContactsContract.Contacts.CONTACT_LAST_UPDATED_TIMESTAMP)
            val givenNameCol = it.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.StructuredName.GIVEN_NAME)
            val middleNameCol = it.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.StructuredName.MIDDLE_NAME)
            val familyNameCol = it.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.StructuredName.FAMILY_NAME)
            val phoneNumberCol = it.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.NUMBER)

            while (it.moveToNext()) {
                val contactId = it.getString(contactIdCol)
                val rawContactId = it.getString(rawContactIdCol)
                val mimeType = it.getString(mimeTypeCol)

                val contactEntry = contactsDataMap.getOrPut(contactId) {
                    mutableMapOf(
                        "id" to contactId,
                        "rawId" to rawContactId,
                        "displayName" to (it.getString(displayNameCol) ?: ""), // Data 테이블의 DISPLAY_NAME
                        "firstName" to "",
                        "middleName" to "",
                        "lastName" to "",
                        "phoneNumber" to "",
                        "lastUpdated" to it.getLong(lastUpdatedCol)
                    )
                }

                when (mimeType) {
                    ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE -> {
                        contactEntry["firstName"] = it.getString(givenNameCol) ?: ""
                        contactEntry["middleName"] = it.getString(middleNameCol) ?: ""
                        contactEntry["lastName"] = it.getString(familyNameCol) ?: ""
                        // StructuredName의 DISPLAY_NAME이 Data.DISPLAY_NAME보다 우선순위가 높다면 여기서 덮어쓸 수 있음
                        // val structuredDisplayName = it.getString(displayNameCol) // StructuredName 행의 DISPLAY_NAME
                        // if (!structuredDisplayName.isNullOrEmpty()) {
                        //    contactEntry["displayName"] = structuredDisplayName
                        // }
                    }
                    ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE -> {
                        val number = it.getString(phoneNumberCol) ?: ""
                        if (contactEntry["phoneNumber"] == "" && number.isNotEmpty()) { // 첫 번째 번호만 저장
                            contactEntry["phoneNumber"] = number
                        }
                    }
                }
            }
        }
        Log.d("ContactManager", "getContacts: Processed ${contactsDataMap.size} contacts.")
        return contactsDataMap.values.toList()
    }

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
            rawCursor?.use {
                if (it.moveToFirst()) {
                    resolvedContactIdLocal = it.getString(it.getColumnIndexOrThrow(ContactsContract.RawContacts.CONTACT_ID))
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
            rawCursor?.use {
                if (it.moveToFirst()) {
                    resolvedContactIdLocal = it.getString(it.getColumnIndexOrThrow(ContactsContract.RawContacts.CONTACT_ID))
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