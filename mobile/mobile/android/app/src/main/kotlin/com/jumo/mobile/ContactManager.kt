package com.jumo.mobile

import android.content.ContentResolver
import android.content.ContentValues
import android.content.Context
import android.provider.ContactsContract
import android.util.Log

object ContactManager {
    fun getContacts(context: Context): List<Map<String, Any?>> {
        val contacts = mutableListOf<Map<String, Any?>>()
        val contentResolver: ContentResolver = context.contentResolver
        val projection = arrayOf(
            ContactsContract.Contacts._ID,
            ContactsContract.Contacts.DISPLAY_NAME,
            ContactsContract.Contacts.CONTACT_LAST_UPDATED_TIMESTAMP
        )
        val cursor = contentResolver.query(
            ContactsContract.Contacts.CONTENT_URI,
            projection,
            null,
            null,
            null
        )
        cursor?.use {
            while (it.moveToNext()) {
                val id = it.getString(it.getColumnIndexOrThrow(ContactsContract.Contacts._ID))
                val displayName = it.getString(it.getColumnIndexOrThrow(ContactsContract.Contacts.DISPLAY_NAME)) ?: ""
                val lastUpdated = it.getLong(it.getColumnIndexOrThrow(ContactsContract.Contacts.CONTACT_LAST_UPDATED_TIMESTAMP))

                // raw_contact_id 쿼리
                var rawId: String? = null
                val rawCursor = contentResolver.query(
                    ContactsContract.RawContacts.CONTENT_URI,
                    arrayOf(ContactsContract.RawContacts._ID),
                    ContactsContract.RawContacts.CONTACT_ID + "=?",
                    arrayOf(id),
                    null
                )
                rawCursor?.use { rc ->
                    if (rc.moveToFirst()) {
                        rawId = rc.getString(rc.getColumnIndexOrThrow(ContactsContract.RawContacts._ID))
                    }
                }

                // 전화번호 가져오기 (대표 1개)
                var phoneNumber = ""
                val phoneCursor = contentResolver.query(
                    ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                    arrayOf(ContactsContract.CommonDataKinds.Phone.NUMBER),
                    ContactsContract.CommonDataKinds.Phone.CONTACT_ID + "=?",
                    arrayOf(id),
                    null
                )
                phoneCursor?.use { pc ->
                    if (pc.moveToFirst()) {
                        phoneNumber = pc.getString(pc.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.NUMBER)) ?: ""
                    }
                }

                // 이름 필드(퍼스트/미들/라스트/디스플레이네임) StructuredName 쿼리
                var firstName = ""
                var middleName = ""
                var lastName = ""
                var structuredDisplayName = ""
                val nameCursor = contentResolver.query(
                    ContactsContract.Data.CONTENT_URI,
                    arrayOf(
                        ContactsContract.Data.CONTACT_ID,
                        ContactsContract.Data.MIMETYPE,
                        ContactsContract.CommonDataKinds.StructuredName.GIVEN_NAME,
                        ContactsContract.CommonDataKinds.StructuredName.MIDDLE_NAME,
                        ContactsContract.CommonDataKinds.StructuredName.FAMILY_NAME,
                        ContactsContract.CommonDataKinds.StructuredName.DISPLAY_NAME
                    ),
                    ContactsContract.Data.CONTACT_ID + "=? AND " +
                            ContactsContract.Data.MIMETYPE + "=?",
                    arrayOf(id, ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE),
                    null
                )
                nameCursor?.use { nc ->
                    if (nc.moveToFirst()) {
                        firstName = nc.getString(nc.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.StructuredName.GIVEN_NAME)) ?: ""
                        middleName = nc.getString(nc.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.StructuredName.MIDDLE_NAME)) ?: ""
                        lastName = nc.getString(nc.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.StructuredName.FAMILY_NAME)) ?: ""
                        structuredDisplayName = nc.getString(nc.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.StructuredName.DISPLAY_NAME)) ?: ""
                    }
                }

                contacts.add(
                    mapOf(
                        "id" to id,
                        "rawId" to rawId,
                        "displayName" to displayName,
                        "firstName" to firstName,
                        "middleName" to middleName,
                        "lastName" to lastName,
                        "structuredDisplayName" to structuredDisplayName,
                        "phoneNumber" to phoneNumber,
                        "lastUpdated" to lastUpdated
                    )
                )
            }
        }
        Log.d("ContactManager", "getContacts: found ${contacts.size} contacts")
        return contacts
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
        val values = ContentValues().apply {
            put(ContactsContract.Contacts.DISPLAY_NAME, displayName)
        }

        val contactId = if (rawContactId != null) {
            // 기존 연락처 업데이트
            contentResolver.update(
                ContactsContract.RawContacts.CONTENT_URI,
                values,
                "${ContactsContract.RawContacts._ID} = ?",
                arrayOf(rawContactId)
            )
            // rawContactId로부터 contactId 가져오기
            var contactId: String? = null
            val cursor = contentResolver.query(
                ContactsContract.RawContacts.CONTENT_URI,
                arrayOf(ContactsContract.RawContacts.CONTACT_ID),
                "${ContactsContract.RawContacts._ID} = ?",
                arrayOf(rawContactId),
                null
            )
            cursor?.use {
                if (it.moveToFirst()) {
                    contactId = it.getString(it.getColumnIndexOrThrow(ContactsContract.RawContacts.CONTACT_ID))
                }
            }
            contactId ?: throw Exception("Failed to get contact ID")
        } else {
            // 새 연락처 생성
            val uri = contentResolver.insert(ContactsContract.Contacts.CONTENT_URI, values)
            uri?.lastPathSegment ?: throw Exception("Failed to create contact")
        }

        // 이름 정보 업데이트
        val nameValues = ContentValues().apply {
            put(ContactsContract.Data.RAW_CONTACT_ID, rawContactId ?: contactId)
            put(ContactsContract.Data.MIMETYPE, ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE)
            put(ContactsContract.CommonDataKinds.StructuredName.GIVEN_NAME, firstName)
            put(ContactsContract.CommonDataKinds.StructuredName.MIDDLE_NAME, middleName)
            put(ContactsContract.CommonDataKinds.StructuredName.FAMILY_NAME, lastName)
            put(ContactsContract.CommonDataKinds.StructuredName.DISPLAY_NAME, displayName)
        }

        // 기존 이름 데이터 삭제
        contentResolver.delete(
            ContactsContract.Data.CONTENT_URI,
            "${ContactsContract.Data.RAW_CONTACT_ID} = ? AND ${ContactsContract.Data.MIMETYPE} = ?",
            arrayOf(rawContactId ?: contactId, ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE)
        )

        // 새 이름 데이터 삽입
        contentResolver.insert(ContactsContract.Data.CONTENT_URI, nameValues)

        // 전화번호 업데이트
        val phoneValues = ContentValues().apply {
            put(ContactsContract.Data.RAW_CONTACT_ID, rawContactId ?: contactId)
            put(ContactsContract.Data.MIMETYPE, ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE)
            put(ContactsContract.CommonDataKinds.Phone.NUMBER, phoneNumber)
            put(ContactsContract.CommonDataKinds.Phone.TYPE, ContactsContract.CommonDataKinds.Phone.TYPE_MOBILE)
        }

        // 기존 전화번호 데이터 삭제
        contentResolver.delete(
            ContactsContract.Data.CONTENT_URI,
            "${ContactsContract.Data.RAW_CONTACT_ID} = ? AND ${ContactsContract.Data.MIMETYPE} = ?",
            arrayOf(rawContactId ?: contactId, ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE)
        )

        // 새 전화번호 데이터 삽입
        contentResolver.insert(ContactsContract.Data.CONTENT_URI, phoneValues)

        return contactId
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