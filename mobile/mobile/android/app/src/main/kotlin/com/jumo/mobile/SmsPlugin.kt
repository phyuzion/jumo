package com.jumo.mobile

import android.content.Context
import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Telephony
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
// import java.util.ArrayList // Not strictly needed if returning List

class SmsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var applicationContext: Context
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var contentObserver: ContentObserver? = null
    private val handler = Handler(Looper.getMainLooper())
    private var debounceRunnable: Runnable? = null

    companion object {
        private const val TAG = "SmsPlugin"
        private const val SMS_EVENT_CHANNEL_NAME = "com.jumo.mobile/sms_events"
        private const val SMS_METHOD_CHANNEL_NAME = "com.jumo.mobile/sms_query"
        private const val DEBOUNCE_TIMEOUT_MS = 1000L
        // SharedPreferences for last checked timestamp (specific to this plugin's event triggering)
        // private const val PREFS_NAME = "sms_plugin_prefs" // 사용 안 함
        // private const val KEY_LAST_EVENT_TRIGGER_SMS_TIMESTAMP = "last_event_sms_timestamp" // 사용 안 함
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
        stopSmsObservation() // Unregister observer when plugin is detached
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
            "startSmsObservation" -> {
                startSmsObservation()
                result.success(null)
            }
            "stopSmsObservation" -> {
                stopSmsObservation()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // --- EventChannel.StreamHandler --- 
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        Log.d(TAG, "EventChannel.onListen: Client is listening for SMS events.")
        eventSink = events
        // Flutter에서 startSmsObservation을 명시적으로 호출하는 것을 기다림.
    }

    override fun onCancel(arguments: Any?) {
        Log.d(TAG, "EventChannel.onCancel: Client stopped listening.")
        // Do not stop observation here if you want it to persist 앱 wide
        // eventSink = null; // Only nullify if observation is also stopped.
        // To allow multiple listeners, or to keep observing 앱 wide, don't call stopSmsObservation() here
        // unless it's the very last listener. For simplicity now, we can stop if sink is cancelled.
        // However, a more robust approach is to manage observation lifecycle via start/stopSmsObservation methods.
        // For now, let's make onCancel also stop it to be simple and avoid leaks if Flutter side forgets to call stop.
        stopSmsObservation() 
        eventSink = null
    }

    // --- SMS Observation Logic --- 
    private fun startSmsObservation() {
        if (contentObserver == null) {
            contentObserver = object : ContentObserver(handler) {
                override fun onChange(selfChange: Boolean, uri: Uri?) {
                    Log.d(TAG, "[Observer] onChange triggered. Uri: $uri. Debouncing...")
                    debounceRunnable?.let { handler.removeCallbacks(it) }
                    debounceRunnable = Runnable {
                        Log.d(TAG, "[Observer] Debounced onChange executing for Uri: $uri")
                        eventSink?.success("sms_changed_event") 
                        Log.d(TAG, "[Observer] Sent 'sms_changed_event' to Flutter.")
                    }
                    handler.postDelayed(debounceRunnable!!, DEBOUNCE_TIMEOUT_MS)
                }
            }
            try {
                applicationContext.contentResolver.registerContentObserver(
                    Telephony.Sms.CONTENT_URI, true, contentObserver!!
                )
                Log.d(TAG, "[Observer] SmsContentObserver registered successfully.")
            } catch (e: SecurityException) {
                Log.e(TAG, "[Observer] SecurityException registering. Check READ_SMS permission.", e)
                eventSink?.error("PERMISSION_ERROR", "READ_SMS permission denied.", e.toString())
            } catch (e: Exception) {
                Log.e(TAG, "[Observer] Exception registering SmsContentObserver.", e)
                eventSink?.error("REGISTRATION_ERROR", "Failed to register SMS observer.", e.toString())
            }
        } else {
            Log.d(TAG, "[Observer] SmsContentObserver is already registered.")
        }
    }

    private fun stopSmsObservation() {
        contentObserver?.let {
            applicationContext.contentResolver.unregisterContentObserver(it)
            contentObserver = null
            Log.d(TAG, "[Observer] SmsContentObserver unregistered.")
        }
        debounceRunnable?.let { handler.removeCallbacks(it) }
        debounceRunnable = null
    }

    // --- SMS Query Logic (fromTimestampMillis 와 선택적 toTimestampMillis 사용) --- 
    private fun querySms(fromTimestampMillis: Long, toTimestampMillis: Long? = null): List<Map<String, Any?>> {
        Log.d(TAG, "Querying SMS database from: $fromTimestampMillis to: $toTimestampMillis")
        val smsList = mutableListOf<Map<String, Any?>>()
        val projection = arrayOf(
            Telephony.Sms._ID, Telephony.Sms.ADDRESS, Telephony.Sms.BODY,
            Telephony.Sms.DATE, Telephony.Sms.TYPE, Telephony.Sms.READ,
            Telephony.Sms.THREAD_ID, Telephony.Sms.SUBJECT
        )
        
        val selectionArgsList = mutableListOf<String>()
        var selectionClause = "${Telephony.Sms.DATE} > ?" // fromTimestampMillis는 항상 포함 (이후)
        selectionArgsList.add(fromTimestampMillis.toString())

        if (toTimestampMillis != null) {
            selectionClause += " AND ${Telephony.Sms.DATE} <= ?" // toTimestampMillis는 포함 (이하)
            selectionArgsList.add(toTimestampMillis.toString())
        }

        try {
            val cursor = applicationContext.contentResolver.query(
                Telephony.Sms.CONTENT_URI, projection,
                selectionClause, 
                selectionArgsList.toTypedArray(), 
                "${Telephony.Sms.DATE} ASC" 
            )

            cursor?.use { c ->
                Log.d(TAG, "Found ${c.count} SMS messages matching criteria (from: $fromTimestampMillis, to: $toTimestampMillis).")
                val idCol = c.getColumnIndexOrThrow(Telephony.Sms._ID)
                val addressCol = c.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
                val bodyCol = c.getColumnIndexOrThrow(Telephony.Sms.BODY)
                val dateCol = c.getColumnIndexOrThrow(Telephony.Sms.DATE)
                val typeCol = c.getColumnIndexOrThrow(Telephony.Sms.TYPE)
                val readCol = c.getColumnIndexOrThrow(Telephony.Sms.READ)
                val threadIdCol = c.getColumnIndexOrThrow(Telephony.Sms.THREAD_ID)
                val subjectCol = c.getColumnIndexOrThrow(Telephony.Sms.SUBJECT)

                while (c.moveToNext()) {
                    val date = c.getLong(dateCol)
                    val smsMap = mapOf(
                        "_id" to c.getLong(idCol),
                        "address" to c.getString(addressCol),
                        "body" to c.getString(bodyCol),
                        "date" to date,
                        "type" to c.getInt(typeCol),
                        "read" to c.getInt(readCol),
                        "thread_id" to c.getLong(threadIdCol),
                        "subject" to c.getString(subjectCol)
                    )
                    smsList.add(smsMap)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error querying SMS database: ${e.message}", e)
            throw e 
        }
        return smsList
    }

    // SharedPreferences 예시 (필요하다면 getLastQueriedTimestamp / setLastQueriedTimestamp 구현)
    // private fun getLastQueriedTimestamp(): Long { ... }
    // private fun setLastQueriedTimestamp(timestamp: Long) { ... }
} 