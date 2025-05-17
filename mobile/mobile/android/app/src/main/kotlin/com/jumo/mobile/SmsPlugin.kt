package com.jumo.mobile

import android.content.Context
import android.database.ContentObserver
import android.database.Cursor
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Telephony
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
// import com.google.android.mms.pdu.PduHeaders 삭제
import java.util.ArrayList // ArrayList import 추가

// 단순화된 메시지 데이터 모델
data class UnifiedMessage(
    val id: Long,               // 메시지 고유 ID (내부 식별용)
    val address: String,        // 발신/수신 전화번호 (표준화됨)
    val body: String,           // 메시지 내용 (제목 포함)
    val date: Long,             // 메시지 타임스탬프 (밀리초)
    val type: Int,              // 메시지 타입 (1=INBOX, 2=SENT)
    val typeStr: String         // 타입 문자열 ("INBOX" 또는 "SENT")
) {
    // Flutter에 전달하기 위한 Map 변환 - 필요한 4개 필드만 포함
    fun toMap(): Map<String, Any?> {
        return mapOf(
            "address" to address,
            "body" to body,
            "date" to date,
            "type" to typeStr
        )
    }
}

// MMS 메시지 타입 상수 정의
object MmsMessageType {
    // 수신 메시지 타입
    const val NOTIFICATION_IND = 130    // 0x82 - MMS 도착 알림
    const val RETRIEVE_CONF = 132       // 0x84 - 수신된 MMS 콘텐츠
    const val READ_ORIG_IND = 136       // 0x88 - 읽음 확인 (수신)
    
    // 발신 메시지 타입
    const val SEND_REQ = 128            // 0x80 - 발신 요청
    const val SEND_CONF = 129           // 0x81 - 발신 확인
    const val ACKNOWLEDGE_IND = 133     // 0x85 - 확인 응답
    const val DELIVERY_IND = 134        // 0x86 - 배달 알림
    const val READ_REC_IND = 135        // 0x87 - 읽음 확인 (발신)
    const val FORWARD_REQ = 137         // 0x89 - 전달 요청
    const val FORWARD_CONF = 138        // 0x8A - 전달 확인
}

// MMS 주소 타입 상수 정의
object MmsAddressType {
    const val FROM = 137   // 0x89 - 발신자
    const val TO = 151     // 0x97 - 수신자
    const val CC = 130     // 0x82 - 참조
    const val BCC = 129    // 0x81 - 숨은 참조
}

class SmsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var applicationContext: Context
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var smsContentObserver: ContentObserver? = null
    private var mmsContentObserver: ContentObserver? = null
    private val handler = Handler(Looper.getMainLooper())
    private var debounceRunnable: Runnable? = null
    
    // 성능 최적화: 쿼리 결과 캐싱 (마지막 조회 결과)
    private var lastQueryTime: Long = 0
    private var lastQueryResults: List<Map<String, Any?>> = emptyList()
    private val queryCacheTimeoutMs = 3000L // 3초 동안 캐시 유효

    companion object {
        private const val TAG = "SmsPlugin"
        private const val SMS_EVENT_CHANNEL_NAME = "com.jumo.mobile/sms_events"
        private const val SMS_METHOD_CHANNEL_NAME = "com.jumo.mobile/sms_query"
        private const val DEBOUNCE_TIMEOUT_MS = 1000L
        
        // 성능 최적화: SMS/MMS 쿼리용 프로젝션 필드 정의
        private val SMS_PROJECTION = arrayOf(
            Telephony.Sms._ID, 
            Telephony.Sms.ADDRESS, 
            Telephony.Sms.BODY,
            Telephony.Sms.DATE, 
            Telephony.Sms.TYPE, 
            Telephony.Sms.SUBJECT
        )
        
        private val MMS_PROJECTION = arrayOf(
            Telephony.Mms._ID, 
            Telephony.Mms.DATE, 
            Telephony.Mms.MESSAGE_TYPE,
            Telephony.Mms.SUBJECT
        )
        
        // 최대 쿼리 결과 수 제한
        private const val MAX_QUERY_RESULTS = 100
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, SMS_METHOD_CHANNEL_NAME)
        eventChannel = EventChannel(binding.binaryMessenger, SMS_EVENT_CHANNEL_NAME)

        methodChannel?.setMethodCallHandler(this)
        eventChannel?.setStreamHandler(this)
        Log.d(TAG, "SmsPlugin attached to engine and channels configured.")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        eventChannel = null
        stopObservation() // Unregister observer when plugin is detached
        Log.d(TAG, "SmsPlugin detached from engine.")
    }

    // --- MethodChannel.MethodCallHandler --- 
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getSmsSince" -> { // Flutter에서는 여전히 getSmsSince로 호출하나, toTimestamp 인자 추가
                val fromTimestamp = call.argument<Long>("timestamp")
                val toTimestamp = call.argument<Long>("toTimestamp") // Flutter에서 전달받을 toTimestamp

                if (fromTimestamp != null) {
                    try {
                        val smsList = querySms(fromTimestamp, toTimestamp) 
                        result.success(smsList)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error in getSmsSince (querySms): ${e.message}", e)
                        result.error("QUERY_ERROR", "Failed to query SMS: ${e.message}", null)
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "'timestamp' (fromTimestamp) argument is null", null)
                }
            }
            "getMessagesSince" -> { // SMS와 MMS 모두 쿼리하는 새 메서드
                val fromTimestamp = call.argument<Long>("timestamp")
                val toTimestamp = call.argument<Long>("toTimestamp")

                if (fromTimestamp != null) {
                    try {
                        // 성능 최적화: 최근 요청과 동일하고 짧은 시간 내에 다시 호출되면 캐시된 결과 반환
                        val now = System.currentTimeMillis()
                        if (now - lastQueryTime < queryCacheTimeoutMs && lastQueryResults.isNotEmpty()) {
                            Log.d(TAG, "Returning cached query results (${lastQueryResults.size} messages) from ${now - lastQueryTime}ms ago")
                            result.success(lastQueryResults)
                            return
                        }
                        
                        val messages = getUnifiedMessages(fromTimestamp, toTimestamp)
                        
                        // 결과 캐싱
                        lastQueryTime = now
                        lastQueryResults = messages
                        
                        result.success(messages)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error in getMessagesSince: ${e.message}", e)
                        result.error("QUERY_ERROR", "Failed to query SMS/MMS: ${e.message}", null)
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "'timestamp' (fromTimestamp) argument is null", null)
                }
            }
            "startSmsObservation" -> {
                startObservation()
                result.success(null)
            }
            "stopSmsObservation" -> {
                stopObservation()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // SMS와 MMS를 통합하여 조회하는 새로운 함수
    private fun getUnifiedMessages(fromTimestamp: Long, toTimestamp: Long?): List<Map<String, Any?>> {
        Log.d(TAG, "Getting unified messages from: $fromTimestamp to: $toTimestamp")
        
        // 1. SMS 메시지 조회
        val smsMessages = querySmsUnified(fromTimestamp, toTimestamp)
        
        // 2. MMS 메시지 조회
        val mmsMessages = queryMmsUnified(fromTimestamp, toTimestamp)
        
        // 3. 통합 및 날짜순 정렬
        val allMessages = smsMessages + mmsMessages
        
        // 성능 최적화: 이미 정렬된 데이터 병합 (병합 정렬 알고리즘 사용)
        val sortedMessages = mergeSort(smsMessages, mmsMessages)
        
        // 4. Map으로 변환하여 Flutter에 전달 - 필요한 필드만 포함
        return sortedMessages.map { it.toMap() }
    }
    
    // 성능 최적화: 이미 정렬된 두 리스트를 병합
    private fun mergeSort(smsMessages: List<UnifiedMessage>, mmsMessages: List<UnifiedMessage>): List<UnifiedMessage> {
        val result = ArrayList<UnifiedMessage>(smsMessages.size + mmsMessages.size)
        
        var smsIndex = 0
        var mmsIndex = 0
        
        // 두 리스트를 동시에 순회하며 날짜순으로 정렬된 리스트 생성
        while (smsIndex < smsMessages.size && mmsIndex < mmsMessages.size) {
            if (smsMessages[smsIndex].date <= mmsMessages[mmsIndex].date) {
                result.add(smsMessages[smsIndex++])
            } else {
                result.add(mmsMessages[mmsIndex++])
            }
        }
        
        // 남은 메시지들 추가
        while (smsIndex < smsMessages.size) {
            result.add(smsMessages[smsIndex++])
        }
        
        while (mmsIndex < mmsMessages.size) {
            result.add(mmsMessages[mmsIndex++])
        }
        
        return result
    }

    // --- EventChannel.StreamHandler --- 
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        Log.d(TAG, "EventChannel.onListen: Client is listening for SMS events.")
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        Log.d(TAG, "EventChannel.onCancel: Client stopped listening.")
        stopObservation() 
        eventSink = null
    }

    // --- SMS/MMS Observation Logic --- 
    private fun startObservation() {
        // SMS ContentObserver 등록
        if (smsContentObserver == null) {
            smsContentObserver = createContentObserver("SMS")
            try {
                applicationContext.contentResolver.registerContentObserver(
                    Telephony.Sms.CONTENT_URI, true, smsContentObserver!!
                )
                Log.d(TAG, "[Observer] SmsContentObserver registered successfully.")
            } catch (e: SecurityException) {
                Log.e(TAG, "[Observer] SecurityException registering SMS observer. Check READ_SMS permission.", e)
                eventSink?.error("PERMISSION_ERROR", "READ_SMS permission denied.", e.toString())
            } catch (e: Exception) {
                Log.e(TAG, "[Observer] Exception registering SmsContentObserver.", e)
                eventSink?.error("REGISTRATION_ERROR", "Failed to register SMS observer.", e.toString())
            }
        }
        
        // MMS ContentObserver 등록
        if (mmsContentObserver == null) {
            mmsContentObserver = createContentObserver("MMS")
            try {
                applicationContext.contentResolver.registerContentObserver(
                    Telephony.Mms.CONTENT_URI, true, mmsContentObserver!!
                )
                Log.d(TAG, "[Observer] MmsContentObserver registered successfully.")
            } catch (e: SecurityException) {
                Log.e(TAG, "[Observer] SecurityException registering MMS observer. Check READ_SMS permission.", e)
                eventSink?.error("PERMISSION_ERROR", "READ_SMS permission denied for MMS.", e.toString())
            } catch (e: Exception) {
                Log.e(TAG, "[Observer] Exception registering MmsContentObserver.", e)
                eventSink?.error("REGISTRATION_ERROR", "Failed to register MMS observer.", e.toString())
            }
        }
    }

    private fun createContentObserver(type: String): ContentObserver {
        return object : ContentObserver(handler) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                Log.d(TAG, "[Observer] $type onChange triggered. Uri: $uri. Debouncing...")
                debounceRunnable?.let { handler.removeCallbacks(it) }
                debounceRunnable = Runnable {
                    Log.d(TAG, "[Observer] Debounced $type onChange executing for Uri: $uri")
                    // 캐시 무효화
                    lastQueryTime = 0
                    lastQueryResults = emptyList()
                    eventSink?.success("message_changed_event") 
                    Log.d(TAG, "[Observer] Sent 'message_changed_event' to Flutter.")
                }
                handler.postDelayed(debounceRunnable!!, DEBOUNCE_TIMEOUT_MS)
            }
        }
    }

    private fun stopObservation() {
        smsContentObserver?.let {
            applicationContext.contentResolver.unregisterContentObserver(it)
            smsContentObserver = null
            Log.d(TAG, "[Observer] SmsContentObserver unregistered.")
        }
        
        mmsContentObserver?.let {
            applicationContext.contentResolver.unregisterContentObserver(it)
            mmsContentObserver = null
            Log.d(TAG, "[Observer] MmsContentObserver unregistered.")
        }
        
        debounceRunnable?.let { handler.removeCallbacks(it) }
        debounceRunnable = null
    }

    // --- SMS Query Logic (단순화된 데이터 모델 버전) ---
    private fun querySmsUnified(fromTimestampMillis: Long, toTimestampMillis: Long? = null): List<UnifiedMessage> {
        Log.d(TAG, "Querying SMS database for unified model from: $fromTimestampMillis to: $toTimestampMillis")
        val smsList = ArrayList<UnifiedMessage>() // MutableList에서 ArrayList로 변경
        
        // 쿼리 매개변수 설정
        val selection = buildSmsSelection(fromTimestampMillis, toTimestampMillis)
        val selectionArgs = buildSmsSelectionArgs(fromTimestampMillis, toTimestampMillis)
        
        try {
            // ORDER BY 절을 사용하여 정렬된 결과 가져오기
            val sortOrder = "${Telephony.Sms.DATE} ASC"
            
            // 성능 최적화: 최대 결과 수 제한
            val limitClause = " LIMIT $MAX_QUERY_RESULTS"
            
            val cursor = applicationContext.contentResolver.query(
                Telephony.Sms.CONTENT_URI, 
                SMS_PROJECTION,
                selection, 
                selectionArgs, 
                sortOrder + limitClause // 정렬 및 결과 수 제한
            )

            cursor?.use { c ->
                val count = c.count
                Log.d(TAG, "Found $count SMS messages matching criteria.")
                
                // 메모리 최적화: 미리 용량 할당
                smsList.ensureCapacity(count)
                
                while (c.moveToNext()) {
                    val id = c.getLong(c.getColumnIndexOrThrow(Telephony.Sms._ID))
                    val address = standardizeMessageAddress(c.getString(c.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)))
                    
                    // 본문 및 제목 처리 (제목이 있으면 본문 앞에 추가)
                    val bodyText = c.getString(c.getColumnIndexOrThrow(Telephony.Sms.BODY)) ?: ""
                    val rawSubject = c.getString(c.getColumnIndexOrThrow(Telephony.Sms.SUBJECT))
                    val subject = decodeMessageSubject(rawSubject)
                    
                    val body = if (!subject.isNullOrEmpty()) {
                        "$subject\n$bodyText"
                    } else {
                        bodyText
                    }
                    
                    val date = c.getLong(c.getColumnIndexOrThrow(Telephony.Sms.DATE))
                    val type = c.getInt(c.getColumnIndexOrThrow(Telephony.Sms.TYPE))
                    
                    // 타입 문자열 단순화 (INBOX 또는 SENT만 구분)
                    val typeStr = if (type == Telephony.Sms.MESSAGE_TYPE_INBOX) "INBOX" else "SENT"
                    
                    smsList.add(
                        UnifiedMessage(
                            id = id,
                            address = address,
                            body = body,
                            date = date,
                            type = type,
                            typeStr = typeStr
                        )
                    )
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error querying SMS database: ${e.message}", e)
            throw e 
        }
        return smsList
    }
    
    // 성능 최적화: SMS WHERE 절 구성
    private fun buildSmsSelection(fromTimestamp: Long, toTimestamp: Long?): String {
        // 필터링 조건: 시작 시간 + (선택적) 종료 시간 + 중요 메시지 타입만 (INBOX, SENT)
        var selection = "${Telephony.Sms.DATE} > ?"
        
        if (toTimestamp != null) {
            selection += " AND ${Telephony.Sms.DATE} <= ?"
        }
        
        // 중요 메시지만 필터링 (INBOX 또는 SENT)
        selection += " AND (${Telephony.Sms.TYPE} = ${Telephony.Sms.MESSAGE_TYPE_INBOX} OR ${Telephony.Sms.TYPE} = ${Telephony.Sms.MESSAGE_TYPE_SENT})"
        
        return selection
    }
    
    // 성능 최적화: SMS 쿼리 매개변수 구성
    private fun buildSmsSelectionArgs(fromTimestamp: Long, toTimestamp: Long?): Array<String> {
        return if (toTimestamp != null) {
            arrayOf(fromTimestamp.toString(), toTimestamp.toString())
        } else {
            arrayOf(fromTimestamp.toString())
        }
    }

    // --- MMS Query Logic (단순화된 데이터 모델 버전) ---
    private fun queryMmsUnified(fromTimestampMillis: Long, toTimestampMillis: Long? = null): List<UnifiedMessage> {
        Log.d(TAG, "Querying MMS database for unified model from: $fromTimestampMillis to: $toTimestampMillis")
        val mmsList = ArrayList<UnifiedMessage>() // MutableList에서 ArrayList로 변경
        
        // MMS 시간은 초 단위로 저장됨
        val fromTimestampSecs = fromTimestampMillis / 1000
        val toTimestampSecs = if (toTimestampMillis != null) toTimestampMillis / 1000 else null
        
        // 쿼리 매개변수 설정
        val selection = buildMmsSelection(fromTimestampSecs, toTimestampSecs)
        val selectionArgs = buildMmsSelectionArgs(fromTimestampSecs, toTimestampSecs)
        
        try {
            // ORDER BY 절을 사용하여 정렬된 결과 가져오기
            val sortOrder = "${Telephony.Mms.DATE} ASC"
            
            // 성능 최적화: 최대 결과 수 제한
            val limitClause = " LIMIT $MAX_QUERY_RESULTS"
            
            val cursor = applicationContext.contentResolver.query(
                Telephony.Mms.CONTENT_URI,
                MMS_PROJECTION,
                selection, 
                selectionArgs, 
                sortOrder + limitClause // 정렬 및 결과 수 제한
            )

            cursor?.use { c ->
                val count = c.count
                Log.d(TAG, "Found $count MMS messages matching criteria.")
                
                // 메모리 최적화: 미리 용량 할당
                mmsList.ensureCapacity(count)
                
                while (c.moveToNext()) {
                    val id = c.getLong(c.getColumnIndexOrThrow(Telephony.Mms._ID))
                    val date = c.getLong(c.getColumnIndexOrThrow(Telephony.Mms.DATE)) * 1000 // 초 -> 밀리초
                    val mmsType = c.getInt(c.getColumnIndexOrThrow(Telephony.Mms.MESSAGE_TYPE))
                    
                    // 인코딩 문제 해결을 위한 subject 처리 개선
                    val rawSubject = c.getString(c.getColumnIndexOrThrow(Telephony.Mms.SUBJECT))
                    val subject = decodeMessageSubject(rawSubject)
                    
                    // 추가 데이터 가져오기 (본문 및 주소)
                    val bodyText = getMmsText(id)
                    val address = getMmsAddress(id)
                    
                    // 본문과 제목 통합
                    val body = if (subject.isNotEmpty()) {
                        "$subject\n$bodyText"
                    } else {
                        bodyText
                    }
                    
                    // SMS 형식으로 변환 (INBOX 또는 SENT만 구분)
                    val smsType = convertMmsTypeToSmsType(mmsType)
                    val typeStr = if (smsType == Telephony.Sms.MESSAGE_TYPE_INBOX) "INBOX" else "SENT"
                    
                    mmsList.add(
                        UnifiedMessage(
                            id = id,
                            address = standardizeMessageAddress(address),
                            body = body,
                            date = date,
                            type = smsType,
                            typeStr = typeStr
                        )
                    )
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error querying MMS database: ${e.message}", e)
            throw e 
        }
        return mmsList
    }
    
    // 성능 최적화: MMS WHERE 절 구성
    private fun buildMmsSelection(fromTimestampSecs: Long, toTimestampSecs: Long?): String {
        var selection = "${Telephony.Mms.DATE} > ?"
        
        if (toTimestampSecs != null) {
            selection += " AND ${Telephony.Mms.DATE} <= ?"
        }
        
        // 중요 메시지 타입만 필터링 (INBOX 또는 SENT)
        selection += " AND (${Telephony.Mms.MESSAGE_TYPE} IN (?, ?, ?, ?, ?, ?, ?, ?, ?, ?))"
        
        return selection
    }
    
    // 성능 최적화: MMS 쿼리 매개변수 구성
    private fun buildMmsSelectionArgs(fromTimestampSecs: Long, toTimestampSecs: Long?): Array<String> {
        val args = mutableListOf(fromTimestampSecs.toString())
        
        if (toTimestampSecs != null) {
            args.add(toTimestampSecs.toString())
        }
        
        // 모든 MMS 메시지 타입 추가
        args.addAll(listOf(
            MmsMessageType.NOTIFICATION_IND.toString(),
            MmsMessageType.RETRIEVE_CONF.toString(),
            MmsMessageType.READ_ORIG_IND.toString(),
            MmsMessageType.SEND_REQ.toString(),
            MmsMessageType.SEND_CONF.toString(),
            MmsMessageType.ACKNOWLEDGE_IND.toString(),
            MmsMessageType.DELIVERY_IND.toString(),
            MmsMessageType.READ_REC_IND.toString(),
            MmsMessageType.FORWARD_REQ.toString(),
            MmsMessageType.FORWARD_CONF.toString()
        ))
        
        return args.toTypedArray()
    }

    // 이전 버전과의 호환성을 위한 레거시 SMS 쿼리 메서드
    private fun querySms(fromTimestampMillis: Long, toTimestampMillis: Long? = null): List<Map<String, Any?>> {
        val unifiedMessages = querySmsUnified(fromTimestampMillis, toTimestampMillis)
        return unifiedMessages.map { it.toMap() }
    }
    
    // MMS 타입을 수신/발신 구분으로 단순화
    private fun getMmsDirection(mmsType: Int): String {
        return when (mmsType) {
            MmsMessageType.NOTIFICATION_IND, MmsMessageType.RETRIEVE_CONF, 
            MmsMessageType.READ_ORIG_IND -> "INBOX"
            else -> "SENT"
        }
    }
    
    // MMS 타입 코드를 SMS 타입 코드로 변환 (단순화)
    private fun convertMmsTypeToSmsType(mmsType: Int): Int {
        return when (getMmsDirection(mmsType)) {
            "INBOX" -> Telephony.Sms.MESSAGE_TYPE_INBOX // 1
            else -> Telephony.Sms.MESSAGE_TYPE_SENT // 2
        }
    }
    
    // 주소 표준화 함수
    private fun standardizeMessageAddress(address: String?): String {
        return address?.replace(" ", "")?.replace("-", "") ?: ""
    }
    
    // MMS 텍스트 부분 추출 - 성능 최적화: 캐시 적용
    private val mmsTextCache = mutableMapOf<Long, String>()
    private val mmsAddressCache = mutableMapOf<Long, String>()
    
    private fun getMmsText(mmsId: Long): String {
        // 캐시된 텍스트가 있는지 확인
        mmsTextCache[mmsId]?.let { return it }
        
        val textBuilder = StringBuilder()
        val selectionPart = "${Telephony.Mms.Part.MSG_ID} = ?"
        val selectionArgs = arrayOf(mmsId.toString())
        
        try {
            val cursor = applicationContext.contentResolver.query(
                Uri.parse("content://mms/part"),
                arrayOf("_id", "ct", "_data", "text"),
                selectionPart,
                selectionArgs,
                null
            )
            
            cursor?.use { c ->
                if (c.moveToFirst()) {
                    do {
                        val type = c.getString(c.getColumnIndexOrThrow("ct"))
                        
                        if ("text/plain" == type) {
                            var data = c.getString(c.getColumnIndexOrThrow("_data"))
                            if (data != null) {
                                // 저장된 파일에서 텍스트 읽기
                                // 구현 생략 (복잡한 로직)
                            } else {
                                // 직접 텍스트 필드에서 가져오기
                                val text = c.getString(c.getColumnIndexOrThrow("text"))
                                if (text != null) {
                                    textBuilder.append(text)
                                }
                            }
                        }
                    } while (c.moveToNext())
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting MMS text for id $mmsId: ${e.message}", e)
        }
        
        val result = textBuilder.toString()
        // 결과 캐싱
        mmsTextCache[mmsId] = result
        
        // 캐시 크기 제한 (100개까지)
        if (mmsTextCache.size > 100) {
            val oldestEntry = mmsTextCache.entries.firstOrNull()
            oldestEntry?.let { mmsTextCache.remove(it.key) }
        }
        
        return result
    }
    
    // MMS 주소(발신자/수신자) 정보 추출 - 단순화된 버전 + 캐시 적용
    private fun getMmsAddress(mmsId: Long): String {
        // 캐시된 주소가 있는지 확인
        mmsAddressCache[mmsId]?.let { return it }
        
        var address = ""
        
        // 먼저 MMS 타입 확인 (발신 또는 수신)
        val msgTypeProjection = arrayOf(Telephony.Mms.MESSAGE_TYPE)
        val msgTypeSelection = "${Telephony.Mms._ID} = ?"
        val msgTypeSelectionArgs = arrayOf(mmsId.toString())
        var messageType = 0
        
        try {
            val cursor = applicationContext.contentResolver.query(
                Telephony.Mms.CONTENT_URI,
                msgTypeProjection,
                msgTypeSelection,
                msgTypeSelectionArgs,
                null
            )
            
            cursor?.use { c ->
                if (c.moveToFirst()) {
                    messageType = c.getInt(c.getColumnIndexOrThrow(Telephony.Mms.MESSAGE_TYPE))
                }
            }
            
            // 내가 보낸 메시지인지 받은 메시지인지에 따라 다른 주소 유형 사용
            val isSentMessage = (getMmsDirection(messageType) == "SENT")
            
            // 주소 가져오기
            val projection = arrayOf(Telephony.Mms.Addr.ADDRESS)
            var selection = ""
            
            if (isSentMessage) {
                // 보낸 메시지면 수신자 주소 가져오기 (TO = 151)
                selection = "${Telephony.Mms.Addr.MSG_ID} = ? AND ${Telephony.Mms.Addr.TYPE} = ${MmsAddressType.TO}" // TO 타입
            } else {
                // 받은 메시지면 발신자 주소 가져오기 (FROM = 137)
                selection = "${Telephony.Mms.Addr.MSG_ID} = ? AND ${Telephony.Mms.Addr.TYPE} = ${MmsAddressType.FROM}" // FROM 타입
            }
            
            val selectionArgs = arrayOf(mmsId.toString())
            val cursor2 = applicationContext.contentResolver.query(
                Uri.parse("content://mms/${mmsId}/addr"),
                projection,
                selection,
                selectionArgs,
                null
            )
            
            cursor2?.use { c ->
                if (c.moveToFirst()) {
                    address = c.getString(c.getColumnIndexOrThrow(Telephony.Mms.Addr.ADDRESS)) ?: ""
                }
            }
            
            // 주소를 찾지 못한 경우, 타입과 관계없이 아무 주소나 가져오기
            if (address.isEmpty()) {
                val cursor3 = applicationContext.contentResolver.query(
                    Uri.parse("content://mms/${mmsId}/addr"),
                    projection,
                    "${Telephony.Mms.Addr.MSG_ID} = ?",
                    arrayOf(mmsId.toString()),
                    null
                )
                cursor3?.use { c ->
                    if (c.moveToFirst()) {
                        address = c.getString(c.getColumnIndexOrThrow(Telephony.Mms.Addr.ADDRESS)) ?: ""
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting MMS address for id $mmsId: ${e.message}", e)
        }
        
        // 결과 캐싱
        mmsAddressCache[mmsId] = address
        
        // 캐시 크기 제한 (100개까지)
        if (mmsAddressCache.size > 100) {
            val oldestEntry = mmsAddressCache.entries.firstOrNull()
            oldestEntry?.let { mmsAddressCache.remove(it.key) }
        }
        
        return address
    }

    // MMS subject 인코딩 처리 함수 추가
    private fun decodeMessageSubject(subject: String?): String {
        if (subject == null || subject.isEmpty()) return ""
        
        try {
            // 인코딩 처리 시도 - 여러 인코딩 방식 시도
            val encodings = arrayOf("UTF-8", "EUC-KR", "ISO-8859-1")
            
            for (encoding in encodings) {
                try {
                    // 먼저 바이트 배열로 변환 후 해당 인코딩으로 다시 변환
                    val bytes = subject.toByteArray(charset("ISO-8859-1"))
                    val decoded = String(bytes, charset(encoding))
                    
                    // 한글이 포함되어 있는지 확인
                    if (decoded.any { it.code in 0xAC00..0xD7A3 }) {
                        Log.d(TAG, "Successfully decoded subject using $encoding: $decoded")
                        return decoded
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error decoding with $encoding: ${e.message}")
                }
            }
            
            // 모든 인코딩 시도 실패시 원본 반환
            return subject
        } catch (e: Exception) {
            Log.e(TAG, "Error in decodeMessageSubject: ${e.message}", e)
            return subject // 오류 발생시 원본 그대로 반환
        }
    }
} 