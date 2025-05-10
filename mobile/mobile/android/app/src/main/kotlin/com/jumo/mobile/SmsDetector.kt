package com.jumo.mobile // 사용자 앱의 패키지명 확인

import android.content.Context
import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Telephony
import android.util.Log

class SmsDetector(private val context: Context) {

    private var smsObserver: ContentObserver? = null
    private val handler = Handler(Looper.getMainLooper())
    private var debounceRunnable: Runnable? = null

    companion object {
        private const val TAG = "SmsDetector"
        private const val DEBOUNCE_TIMEOUT_MS = 1000L // 1초 디바운스 타임아웃
    }

    fun startListening() {
        if (smsObserver == null) {
            smsObserver = object : ContentObserver(handler) {
                override fun onChange(selfChange: Boolean, uri: Uri?) {
                    super.onChange(selfChange, uri)
                    Log.d(TAG, "[로그] onChange triggered (debouncer). selfChange: $selfChange, Uri: $uri")

                    // 기존 Runnable이 있다면 취소
                    debounceRunnable?.let { handler.removeCallbacks(it) }

                    // 새 Runnable 생성 및 예약
                    debounceRunnable = Runnable {
                        Log.d(TAG, "[로그] Debounced onChange executing. selfChange: $selfChange, Uri: $uri")
                        handleSmsChange(uri)
                    }
                    handler.postDelayed(debounceRunnable!!, DEBOUNCE_TIMEOUT_MS)
                }
            }

            try {
                context.contentResolver.registerContentObserver(
                    Telephony.Sms.CONTENT_URI,
                    true,
                    smsObserver!!
                )
                Log.d(TAG, "[로그] SmsContentObserver 등록 완료.")
            } catch (e: SecurityException) {
                Log.e(TAG, "[로그] SmsContentObserver 등록 실패 (SecurityException). READ_SMS 권한 확인 필요.", e)
            } catch (e: Exception) {
                Log.e(TAG, "[로그] SmsContentObserver 등록 실패.", e)
            }
        } else {
            Log.d(TAG, "[로그] SmsContentObserver 이미 등록됨.")
        }
    }

    private fun handleSmsChange(uri: Uri?) {
        // 이전에 있던 로그 출력 및 SMS 쿼리 로직
        if (uri != null) {
            try {
                val projection = arrayOf(
                    Telephony.Sms._ID,
                    Telephony.Sms.ADDRESS,
                    Telephony.Sms.BODY,
                    Telephony.Sms.DATE,
                    Telephony.Sms.TYPE
                )
                val cursor = context.contentResolver.query(uri, projection, null, null, null)
                cursor?.use { c ->
                    if (c.moveToFirst()) {
                        val id = c.getLong(c.getColumnIndexOrThrow(Telephony.Sms._ID))
                        val address = c.getString(c.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)) ?: "N/A"
                        val body = c.getString(c.getColumnIndexOrThrow(Telephony.Sms.BODY)) ?: "N/A"
                        val date = c.getLong(c.getColumnIndexOrThrow(Telephony.Sms.DATE))
                        val type = c.getInt(c.getColumnIndexOrThrow(Telephony.Sms.TYPE))
                        
                        var typeStr = "UNKNOWN ($type)"
                        when (type) {
                            Telephony.Sms.MESSAGE_TYPE_INBOX -> typeStr = "INBOX"
                            Telephony.Sms.MESSAGE_TYPE_SENT -> typeStr = "SENT"
                            Telephony.Sms.MESSAGE_TYPE_DRAFT -> typeStr = "DRAFT"
                            Telephony.Sms.MESSAGE_TYPE_OUTBOX -> typeStr = "OUTBOX"
                            Telephony.Sms.MESSAGE_TYPE_FAILED -> typeStr = "FAILED"
                            Telephony.Sms.MESSAGE_TYPE_QUEUED -> typeStr = "QUEUED"
                        }
                        Log.d(TAG, "[로그] SMS (uri: $uri) -> ID:$id, Addr:$address, Type:$typeStr, Date:$date, Body:'${body.take(30)}...'" )
                    } else {
                        Log.d(TAG, "[로그] SMS (uri: $uri) -> 해당 URI로 커서 이동 실패 또는 데이터 없음")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "[로그] SMS (uri: $uri) -> URI 쿼리 중 오류: ${e.message}")
            }
        } else {
            Log.d(TAG, "[로그] Debounced onChange URI is null. 일반적인 SMS DB 변경 감지.")
            // TODO: URI가 null일 경우, 최근 변경된 SMS를 쿼리하는 로직 추가 고려 (예: queryRecentSmsForDebug())
        }
        // 여기에 나중에 Flutter로 이벤트를 보내는 코드가 추가될 수 있습니다.
    }

    fun stopListening() {
        smsObserver?.let {
            context.contentResolver.unregisterContentObserver(it)
            smsObserver = null
            Log.d(TAG, "[로그] SmsContentObserver 해제 완료.")
        }
        // 예약된 Runnable도 취소
        debounceRunnable?.let { handler.removeCallbacks(it) }
        debounceRunnable = null
    }
}
